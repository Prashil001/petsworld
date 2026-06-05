# PetsWorld — Flutter + Firebase Pet Store

PetsWorld is a pet products & grooming e-commerce app built with Flutter, with two entry points sharing one codebase:

| Entry | What it is | Where it runs |
|-------|------------|---------------|
| `lib/main.dart` | Mobile shopper app | Android + iOS |
| `lib/admin_web_main.dart` | Admin panel (catalog, orders, banners, settings) | Web (Firebase Hosting) |

**Live admin:** https://pet-shop-app-ee6f2.web.app

---

## Features

### Shopper (mobile)
- Email/password and Phone OTP login
- 4-tab shell: **Shop** · **Discover** · **Saved** · **Profile**
- Home with admin-managed banners + dynamic offer sections
- Category & sub-category browse (Dogs / Cats parent tabs)
- Product details with pack-size options, image gallery, reviews
- Saved items, cart, and order history all synced to Firestore per user
- Cart with **free-delivery progress bar** and coupon support
- Checkout via **Razorpay** (online) or **Cash on Delivery**
- PDF invoice generation + share/print after order
- Light / Dark / Device theme

### Admin (web + mobile)
- Role-gated login (only `role == admin` users get in)
- Dashboard with order stats
- **Manage products** with search bar + low-stock filter (configurable threshold, accounts for pack stock)
- Categories CRUD (parent → child hierarchy)
- Orders: view all, update status (Pending → Completed)
- Home banners & home offer sections (with optional section-level discounts)
- Coupons (flat or percentage)
- Store settings (delivery fee, free-delivery threshold, payment methods)
- Image uploads to Cloudinary

---

## Tech Stack

- **Flutter** (Dart 3.8+)
- **Provider** — state management (7 ChangeNotifiers wired in `lib/core/app/app_scope.dart`)
- **Firebase** — Auth, Cloud Firestore, Hosting
- **Razorpay** (`razorpay_flutter`) for online payments via a hosted backend
- **Cloudinary** — unsigned image uploads to `petsworld/products`
- **pdf** + **printing** — invoice generation
- **Google Fonts** (Manrope / Space Grotesk) + bundled Plus Jakarta / Grandis Extended

## Design System

| Token | Use |
|-------|-----|
| `primaryColor` (purple `#7B61FF`) | Buttons, prices, links, active nav, progress |
| `accentColor` (orange `#E0953D`) | **Deals/sale only** (HOT badges, discount %) |
| `dealBadgeBg` / `dealBadgeText` | Standardized sale-badge colors |
| `errorColor` | Out-of-stock + destructive actions |

All tokens live in `lib/constants.dart`. Don't introduce new accent colors — extend the tokens instead.

---

## Project Structure

```
lib/
  core/
    app/                  # AppScope (MultiProvider wiring)
    config/               # cloudinary_config, payment_config
    services/             # FirebaseBootstrap, Cloudinary, Razorpay, PDF, etc.
    widgets/              # shared widgets (loading, empty states)
  components/             # reusable UI (ProductCard, CategoryTile, ...)
  models/                 # immutable data classes
  providers/              # 7 ChangeNotifiers (Auth, Cart, Product, Order, Address, Admin, Theme)
  repositories/           # abstract interfaces + Firebase implementations
  route/                  # named routes + screen barrel
  screens/                # feature-grouped UI (admin, auth, home, checkout, ...)
  theme/                  # ThemeData, button/input themes
  constants.dart          # design tokens + validators
  main.dart               # mobile entry
  admin_web_main.dart     # admin-web entry

ios/         android/         web/         functions/
codemagic.yaml              firebase.json   firestore.rules / .indexes.json
```

All Firestore access goes through `lib/repositories/` — **never** call Firestore directly from UI.

---

## Firestore Schema

### Top-level collections

#### `users/{uid}`
`uid`, `name`, `email`, `phoneNumber`, `role` (`user` | `admin`), `createdAt`

#### `products/{productId}`
`name`, `brandName`, `description`, `category`, `price`, `salePrice?`, `discountPercent?`, `imageUrl`, `imageUrls[]`, `stockQuantity`, `packOptions[]`, `isActive`, `isFeatured`, `isPopular`, `isNewArrival`, `createdAt`, `updatedAt`

#### `categories/{categoryId}`
`title`, `image?`, `svgSrc?`, `parentId?`, `isActive`, `sortOrder`

#### `orders/{orderId}`
`userId`, `items[]`, `pricing` (subtotal / discount / delivery / total), `payment` (method, status), `deliveryAddress`, `orderStatus`, `createdAt`

#### `coupons/{couponId}`
code, type (`flat` | `percent`), value, validity, min spend.

#### `storefront/*`
Admin-managed singletons: `banners`, `sections`, `delivery_settings`, `payment_settings`.

### User sub-collections
- `users/{uid}/addresses/` — saved delivery addresses
- `users/{uid}/bookmarks/` — saved products
- `users/{uid}/cart/` — cart items

### Product sub-collection
- `products/{productId}/reviews/` — ratings + text reviews

---

## Setup

### 1. Install dependencies
```bash
flutter pub get
```

### 2. Firebase
- `lib/firebase_options.dart` is committed (FlutterFire-generated for project `pet-shop-app-ee6f2`).
- Enable Auth providers in Firebase Console: **Email/Password**, **Phone**.
- Android: add **SHA-1** and **SHA-256** for your debug + release keystores in the Firebase Console (required for Phone auth).
- iOS: `ios/Runner/GoogleService-Info.plist` is committed; for Codemagic builds, set the `GOOGLE_SERVICE_INFO_PLIST` env var (see iOS section below).

### 3. Cloudinary
Edit `lib/core/config/cloudinary_config.dart` — cloud name and unsigned upload preset.

### 4. Razorpay
Edit `lib/core/config/payment_config.dart` — Razorpay key ID and your backend base URL (the backend is a separate service that creates Razorpay orders and verifies payment signatures).

### 5. Run
```bash
# Mobile (Android emulator / connected device)
flutter run

# Admin web (Chrome, hot-reload)
flutter run -d chrome --target lib/admin_web_main.dart
```

---

## Common Commands

```bash
flutter pub get
flutter run                                              # mobile
flutter run -d chrome --target lib/admin_web_main.dart   # admin web (dev)
flutter test                                             # all tests
flutter test test/widget_test.dart                       # single test file
flutter analyze                                          # static analysis
dart format lib/                                         # format
flutter build apk                                        # release APK
flutter build web --target lib/admin_web_main.dart --release   # admin web build
```

---

## Deploy Admin Web (Firebase Hosting)

```bash
flutter build web --target lib/admin_web_main.dart --release
firebase deploy --only hosting
```

Hosting is configured in `firebase.json` to serve `build/web` with cache-busting headers on `index.html`, `flutter_bootstrap.js`, `main.dart.js`, and `flutter_service_worker.js`, so the latest build appears immediately.

---

## Cloud Functions

Located in `functions/`. Deploy with:
```bash
firebase deploy --only functions
```

---

## Notes & Behaviors

- **Cart / saved / orders** are user-scoped and synced via repositories on auth state change (see `_SessionSyncGate` in `lib/main.dart`).
- On successful checkout, cart items are cleared from Firestore.
- Phone-auth users without email in Firebase Auth can still set an email on their Firestore profile.
- Product cards show effective stock from `packOptions` when present; the admin "Manage products" filter respects this.

---

## License

Private project — all rights reserved.
