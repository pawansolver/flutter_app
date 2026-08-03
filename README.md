# my_first_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## API configuration

Development builds default to the local backend (`10.0.2.2` on the Android
emulator and `localhost` on other platforms), so local HTTP remains available
only through the Android debug manifest.

Release builds must provide an absolute HTTPS API URL:

```sh
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.example.com/api/v1
```

The same origin is used for Socket.IO. A release build without
`API_BASE_URL`, or with a non-HTTPS value, fails at runtime before making a
network request. Do not add cleartext exceptions to the main Android manifest
or iOS transport-security exceptions for production.

## Platform permissions

The app requests camera access when taking profile or chat photos and
microphone access when recording a voice note. Gallery selection uses the
system picker, so Android storage and broad media-library permissions are not
declared. On iOS, camera, photo-library, microphone, and foreground-location
usage descriptions are configured in `Info.plist`.
