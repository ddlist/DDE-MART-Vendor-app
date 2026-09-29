# DDE-Mart Vendor App

The store-owner Flutter app for the DDE-Mart platform: orders, dine-in,
catalog, coupons, payouts, chat and subscription — against one backend API.

- Backend: [DDE-MART-BACKEND](https://github.com/ddlist/DDE-MART-BACKEND) (`master`)
- API reference: `admin-panel/docs/api-v1.md` (Vendor app section)

## Features

- **Auth** — OTP sign-in with vendor/owner role switch, profile edit,
  sign out.
- **Orders inbox** — own-store orders with status tabs, order detail
  (bill, timeline), machine-driven transitions.
- **Dine-in inbox** — bookings with confirm/seat/complete flow.
- **Catalog** — stores list with open/close toggles, products with
  active toggles, product create/edit with photo upload.
- **Coupons** — vendor-scoped coupon create/edit with usage limits.
- **Payouts** — history + requests (bank/paypal/stripe/razorpay/
  flutterwave/cash), subscription plans.
- **Chat** — two-sided order threads with reply.
- **Platform** — launch gate (`/app-config`), FCM push (`vendors`
  topic), dark mode, runtime permission flows (photos, notifications),
  tolerant form dropdowns with empty-state hints.

## Setup

Prerequisites: Flutter 3.41+ (`flutter doctor` clean), Android Studio or
Xcode, and the backend running (see backend README).

```sh
git clone https://github.com/ddlist/DDE-MART-Vendor-app.git vendor
cd vendor
flutter pub get
```

## Run

```sh
# Herd/Valet domain (default baked into lib/core/config.dart):
flutter run --dart-define=API_BASE_URL=http://dde-mart-admin.test/api/v1

# Android emulator when .test doesn't resolve there:
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1

# Physical phone (same Wi-Fi; backend on 0.0.0.0:8000):
flutter run --dart-define=API_BASE_URL=http://<pc-lan-ip>:8000/api/v1
```

Test accounts: create the owner in the admin panel (Owners page, status
`active`, link stores to it), then sign in with phone + OTP. Demo OTP
codes appear in the backend log outside production.

## Release build

```sh
flutter build appbundle --dart-define=API_BASE_URL=https://api.your-domain.com/api/v1
flutter build ipa      --dart-define=API_BASE_URL=https://api.your-domain.com/api/v1
```

Push needs `google-services.json` / `GoogleService-Info.plist` per
environment (see `FIREBASE_SETUP.md`) — never committed.

## Verify

```sh
flutter analyze   # clean
flutter test      # 13 tests: dine-in machine, nav guards, API parity, boot
```

## Support

Installation, tech support, customization: **shariqq.com@gmail.com** ·
WhatsApp **@shareeq9**.

## Credits

Built by [DDLIST](https://ddlist.github.io).

## License

DDLIST Source-Available License v1.0 � see [LICENSE](LICENSE). You may
use and modify the software for personal or business use, but you may
not resell or redistribute it.
