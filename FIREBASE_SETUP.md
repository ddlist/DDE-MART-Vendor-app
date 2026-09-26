# Firebase setup — DDE Vendor

Push code is wired (`lib/core/push.dart`, topic `vendors`, token at
`POST /vendor/push-tokens` after sign-in). Only native config is missing.

1. Firebase project: Android app `com.ddemart.dde_vendor`
   (iOS bundle ID identical). May share the project with customer/driver.
2. `google-services.json` → `android/app/`;
   `GoogleService-Info.plist` → `ios/Runner/` (add to Xcode).
3. No Dart changes. Without the files, push skips gracefully.
4. Test: sign in → place a food order / dine-in request for your store →
   vendor gets the broadcast → accept it in Orders.
