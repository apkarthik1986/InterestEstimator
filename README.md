# InterestEstimator

A simple Flutter application for calculating pawn broker loan interest.

## Features

- **Simple Input**: 3 inputs - Loan Amount, Interest Rate, and Loan Date
- **Configurable Interest Rate**: Set your own monthly interest rate (default: 2%)
- **Auto-calculation**: Automatically calculates duration from loan date to today
- **Clear Summary**: Shows loan amount, duration, interest breakdown, and total amount
- **Google Sheets Integration**: Link to your Google Drive Excel file for real-time loan lookup

## Google Sheets Setup

### Excel Format

Your Google Sheet should have the following columns:

| Column A | Column B | Column C |
|----------|----------|----------|
| Date | Loan Number | Amount |
| 15/06/2024 | 12345 | 50000 |
| 20/07/2024 | 12346 | 75000 |

- **Column A**: Date in DD/MM/YYYY format
- **Column B**: Loan Number (numeric)
- **Column C**: Loan Amount (numeric)
- **Row 1**: Should contain headers

### Publishing Your Google Sheet

1. Open your Google Sheet in Google Drive
2. Go to **File → Share → Publish to web**
3. In the dialog that opens:
   - Select the specific sheet tab (e.g., "Sheet1")
   - Choose **Comma-separated values (.csv)** as the format
4. Click **Publish**
5. Copy the generated URL
6. In the app, go to **Settings** (gear icon) and paste the URL in the "Google Sheet CSV URL" field

### Permissions

- Your Google Sheet only needs to be **Published to web** (File → Share → Publish to web)
- You do NOT need to share the sheet publicly or with anyone
- The published CSV link allows read-only access to the data
- Changes made to the Google Sheet are automatically reflected when you click **Search** in the app (real-time updates)

**Note**: Publishing to web is different from sharing. Your sheet remains private, but the published CSV link can be accessed by anyone with the URL.

## Interest Calculation

The app uses the following calculation logic (based on industry standard):

- **Interest Rate**: Configurable per month (default 2%)
- **Duration**: Calculated using year fraction method with special rounding:
  - If fractional month >= 0.07, rounds up
  - Otherwise, rounds down
- **Total Interest**: Interest per month × Number of months
- **Total Amount**: Loan Amount + Total Interest

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