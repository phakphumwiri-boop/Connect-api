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


## Supported host operating systems

### Windows 11

- Install Docker Desktop and select the **WSL 2 backend** with Linux containers.
- Enable WSL integration for the Ubuntu distribution used to run the FastAPI service.
- Run FastAPI inside that integrated WSL 2 distribution so the Docker SDK can access the Docker Engine socket/context. Do not use Docker Desktop's Docker VMM backend for this Python Docker-SDK deployment unless a compatible Docker API endpoint is explicitly configured.
- Web and Webtop containers run through Docker Desktop's Linux VM.
- Android Emulator should run natively on Windows using the Android Emulator with **Windows Hypervisor Platform (WHPX)**. The current Docker Android runtime requires `/dev/kvm` and therefore intentionally does not claim Windows support. A future Windows host-agent integration will expose a managed native emulator session to the API.
- Do not enable privileged containers to work around missing KVM.

### Ubuntu/Linux

- Install Docker Engine using Docker's official Ubuntu instructions, enable/start the Docker service, and grant the dedicated API service account least-privilege access to the Docker socket.
- Web and Webtop run as ordinary managed containers.
- Android container runtime requires x86_64 virtualization support, KVM enabled in firmware/kernel, and readable/writable `/dev/kvm`. The API checks for this device and refuses provisioning when it is absent.
- If the host itself is a VM, nested virtualization must be exposed by its hypervisor.

### Official setup references

- Docker Desktop WSL 2 backend: https://docs.docker.com/desktop/features/wsl/
- Docker Engine on Ubuntu: https://docs.docker.com/engine/install/ubuntu/
- Android Emulator acceleration: https://developer.android.com/studio/run/emulator-acceleration
- Android Emulator command-line acceleration modes: https://developer.android.com/studio/run/emulator-commandline

## Host installation smoke checks

Windows PowerShell:
```powershell
wsl --status
docker version
docker info
```

Ubuntu:
```bash
sudo systemctl is-active docker
docker version
test -r /dev/kvm && test -w /dev/kvm
```

These commands verify prerequisites only. A successful live acceptance also needs a create/start/stop/delete cycle against the actual host and a browser session test.


### macOS

- Install Docker Desktop for Mac and use its supported container runtime for Web and Linux Desktop/Webtop workloads. Containers execute in Docker Desktop's Linux VM, not as native macOS processes.
- Run FastAPI on macOS with Docker Desktop's supported Docker context/socket and verify SDK connectivity with `docker version` before enabling machine management.
- Build and run Flutter macOS desktop apps natively using the macOS Flutter toolchain and Xcode command-line tools.
- Android Emulator runs natively on macOS using Apple's Hypervisor.framework acceleration (subject to Android Emulator and host architecture support). The current Docker Android mode still requires Linux `/dev/kvm`; it is not the macOS Android runtime.
- Do not advertise native iOS Simulator or iOS device support from Docker containers.

### iOS

- iOS Simulator is provided by Xcode and must run on a macOS host. CI uses a macOS GitHub Actions runner to compile the iOS Simulator target without code signing.
- Installing on a physical iPhone, signing an archive, and App Store/TestFlight distribution require the appropriate Apple developer signing assets and device/provisioning configuration. CI must not claim device installation merely because the simulator build succeeds.
- The current Machine API does not yet orchestrate Xcode simulator boot, app installation, screenshots, or physical-device deployment; those require a macOS host agent and explicit acceptance tests.

### Apple platform smoke checks

On macOS with Xcode installed:
```bash
xcodebuild -version
flutter doctor -v
flutter build macos --release
flutter build ios --simulator --no-codesign
```

A successful compile is not equivalent to a booted simulator or a successful run on a physical iPhone.


## Flutter Machine Dashboard

The Flutter home screen provides the first API-backed machine control surface:
- Configure the API base URL and enter the admin token at runtime. The token is held in app memory only and is not persisted.
- List, create, start, stop, restart, and delete Docker-managed machines through the authenticated `/machines` endpoints.
- Android Emulator defaults to `10.0.2.2` for the Android emulator host loopback. Web, iOS Simulator, macOS, Windows, and Linux default to `127.0.0.1` when the API runs on the same host.
- For a physical iPhone/Android device, set `API_BASE_URL` to a reachable HTTPS API endpoint or enter the host's LAN URL. Do not expose the admin API directly to the public internet.

Example:
```bash
cd flutter_app
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8000
```

This is a machine CRUD/control dashboard, not yet a live desktop/phone screen viewer or a cross-host agent manager. The admin token should be supplied only over a trusted network; production deployment needs TLS and a stronger user/session authorization design.
