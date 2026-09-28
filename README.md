# AtomPay mobile

Customer app for AtomPay (buy now, pay in instalments on AtomShop.pk). Flutter, Android + iOS.

The full spec (product, architecture, design, screens, rules, tasks, API) is
[docs/MOBILE_APP_HANDBOOK.md](docs/MOBILE_APP_HANDBOOK.md). The API contract is [docs/api/](docs/api/).

## Setup

```sh
flutter pub get
flutter gen-l10n
dart run build_runner build
```

Generated files (`*.g.dart`, `*.freezed.dart`, `lib/l10n/gen/`) are not committed. CI generates them.

## Run

Each flavour pairs an Android product flavour with a Dart defines file:

| Flavour | Command | API |
|---|---|---|
| dev | `flutter run --flavor dev --dart-define-from-file=env/dev.json` | `http://10.0.2.2/atompay/api/v1` (Android emulator → local XAMPP) |
| staging | `flutter run --flavor staging --dart-define-from-file=env/staging.json` | TBD |
| prod | `flutter run --flavor prod --dart-define-from-file=env/prod.json` | `https://atompay.shop/api/v1` |

On a real phone in dev, change `API_BASE_URL` to `http://<PC-LAN-IP>/atompay/api/v1`. Cleartext HTTP is allowed
in the dev flavour only.

In dev, one-time codes aren't really sent. They're in the server's `storage/logs/laravel.log`.

## Checks (same as CI)

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

## Package ids

| Flavour | Android `applicationId` |
|---|---|
| dev | `com.ecommerce.atompay.dev` |
| staging | `com.ecommerce.atompay.staging` |
| prod | `com.ecommerce.atompay` |

iOS bundle id is `com.ecommerce.atompay`. iOS flavours (schemes + xcconfigs) still need to be set up on a Mac.
