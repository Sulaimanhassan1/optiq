# Optiq · Edgecraft Labs

Optiq is an offline-first Flutter document scanner for iOS, iPadOS, and Android. It captures or imports a page, performs Latin OCR locally with ML Kit, offers filename review and optional grayscale, and saves an encrypted image-only PDF to the local library.

## Development

Use Flutter 3.50 with Dart 3.12 or later, Xcode for iOS, and the Android SDK with its command-line tools and a JDK suitable for the checked-in Gradle wrapper. Run from this directory:

```sh
flutter doctor -v
flutter pub get
flutter analyze
flutter test
flutter devices
flutter run -d <device-id>
```

iOS targets 15.5 or later. Open `ios/Runner.xcworkspace` in Xcode and choose the Runner scheme. SwiftPM resolves the native plugins. `ios/Runner/LatinOCRResources.bundle` matches the [ML Kit SwiftPM 9.0.3 release](https://github.com/d-date/google-mlkit-swiftpm/releases/tag/9.0.3). Update the resource when updating the corresponding binary distribution. On a physical iPhone or iPad, select your Apple development team and provision the device before running. Android uses built-in Kotlin and the system photo picker where available. Camera and photo access are requested by the platform picker.

## Architecture

`lib/main.dart` wires dependencies. `application/` owns state and coordinates capture, review, persistence, and export. `ui/` renders that state, including busy and error feedback, and uses the system appearance and text scaling. `capture/` wraps native camera and photo selection, including Android lost-picker recovery. `vision/` normalizes orientation and geometry, `enhancement/` applies color processing, and `ocr/` wraps the on-device recognizer. `export/` renders PDFs and hands off user-initiated shares to the OS. `core/` records local timing spans and error types in DevTools without logging document text or paths.

`documents/` opens a versioned SQLite schema. Titles and PDFs use AES-256-GCM with authenticated document context. The device-local key is held in platform secure storage. Document metadata and bounded ciphertext chunks commit in one transaction. Listing reads title metadata only. Image decoding, PDF rendering, and bulk cryptography run in Dart isolates. Captures are constrained to 24 MiB with a 16-megapixel decode limit for export. Older prototype PDFs up to 24 MiB are migrated on startup and their plaintext originals are removed after the encrypted insert commits. Larger legacy files remain in the old folder and are outside the encrypted library.

The SQLite container still exposes row counts, timestamps, and approximate sizes. The device-bound key is required to reopen the vault. This version has no recovery or cross-device vault transfer. Scanning and sharing involve temporary plaintext in OS/plugin caches. Optiq removes its capture copies after processing and clears its own export staging files after sharing or at the next launch. The receiving app and OS/plugin share caches have independent lifecycles.

`ml/` defines a personalization integration point and a model verification policy. A model candidate must match the model ID and runtime version, advance beyond the highest accepted version supplied by the caller, and pass SHA-256 and Ed25519 verification against the trusted key. No personalization runtime, trained model, signing key, update feed, or activation registry ships with this app. Until an engine is wired in, filenames come from the first non-empty OCR line and manual edits. The current vision module provides resize and orientation normalization. Perspective detection, searchable or multi-page PDF generation, biometric app lock, and learned enhancement require additional implementations.

## Test the mobile workflow

The Dart suite covers filename normalization, ciphertext authentication, PDF generation, the signed-model policy, and library UI state. The iOS UI test imports a real image, checks ML Kit’s exact OCR result, saves a PDF, and reopens the library after relaunch to check persistence. With an iPhone simulator booted, seed the fixture as its newest photo:

```sh
flutter build ios --simulator
xcrun simctl addmedia booted ios/RunnerUITests/ocr-sample.png
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner \
  -destination 'platform=iOS Simulator,id=<simulator-udid>' \
  -clonedSourcePackagesDirPath build/ios/SourcePackages \
  -parallel-testing-enabled NO -only-testing:RunnerUITests test
```

On Android, use `flutter build apk --debug` and run the same import, OCR, save, and relaunch sequence on an emulator. Use physical iOS and Android devices to verify camera capture, permission changes, and the share sheet. Use sample documents until deployment security and device behavior have been reviewed.
