# InterestEstimator

A simple Flutter application for Android.

## Getting Started

### Prerequisites

- Flutter SDK (3.24.5 or later)
- Android SDK
- Java 17

### Running Locally

```bash
flutter pub get
flutter run
```

### Building APK

```bash
flutter build apk --release
```

The APK will be available at `build/app/outputs/flutter-apk/app-release.apk`

## GitHub Actions

This project includes a GitHub Actions workflow that automatically builds APK files on every push to main/master branches.

### Downloading APK from Actions

1. Go to the **Actions** tab in the repository
2. Click on the latest successful workflow run
3. Scroll down to the **Artifacts** section
4. Download `release-apk` or `debug-apk`

## Codespaces

This project is configured to work with GitHub Codespaces. Simply open the repository in Codespaces and the Flutter SDK will be automatically installed.

### Using Codespaces

1. Click the green **Code** button on the repository page
2. Select the **Codespaces** tab
3. Click **Create codespace on main**
4. Wait for the environment to be set up
5. Run `flutter pub get` to install dependencies
6. Build APK with `flutter build apk`