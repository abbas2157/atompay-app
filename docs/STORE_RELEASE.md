# Store release checklist: Google Play & App Store

What's done in the code, what the server must ship first, and the answers for the store
consoles. Package / bundle id: `com.ecommerce.atompay` (prod flavour).

## 1. Blockers: server work before submitting

See [backend/STORE_COMPLIANCE_PROMPT.md](backend/STORE_COMPLIANCE_PROMPT.md). None of the following can
be skipped:

- [ ] `POST /me/delete` live (the app's **Account → Delete account** calls it).
- [ ] `https://atompay.shop/privacy-policy` live and public.
- [ ] `https://atompay.shop/account/delete` live (Play's "delete account" URL).
- [ ] Password-reset → login bug fixed (reviewers can't sign in otherwise).
- [ ] Two review accounts seeded (one with a plan, one empty for testing deletion).

## 2. Business / legal: confirm before submitting

AtomPay finances AtomShop purchases in instalments, which both stores treat as **lending**.

- [ ] **Apple 5.1.1(ix)**: financial-services apps must be submitted from an **Organization** developer
      account in the name of the legal entity that provides the service (not an individual account).
- [ ] **Apple 3.2.2(ix)**: personal-loan apps must clearly show all terms, including the maximum
      equivalent **APR** and due dates. They may **not exceed 36% APR** (including fees) and may not require
      full repayment within 60 days. Work out the equivalent APR of the instalment markup. If it's above
      36%, Apple will reject the app.
- [ ] **Google Play Financial features declaration** (Policy → App content): declare
      "Buy now, pay later / point-of-sale financing" or "Personal loans", whichever applies. For **Pakistan**,
      Google requires personal-loan apps to be run by an entity licensed by the **SECP** (NBFC lending
      licence) and to upload proof. Check with legal which category AtomPay falls into, and have the
      licence document ready.
- [ ] Play listing description must show: minimum and maximum repayment period, maximum APR, a
      representative example of the total cost, and the licensed entity's name. Apple wants the same in
      the app/listing.
- [ ] **Google Play personal accounts** created after Nov 2023 must run a **closed test with at least 12
      testers for 14 days** before production. Organization accounts are exempt.

## 3. Done in the app

| Requirement | Where |
|---|---|
| In-app account deletion (Apple 5.1.1(v), Play account-deletion policy) | Account → Delete account (`DeleteAccountScreen`), password-confirmed, explains what is kept |
| Privacy policy reachable in the app | Account → Legal → Privacy policy; Sign-up screen. URL from `/app-config.privacy_url`, default `https://atompay.shop/privacy-policy` |
| Terms link | Shown when `/app-config.terms_url` is set |
| iOS privacy manifest | `ios/Runner/PrivacyInfo.xcprivacy` (collected data + UserDefaults reason `CA92.1`), registered in the Xcode project |
| iOS export compliance | `ITSAppUsesNonExemptEncryption = false` (HTTPS only), so no questionnaire per build |
| iPhone only | `TARGETED_DEVICE_FAMILY = 1`: no iPad screenshots or iPad review |
| Permission strings | Camera, photo library, Face ID in `Info.plist` |
| Android target SDK | 36 (Flutter 3.47 default). Meets Play's current requirement |
| No sensitive Android permissions | Only `INTERNET`, `USE_BIOMETRIC`. `image_picker` uses the system photo picker, so no `READ_MEDIA_*` and no photo/video permission declaration |
| HTTPS only | `network_security_config.xml` (Android), ATS default (iOS) |
| No backups of the session | `allowBackup=false` + `data_extraction_rules.xml` |
| Screenshot protection on KYC screens | `FLAG_SECURE` / iOS snapshot cover |
| Release signing | `android/key.properties` (not committed). Release falls back to debug keys without it, and **Play rejects that** |

## 4. Build commands

```sh
# Bump pubspec.yaml version (e.g. 1.0.0+2) for every upload.
flutter build appbundle --release --flavor prod --dart-define-from-file=env/prod.json
flutter build ipa       --release --dart-define-from-file=env/prod.json
```

Check before uploading: `android/key.properties` exists (upload key), Play App Signing is enabled, and
the iOS archive is signed with the distribution certificate and an App Store provisioning profile.

## 5. Google Play Console answers

**App access**: "All or some functionality is restricted". Give the review account's email and
password, and note: "Sign in on the first screen. CNIC upload screens block screenshots by design."

**Ads**: No ads.

**Content rating** (IARC): Finance/utility. No violence or sexual content, no gambling, no user-generated
content shared with others. Users interact with the business only.

**Target audience**: 18 and over only.

**Data safety**:

| Data type | Collected | Shared¹ | Required | Purpose |
|---|---|---|---|---|
| Personal info → Name | Yes | No | Yes | App functionality, Account management |
| Personal info → Email address | Yes | No | Optional (email *or* phone) | Account management, Communications |
| Personal info → Phone number | Yes | No | Optional (email *or* phone) | Account management, Communications |
| Personal info → Address | Yes | No | Yes | App functionality, Fraud prevention |
| Personal info → Other info (CNIC number) | Yes | No | Yes | Fraud prevention, security & compliance |
| Financial info → Credit score / credit info | Yes | No | Yes | App functionality |
| Financial info → Other financial info (income, employment) | Yes | No | Yes | App functionality |
| Financial info → Purchase history (AtomShop instalment orders) | Yes | No | Yes | App functionality |
| Photos and videos → Photos (CNIC images, selfie) | Yes | No | Yes | Fraud prevention, security & compliance |
| App info & performance, Device IDs, Location, Contacts, Messages | **No** | – | – | – |

- Data is encrypted in transit: **Yes**.
- Users can request deletion: **Yes**. URL: `https://atompay.shop/account/delete`.
- Data is processed ephemerally: No.

¹ Sending data to AtomShop.pk counts as "sharing" unless AtomShop is the same legal entity or acts as
AtomPay's service provider. Confirm with legal. Email/WhatsApp providers are service providers, so not
sharing.

**Government app / Health / News / COVID**: No.

**Store listing assets**: 512×512 icon, 1024×500 feature graphic, at least 2 phone screenshots,
short description (80 chars) and full description including the lending disclosures from section 2.

## 6. App Store Connect answers

**App Privacy** (must match `PrivacyInfo.xcprivacy`). All items are *linked to the user*, *not used
for tracking*, purpose *App Functionality*: Name, Email Address, Phone Number, Physical Address, Photos
or Videos, Credit Info, Other Financial Info, User ID, Other Data (CNIC number). Tracking: **No**.

**Age rating**: answer No to every content question, then set the age rating to **18+** because the
service is lending.

**Category**: Finance.

**App Review information**: the review account credentials, a contact phone number, and notes:
"AtomPay is the instalment-financing service of AtomShop.pk. Accounts are deleted in Account → Delete
account (the second review account has no open plans, so it can be deleted). Identity-document screens
block screenshots by design."

**Screenshots**: 6.9" iPhone (1320×2868). Only iPhone is needed, since the app is iPhone-only.

**Privacy policy URL**: `https://atompay.shop/privacy-policy`. **Support URL**: required. Use a public
page with contact details.

**Encryption**: answered by `ITSAppUsesNonExemptEncryption` in Info.plist.

## 7. After approval

- [ ] Send the store URLs to the backend owner for `/app-config.store_url` (`ATOMPAY_APP_STORE_*`).
- [ ] Keep `min_version` at `1.0.0` until a forced update is needed.
