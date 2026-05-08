# Hustly Setup Guide

This document explains the intended project structure and the Firebase-backed app setup.

## Recommended App Structure

The Flutter codebase is organized by feature:

- `lib/app` for app initialization, routing, and theme setup.
- `lib/core` for shared utilities, helpers, constants, and reusable widgets.
- `lib/features/auth` for login, registration, and verification flow.
- `lib/features/profile` for profile data and QR configuration.
- `lib/features/ride_pooling` for student ride requests, applications, and trip management.
- `lib/features/delivery` for seller delivery jobs, driver applications, and proof handling.
- `lib/features/chat` for request-based chat groups.
- `lib/features/map` for browsing open requests on a map.
- `lib/features/notifications` for notifications.
- `lib/features/admin` for driver verification, disputes, and moderation.
- `lib/features/disputes` for report handling and case tracking.

## Firebase Opinion

You do not need a separate top-level Firebase folder unless you want to store configuration files or helper classes in one place. My recommendation for Flutter is:

- Keep Firebase configuration files at the project root level as required by Flutter/Firebase tooling.
- Put Firebase service wrappers inside `lib/core/services` or `lib/core/firebase` if you prefer a dedicated namespace.
- Keep feature-specific Firestore logic inside the relevant feature folder, not in one giant Firebase folder.

That approach stays clean as the app grows.

## Database

The Firestore schema is documented in [docs/firebase_schema.md](docs/firebase_schema.md).

## How To Run

1. Install Flutter SDK.
2. From the project root run:

```bash
flutter pub get
```

3. Add your Firebase platform configuration files for Android, iOS, and web.
4. Launch the application:

```bash
flutter run
```

To run on web:

```bash
flutter run -d chrome
```