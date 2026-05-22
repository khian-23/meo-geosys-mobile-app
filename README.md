# MEO GeoSys Mobile App

Flutter source for the client mobile application flow.

## Capture flow
- Login or register
- Start a new application
- Walk to each corner of the desired lot
- Record every corner coordinate
- Review the polygon boundary
- Submit the application and optional attachments

## Notes
- The Flutter SDK is not available on PATH in this workspace, so this app was scaffolded manually instead of through `flutter create`.
- Update the backend URL in `lib/src/state/session_controller.dart` if your emulator or device uses a different host.
