# Nivora

Cross-platform Flutter starter app for Bluetooth device control (Android, iOS, Mobile Web).

## Quick start

1. Ensure Flutter is installed (your Flutter doctor must be all green).
2. In the project directory run:
   ```
   flutter pub get
   flutter run
   ```
   For web:
   ```
   flutter run -d chrome
   ```

## Notes

- Mobile BLE uses `flutter_blue_plus`.
- Web BLE uses the browser Web Bluetooth API via JS added in `web/index.html` and Dart JS interop `lib/services/web_ble.dart`.
- Login/register are mocked. Replace `ApiService` with your backend endpoints.
- OTA and device protocol are scaffolded; implement your specific protocol in `BluetoothService`.
