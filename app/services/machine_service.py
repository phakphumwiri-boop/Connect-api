import os
from pathlib import Path
from typing import Any

import docker
from docker.errors import DockerException, NotFound


LABEL_MANAGED = "connect-api.managed"
LABEL_MODE = "connect-api.mode"
LABEL_NAME = "connect-api.name"

IMAGES = {
    "web": ("nginx:alpine", 80),
    "android": ("budtmo/docker-android:emulator_14.0", 6080),
    "desktop": ("lscr.io/linuxserver/webtop:ubuntu-xfce", 3000),
}


class MachineServiceError(RuntimeError):
    pass


class RuntimeUnavailable(MachineServiceError):
    pass


class MachineNotFound(MachineServiceError):
    pass


def _client():
    try:
        client = docker.from_env()
        client.ping()
        return client
    except DockerException as exc:
        raise RuntimeUnavailable(
            "Docker Engine is unavailable. Install/start Docker and check API access."
        ) from exc


def _workspace(workspace_id: str | None) -> Path:
    if not workspace_id:
        raise MachineServiceError("workspace_id is required for web preview.")
    root = Path(os.getenv("CONNECT_API_WORKSPACE_ROOT", "./workspaces")).resolve()
    target = (root / workspace_id).resolve()
    if root not in target.parents or not target.is_dir():
        raise MachineServiceError("Workspace does not exist or is outside workspace root.")
    if not (target / "index.html").is_file():
        raise MachineServiceError("Web workspace must contain a built index.html.")
    return target


def _port(container: Any, internal_port: int) -> int | None:
    container.reload()
    binding = container.attrs.get("NetworkSettings", {}).get("Ports", {}).get(
        f"{internal_port}/tcp"
    )
    if not binding:
        return None
    return int(binding[0]["HostPort"])


def create_machine(payload):
    client = _client()
    image, internal_port = IMAGES[payload.mode]

    if payload.mode == "android" and not Path("/dev/kvm").exists():
        raise MachineServiceError(
            "Android Emulator requires a Linux host with /dev/kvm. "
            "On Windows/macOS, run this service inside a Linux VM with nested virtualization."
        )

    kwargs = {
        "image": image,
        "name": f"connect-{payload.name}",
        "detach": True,
        "ports": {f"{internal_port}/tcp": ("127.0.0.1", None)},
        "cpu_period": 100000,
        "cpu_quota": payload.cpu_cores * 100000,
        "mem_limit": payload.memory_mb * 1024 * 1024,
        "pids_limit": 512,
        "labels": {
            LABEL_MANAGED: "true",
            LABEL_MODE: payload.mode,
            LABEL_NAME: payload.name,
            "connect-api.disk-gb-requested": str(payload.disk_gb),
        },
    }

    if payload.mode == "web":
        workspace = _workspace(payload.workspace_id)
        kwargs["volumes"] = {
            str(workspace): {
                "bind": "/usr/share/nginx/html",
                "mode": "ro",
            }
        }
    elif payload.mode == "android":
        kwargs["devices"] = ["/dev/kvm:/dev/kvm:rwm"]
        kwargs["environment"] = {
            "EMULATOR_DEVICE": "Samsung Galaxy S10",
            "WEB_VNC": "true",
        }
    else:
        kwargs["ports"]["3001/tcp"] = ("127.0.0.1", None)
        kwargs["environment"] = {
            "PUID": "1000",
            "PGID": "1000",
            "TZ": os.getenv("TZ", "Asia/Bangkok"),
        }
        kwargs["shm_size"] = "1gb"

    try:
        container = client.containers.run(**kwargs)
        host_port = _port(container, internal_port)
    except DockerException as exc:
        raise MachineServiceError(f"Could not create {payload.mode} runtime: {exc}") from exc

    note = (
        "Disk quota is recorded as a requested value; enforcement depends on the "
        "Docker host storage driver and is not enabled by this API yet."
    )
    return _serialize(container, payload.mode, payload.cpu_cores, payload.memory_mb,
                      payload.disk_gb, host_port, note)


def _serialize(container, mode=None, cpu_cores=None, memory_mb=None,
               disk_gb=None, host_port=None, note=None):
    labels = container.labels or {}
    mode = mode or labels.get(LABEL_MODE, "web")
    try:
        cpu_cores = cpu_cores or int(container.attrs["HostConfig"]["CpuQuota"]) // 100000
        memory_mb = memory_mb or int(container.attrs["HostConfig"]["Memory"]) // (1024 * 1024)
    except (KeyError, TypeError, ValueError):
        cpu_cores, memory_mb = cpu_cores or 0, memory_mb or 0
    disk_gb = disk_gb or int(labels.get("connect-api.disk-gb-requested", "0"))
    if host_port is None:
        internal = IMAGES[mode][1]
        host_port = _port(container, internal)
    preview = f"http://127.0.0.1:{host_port}" if host_port else None
    return {
        "id": container.id,
        "name": labels.get(LABEL_NAME, container.name),
        "mode": mode,
        "status": container.status,
        "cpu_cores": cpu_cores,
        "memory_mb": memory_mb,
        "disk_gb_requested": disk_gb,
        "disk_quota_enforced": False,
        "preview_url": preview,
        "note": note,
    }


def list_machines():
    client = _client()
    result = []
    for container in client.containers.list(all=True, filters={"label": f"{LABEL_MANAGED}=true"}):
        container.reload()
        result.append(_serialize(container))
    return result


def get_machine(machine_id: str):
    client = _client()
    try:
        container = client.containers.get(machine_id)
        if (container.labels or {}).get(LABEL_MANAGED) != "true":
            raise MachineNotFound("Machine not found.")
        container.reload()
        return _serialize(container)
    except NotFound as exc:
        raise MachineNotFound("Machine not found.") from exc


def control_machine(machine_id: str, action: str):
    client = _client()
    try:
        container = client.containers.get(machine_id)
        if (container.labels or {}).get(LABEL_MANAGED) != "true":
            raise MachineNotFound("Machine not found.")
        if action == "start":
            container.start()
        elif action == "stop":
            container.stop(timeout=10)
        elif action == "restart":
            container.restart(timeout=10)
        else:
            raise MachineServiceError("Unsupported machine action.")
        container.reload()
        return _serialize(container)
    except NotFound as exc:
        raise MachineNotFound("Machine not found.") from exc


def delete_machine(machine_id: str):
    client = _client()
    try:
        container = client.containers.get(machine_id)
        if (container.labels or {}).get(LABEL_MANAGED) != "true":
            raise MachineNotFound("Machine not found.")
        container.remove(force=True)
    except NotFound as exc:
        raise MachineNotFound("Machine not found.") from exc
