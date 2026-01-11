# Agent Instructions

## Finalizing
Before finishing a task or submitting changes, you MUST:
1. Run `dart format .` to ensure all code matches the project's style guidelines.
2. Run `flutter analyze` and fix any reported errors or warnings.
3. Run `flutter test`. If the project lacks relevant tests, ensure it builds successfully using `flutter build <platform>` (e.g., `flutter build linux` or `flutter build apk`).

## Environment Note
If you are in an environment where the Flutter SDK is not available or not configured, you may defer the above commands to the CI pipeline. The CI is configured to run these checks automatically.
