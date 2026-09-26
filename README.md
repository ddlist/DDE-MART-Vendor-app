# DDE-Mart vendor app (clean-room rebuild)

Fresh Flutter app against `admin-panel` API v1 vendor surfaces
(`docs/api-v1.md`, Vendor app section). No legacy code.

## Run

```sh
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

## What's wired

- Launch gate (`/app-config`, `vendor` audience) + maintenance/update screens.
- OTP sign-in with vendor/owner role switch, profile, sign out.
- Orders inbox: own-store orders with accept/cancel on placed orders.
- Dine-in inbox: machine-driven moves
  (pending → confirmed/cancelled → seated → completed).
- Catalog: store open/close toggles, product active toggles.
- Payouts: history + request.

## Next (not yet)

- Push: `firebase_messaging`, topic `vendors`, token at `POST /push-tokens`.
- Product create/edit (backend: admin-owned for now), order detail view.
- Firebase native files per environment (not in repo).

## Verify

```sh
flutter analyze
flutter test
```
