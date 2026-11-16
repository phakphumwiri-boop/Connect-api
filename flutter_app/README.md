# ISH Flutter application

Flutter client for the Connect-api FastAPI backend.

## Supported platforms

The CI pipeline validates the Flutter source and builds release artifacts for:

- Android (APK and Android App Bundle)
- iOS (unsigned app bundle; signing is required for device distribution)
- Web
- Windows
- macOS
- Linux

Build artifacts are published on each successful GitHub Actions run and retained for 14 days.

## Run locally

```sh
cd flutter_app
flutter create --platforms=android,ios,web,windows,macos,linux --project-name ish_app --org com.connectapi .
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

The example URL targets a backend running on the host machine from the Android emulator. For a physical device, desktop app, web deployment, or production build, provide a backend URL reachable from that platform with `--dart-define=API_BASE_URL=https://your-api.example`. Production should use HTTPS.

## Release builds

Use the matching Flutter build command for each platform:

```sh
flutter build apk --release
flutter build appbundle --release
flutter build ios --release --no-codesign
flutter build web --release
flutter build windows --release
flutter build macos --release
flutter build linux --release
```

iOS App Store distribution requires Apple signing certificates and provisioning profiles. Store publishing is intentionally not part of CI.
