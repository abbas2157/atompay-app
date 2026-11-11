# Store release checklist: Google Play & App Store

What's done in the code, what the server must ship first, and the answers for the store
consoles. Package / bundle id: `com.ecommerce.atompay` (prod flavour).

## 1. Blockers: server work before submitting

See [backend/SERVER_RELEASE_PROMPT.md](backend/SERVER_RELEASE_PROMPT.md). None of the following can
be skipped:

- [ ] `POST /me/delete` live (the app's **Account → Delete account** calls it).
- [ ] `https://atompay.shop/privacy-policy` live and public.
- [ ] `https://atompay.shop/delete-account` live (Play's "delete account" URL; must match
      `/app-config.account_deletion_url`).
- [ ] Password-reset → login bug fixed (reviewers can't sign in otherwise).
- [ ] Two review accounts seeded (one with a plan, one empty for testing deletion).

### Switching push on

The app's push code is built. It stays off until all three of these are done:

- [ ] Register AtomPay in the **same Firebase project the server sends from** (`atomshop-a726c` holds
      Atomshop and Atom Seller): an Android app `com.ecommerce.atompay` (plus `.dev`/`.staging` if those
      builds should get pushes) and an iOS app `com.ecommerce.atompay`.
- [ ] Copy the values into `env/<flavor>.json`: `FIREBASE_PROJECT_ID`, `FIREBASE_SENDER_ID`,
      `FIREBASE_ANDROID_API_KEY`, `FIREBASE_ANDROID_APP_ID`, `FIREBASE_IOS_API_KEY`, `FIREBASE_IOS_APP_ID`,
      `FIREBASE_IOS_BUNDLE_ID` (Firebase console → Project settings → Your apps). No
      `google-services.json` or `GoogleService-Info.plist` is needed.
- [ ] iOS: upload an APNs key to that Firebase project, and turn on **Push Notifications** for the App ID
      (the app already has `Runner.entitlements` and the `remote-notification` background mode).
- [ ] Server: FCM credentials set, so `/app-config` sends `features.push: true`.

Then the app shows the notifications explainer after sign-in, registers with `POST /devices`, removes the
token with `DELETE /devices` on sign-out, opens the right screen from a tapped push and shows a toast for
one that arrives while it is open.

### Fields the app is ready for (server work)

The app shows these as soon as the API sends them, and leaves the line out until then (it never computes
money itself):

- [ ] `GET /dashboard` → `limit.available_after_next`: Home "After 10 Jan you will have Rs. 44,332" and
      Ask Atom "Rs. 44,332 once January is paid".
- [ ] `GET /dashboard` → `lowest_eligible_price`: Home "The lowest-priced eligible product is Rs. 47,000".
- [ ] `GET /plans`, `GET /plans/{id}` → `order.delivered_at`: "delivered 9 Nov" on the order card and the
      status chain.
- [ ] Instalments → `paid_via` (e.g. `"JazzCash"`): "paid 9 Nov by JazzCash".

## 2. Business / legal: confirm before submitting

AtomPay finances AtomShop purchases in instalments, which both stores treat as **lending**.

- [ ] **Apple 5.1.1(ix)**: financial-services apps must be submitted from an **Organization** developer
      account in the name of the legal entity that provides the service (not an individual account).
- [ ] **Apple 3.2.2(ix)**: personal-loan apps must clearly show all terms, including the maximum
      equivalent **APR** and due dates. They may **not exceed 36% APR** (including fees) and may not require
      full repayment within 60 days. Work out the equivalent APR of the instalment markup. If it's above
      36%, Apple will reject the app.
- [ ] **AtomPay is not SECP-registered.** Atomshop sells on instalments itself (merchant credit, no
      lender), and the app claims no licence anywhere. **This is the biggest store risk:**
      - For Pakistan, Google Play requires **personal-loan** apps to be run by an SECP-licensed NBFC, with
        proof uploaded. An unlicensed app declared as a personal loan will be rejected.
      - Declare AtomPay in the **Financial features declaration** (Policy → App content) as
        **"Buy now, pay later / point-of-sale financing"** offered by the merchant, not as a personal loan.
      - Get legal confirmation, in writing, that 0% markup instalments sold by Atomshop itself need no SECP
        licence. Google may ask for it.
      - Apple 3.2.2(ix) is written for loan apps. The KFS and the APR must still be shown, and the review
        notes should explain the merchant-instalment model.
- [ ] Play listing description must show: minimum and maximum repayment period, maximum APR, a
      representative example of the total cost, and the company offering the instalments (Atomshop's
      registered company). Apple wants the same in the app/listing.
- [ ] **Company details from the Atomshop admin panel** (`/app-config.business`, server prompt item 7),
      shown in rose until set:
      - company name and registered address;
      - data location;
      - late-payment and early-settlement terms;
      - complaint response time.

      Still open in the app itself:
      - the APR/fee decision (KFS);
      - Help answers for Getting started, Applying & KYC and Account;
      - the support WhatsApp/phone/email in `/app-config.support` (those rows stay hidden while null).
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
| Permission strings | Camera, microphone, speech recognition, Face ID in `Info.plist` (no photo library, contacts or location). Checked by `test/release/release_rules_test.dart` |
| iOS permission_handler | `ios/Podfile` enables only `PERMISSION_CAMERA`, `_NOTIFICATIONS`, `_MICROPHONE`, `_SPEECH_RECOGNIZER` |
| Android target SDK | 36 (Flutter 3.47 default). Meets Play's current requirement |
| No sensitive Android permissions | `INTERNET`, `USE_BIOMETRIC`, `CAMERA` (in-app capture), `RECORD_AUDIO` (Ask Atom voice). The camera plugin's `WRITE_EXTERNAL_STORAGE` is stripped. CI builds the prod APK and runs `dart run tool/check_manifest.dart` on the merged manifest (brief §10 forbidden list + allow-list) |
| Permissions asked only when used | Camera on first capture, microphone on first mic tap, each after an explainer; nothing at launch |
| HTTPS only | `network_security_config.xml` (Android), ATS default (iOS) |
| No backups of the session | `allowBackup=false` + `data_extraction_rules.xml` |
| Screenshot protection | `FLAG_SECURE` / iOS snapshot cover on capture, document and KFS screens |
| In-app grievance route | Help › Raise a complaint → reference number |
| Store review prompt | Rate AtomPay opens the listing only; no rating gate, no `requestReview()` from a button |
| Accessibility | `test/a11y`: Android/iOS tap targets, labels and text contrast on every screen; 200% text without overflow |
| Design fidelity | `test/goldens`: one image per canvas board (`flutter test --tags golden`, generated on Windows) |
| Release signing | `android/key.properties` (not committed). Release falls back to debug keys without it, and **Play rejects that** |

## 4. Build commands

```sh
# Bump pubspec.yaml version (e.g. 1.0.0+2) for every upload.
flutter build appbundle --release --flavor prod --dart-define-from-file=env/prod.json
dart run tool/check_manifest.dart   # fails on any forbidden permission
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
| Messages → Other in-app messages (complaints, Ask Atom questions) | Yes | No | Optional | App functionality, Customer support |
| Audio → Voice or sound recordings | **No**² | – | – | – |
| App info & performance, Device IDs, Location, Contacts, Messages | **No** | – | – | – |

- Data is encrypted in transit: **Yes**.
- Users can request deletion: **Yes**. URL: `https://atompay.shop/delete-account`.
- Data is processed ephemerally: No.

¹ Sending data to AtomShop.pk counts as "sharing" unless AtomShop is the same legal entity or acts as
AtomPay's service provider. Confirm with legal. Email/WhatsApp providers are service providers, so not
sharing.

² Ask Atom voice uses the phone's own speech recogniser; only the resulting text is sent to AtomPay.
Confirm with legal how Google/Apple's recogniser processing should be disclosed.

**Government app / Health / News / COVID**: No.

**Store listing assets**: 512×512 icon, 1024×500 feature graphic, at least 2 phone screenshots,
short description (80 chars) and full description including the lending disclosures from section 2.

## 6. App Store Connect answers

**App Privacy** (must match `PrivacyInfo.xcprivacy`). All items are *linked to the user*, *not used
for tracking*, purpose *App Functionality*: Name, Email Address, Phone Number, Physical Address, Photos
or Videos, Credit Info, Other Financial Info, User ID, Customer Support (complaints), Other User Content
(Ask Atom questions), Other Data (CNIC number). Tracking: **No**.

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
