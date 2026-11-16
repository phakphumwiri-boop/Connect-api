# Connect-api Machine Lab

## Target

One Flutter control plane backed by FastAPI, with three isolated runtime types:

- **Web**: serves a built web workspace through Nginx.
- **Android**: runs Docker-Android with browser-accessible VNC and KVM acceleration.
- **Desktop**: runs LinuxServer Webtop and exposes its browser desktop.

The API never accepts arbitrary Docker image names or arbitrary host paths. Runtime images are allowlisted in `app/services/machine_service.py`. Web preview workspaces must live below `CONNECT_API_WORKSPACE_ROOT` and contain a built `index.html`.

## Resource controls

CPU and memory are passed to Docker as hard container limits. Process count is also capped. The requested disk size is recorded, but **disk quota is not claimed as enforced** because Docker storage quota support depends on the host filesystem and storage driver. Persistent workspace storage and verified disk quotas are a separate implementation step.

## Host requirements

- Docker Engine with access restricted to the trusted API service.
- Web runtime: Docker Engine and a built web workspace.
- Desktop runtime: Docker Engine; Webtop supports x86-64 and arm64.
- Android runtime: Linux host with hardware virtualization and `/dev/kvm`. Windows/macOS hosts need a Linux VM with nested virtualization. The Android runtime fails closed if KVM is missing.

## Security

- Set a strong `CONNECT_API_ADMIN_TOKEN`; machine endpoints fail closed if it is absent.
- Keep the API bound to a trusted private interface. Do not expose the Docker socket or these admin endpoints to the public Internet.
- Put browser preview ports behind an authenticated reverse proxy before remote access.
- Only containers labelled as managed by this API can be listed, controlled, or deleted by these endpoints.
- Runtime containers are not privileged; Android receives only the `/dev/kvm` device.

## API

All machine endpoints require the `X-Admin-Token` header.

- `POST /machines`: create a web, android, or desktop runtime.
- `GET /machines`: list managed runtimes.
- `GET /machines/{id}`: inspect a runtime.
- `POST /machines/{id}/start`, `stop`, `restart`: lifecycle controls.
- `DELETE /machines/{id}`: remove a managed runtime.
- `GET /health`: API health.

Example web machine request:

```json
{
  "name": "demo-web",
  "mode": "web",
  "cpu_cores": 2,
  "memory_mb": 2048,
  "disk_gb": 10,
  "workspace_id": "demo-web"
}
```

Place the web build output, including `index.html`, in
`$CONNECT_API_WORKSPACE_ROOT/demo-web` before creating the runtime.

## Current implementation boundary

This first backend slice provisions and controls the three runtime containers. It does not yet implement source upload, Flutter build/test job execution, Android APK installation, live resource sampling, or the Flutter machine dashboard. Those are subsequent integration stages and must be covered by CI and live-host acceptance tests before the platform is described as production-ready.
