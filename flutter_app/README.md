# ISH Flutter application

Flutter client for the Connect-api FastAPI backend.

## Run locally

```sh
cd flutter_app
flutter create --platforms=android --project-name ish_app --org com.connectapi .
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

The default URL targets a backend running on the host machine from the Android emulator. For a physical device, use a reachable LAN URL or HTTPS deployment URL. Production should use HTTPS.
