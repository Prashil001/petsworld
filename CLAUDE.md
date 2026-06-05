# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Commands

```bash
# Install dependencies
flutter pub get

# Run the app (mobile)
flutter run

# Run the admin web build
flutter run -d chrome --target lib/admin_web_main.dart

# Build Android APK
flutter build apk

# Run tests
flutter test

# Run a single test file
flutter test test/widget_test.dart

# Analyze code
flutter analyze

# Format code
dart format lib/
```

## Architecture Overview

This is a Flutter e-commerce app for a pet store with two entry points:
- **`lib/main.dart`** — mobile app (iOS/Android)
- **`lib/admin_web_main.dart`** — admin web panel

### State Management: Provider

All state lives in `lib/providers/` as `ChangeNotifier` classes. They are wired together in `lib/core/app/app_scope.dart` via `MultiProvider`. The 7 providers are: `AuthProvider`, `ProductProvider`, `CartProvider`, `OrderProvider`, `AddressProvider`, `AdminProvider`, `ThemeProvider`.

Providers depend on repositories (also provided via `MultiProvider`). Never call Firestore directly from UI — go through a repository.

### Data Layer: Repository Pattern

`lib/repositories/` contains abstract interfaces + Firebase implementations for each data domain. Each repository maps to one or more Firestore collections:

- `users/{uid}` — auth profile
- `users/{uid}/addresses/`, `users/{uid}/bookmarks/`, `users/{uid}/cart/` — user sub-collections
- `products/`, `categories/`, `orders/`, `coupons/` — top-level collections
- `products/{id}/reviews/` — nested reviews
- `storefront/` — banners, delivery settings, payment config

### Session Sync

`_SessionSyncGate` in `main.dart` listens to auth state and triggers `syncForUser(userId)` on `CartProvider`, `ProductProvider`, and `OrderProvider` whenever the user changes. This is how Firestore data gets loaded into memory on login.

### Navigation

Named route system in `lib/route/router.dart` using `onGenerateRoute`. Route name constants are in `lib/route/route_constants.dart`. Screen imports are centralized in `lib/route/screen_export.dart`. Arguments between routes are passed as typed model objects (e.g., `ProductModel`, `OrderModel`).

The main app shell is `lib/entry_point.dart` — a 4-tab bottom nav (Shop, Discover, Saved, Profile) using `PageTransitionSwitcher` with `FadeThroughTransition`.

### Authentication

Three flows all handled by `AuthProvider` + `AuthRepository`:
1. Email/password (requires email verification)
2. Google Sign-In (requires SHA-1/SHA-256 in Firebase Console)
3. Phone OTP (`requestPhoneOtp` → `verifyPhoneOtp`)

Role-based access: `AppUserModel.role` is stored in Firestore. `AuthProvider.isAdmin` gates admin screens. The admin web panel checks this role before rendering any admin UI.

### Payments

`lib/core/services/checkout_api_service.dart` makes HTTP calls to a Razorpay backend (URL configured in `lib/core/config/payment_config.dart`). Supports Razorpay online payment and Cash on Delivery. Payment settings (enabled methods, runtime config) are fetched from Firestore `storefront/` at app start.

### Image Storage

Cloudinary is used for product images. `lib/core/services/cloudinary_service.dart` handles upload to the `petsworld/products` folder using an unsigned upload preset. Image deletion is intentionally disabled on the client (requires API secret).

### Firebase Setup

- `lib/firebase_options.dart` — generated config (do not edit manually)
- `firestore.rules` / `storage.rules` — security rules
- `functions/` — Cloud Functions (if any backend logic)
- `firebase.json` — project config

### Theming

`lib/theme/app_theme.dart` provides light and dark `ThemeData`. Fonts used: Manrope (body), Space Grotesk (headings) via Google Fonts. Local custom fonts (Plus Jakarta, Grandis Extended) are declared in `pubspec.yaml` and loaded from `assets/`. `ThemeProvider` persists user preference via SharedPreferences.

### Android Build Notes

- Gradle wrapper is set to **8.14** (cached at `~/.gradle/wrapper/dists/gradle-8.14-all/`)
- Release builds use ProGuard (`android/app/proguard-rules.pro`)
- Signing config: `android/key.properties` (not committed)
- Min SDK: 21 | App ID: `com.petsworld.shop`
- `android/gradle.properties`: JVM heap set to `-Xmx4G`, Kotlin incremental disabled
