# Store release checklist: Google Play & App Store

What's done in the code, what the server must ship first, and the answers for the store
consoles. Package / bundle id: `com.ecommerce.atompay` (prod flavour).

## 0. What AtomPay is, for the purpose of these forms

AtomPay is the **instalment payment option for purchases on AtomShop.pk**, which is also how
atompay.shop describes it ("instalment partner of AtomShop.pk"). This matters because the store
policies key off it:

- No money is ever lent to the customer. The app has no wallet, no disbursement, no withdrawal and
  no payout — `grep -rniE "disburse|withdraw|payout|wallet" lib/` returns nothing. A `Plan` is one
  AtomShop order (`PlanOrder.id`, `reference`, `financed`, `advance`, `tenure`) against a
  `PlanProduct`.
- What the customer gets is goods now, paid for over a few months after a 20–60% down payment.

So this is **point-of-sale instalment financing of goods, not a personal loan.** Google defines a
personal loan as lending money to a consumer, excluding financing the purchase of a fixed asset.
Declare **"Buy now, pay later"** in the Play Console financial features declaration, not
"Personal loans".

The app also carries a real identity-verification purpose — details go in once and the approved
limit then carries across AtomShop orders instead of repeating verification per order. That is a
good line for the **listing description**, but it does not replace the financial features
declaration: 58 user-facing strings are credit servicing (`approvedLimitLabel`,
`limitUsedPercent`, `nextDueTitle`, `instalmentLate`, `tenureLabel`), and an inaccurate
declaration is treated far more harshly than the wrong-but-honest category.

## 1. Blockers: server work before submitting

See [backend/SERVER_RELEASE_PROMPT.md](backend/SERVER_RELEASE_PROMPT.md). Verified live on 2026-10-27:

| Check | Result |
|---|---|
| `POST /api/v1/me/delete` (no token) | **401 Unauthenticated** — route exists and is auth-gated |
| `https://atompay.shop/privacy` | **200** — "Privacy policy — AtomPay" |
| `https://atompay.shop/privacy-policy` | **200** — redirects to `/privacy` |
| `https://atompay.shop/delete-account` | **200** — the public deletion page |
| `https://atompay.shop/account/delete` | **404** — does *not* exist. Do not use this URL. |
| `https://atompay.shop/terms` | **404** — consistent with `/app-config.terms_url` being null |

None of the following can be skipped:

- [x] `POST /me/delete` live (the app's **Account → Delete account** calls it).
- [x] `https://atompay.shop/privacy-policy` live and public.
- [x] `https://atompay.shop/delete-account` live (Play's "delete account" URL; must match
      `/app-config.account_deletion_url`).
- [ ] Password-reset → login bug fixed (reviewers can't sign in otherwise).
- [ ] Two review accounts seeded (one with a plan, one empty so deletion can be demonstrated).
- [ ] The deletion page states **how long** retained records are kept. It lists what is deleted and
      what is retained, but gives no retention period, and Play's account-deletion policy asks for
      one. A single sentence fixes it.

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

These are legal questions. Nothing in the code or on the site settles them.

- [ ] **Operating entity.** atompay.shop names no company, no regulator and no licence — only
      "instalment partner of AtomShop.pk" and a Pakistan copyright line. Play expects a financial
      app's listing to name the entity behind the service. The App Store account is
      **Atom Services Private Limited** (House No 240, Block D 2, Lahore, Pakistan); the site, the
      privacy policy and the Play listing should say the same.
- [ ] **SECP.** Google's Pakistan rules require SECP approval to offer *or facilitate* digital
      lending, and allow one app per NBFC lender. "Or facilitate" is broad enough that the
      BNPL classification does not automatically put AtomPay outside it. Whether an instalment
      sale of goods is digital lending under Pakistani law is for counsel, not for this document.
      Get that confirmation in writing — Google may ask for it.
- [ ] **Apple 5.1.1(ix)**: financial-services apps must come from an **Organization** developer
      account in the legal entity's name, not an individual account.
- [ ] **Apple 3.2.1(ix)** — the open risk for iOS. The cap is written for *personal loans*, so on
      the BNPL reading it does not apply. But atompay.shop publishes a 4%/month service charge on
      the financed amount plus a worked example, which makes the rate computable by anyone:

      financed      PKR 80,000   (100,000 product, 20% down)
      monthly pay   PKR 16,533.33 x 6
      total repaid  PKR 99,200   (service charge 19,200)
      monthly IRR   6.52%  ->  nominal APR 78.2%  ->  effective APR 113.3%

      The same figures come out of the live `/quote` endpoint. How Apple treats this is not
      predictable from the guidelines; plan for the question being asked. The KFS and the APR must
      be shown either way, and the review notes should explain the merchant-instalment model.
      Note this is **not** a 0% markup product — any form answer saying so is wrong.
- [ ] **Google's 36% APR cap does not apply.** It is United States–only in the Financial Services
      policy, and this is a Pakistan-only app. (Earlier revisions of this document listed it as a
      Play blocker. It is not one.)
- [ ] Listing description should still state the repayment period range, the service rate, and a
      representative worked example of the total cost. Good practice, and it matches the site.
      Apple wants the same in the app/listing.
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
| Privacy policy reachable in the app | Account → Legal → Privacy policy; Sign-up screen. URL from `/app-config.privacy_url` (currently `https://atompay.shop/privacy`), with a default |
| Terms link | Shown when `/app-config.terms_url` is set. Currently null, so hidden |
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
# Bump pubspec.yaml version for every upload. versionCode must increase
# monotonically and must not collide with anything already on a track.
flutter build appbundle --release --flavor prod --dart-define-from-file=env/prod.json
dart run tool/check_manifest.dart   # fails on any forbidden permission
flutter build ipa       --release --dart-define-from-file=env/prod.json
```

Check before uploading: `android/key.properties` exists (upload key), Play App Signing is enabled,
and the iOS archive is signed with the distribution certificate and an App Store provisioning
profile. Verify the bundle is not debug-signed:

```sh
jarsigner -verify -verbose:summary build/app/outputs/bundle/prodRelease/app-prod-release.aab
keytool -printcert -jarfile build/app/outputs/bundle/prodRelease/app-prod-release.aab
```

The signer's SHA-256 must match the upload keystore's certificate.

## 5. Google Play Console answers

**Financial features declaration**: "Buy now, pay later" under Banking and loans. See section 0.

**App access**: "All or some functionality is restricted". Give the review account's email and
password, and note: "Sign in on the first screen. CNIC upload screens block screenshots by design."

**Ads**: No ads.

**Content rating** (IARC): Finance/utility. No violence or sexual content, no gambling, no
user-generated content shared with others. Users interact with the business only.

**Target audience**: 18 and over only. A Pakistani CNIC and mobile number are required, so the app
has no use to anyone under 18 or outside Pakistan.

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

¹ Sending data to AtomShop.pk counts as "sharing" unless AtomShop is the same legal entity or acts
as AtomPay's service provider. Confirm with legal. Email/WhatsApp providers are service providers,
so not sharing.

² Ask Atom voice uses the phone's own speech recogniser; only the resulting text is sent to AtomPay.
Confirm with legal how Google/Apple's recogniser processing should be disclosed.

**Government app / Health / News / COVID**: No.

**Store listing assets**: 512×512 icon, 1024×500 feature graphic, at least 2 phone screenshots,
short description (80 chars) and full description including the disclosures from section 2.

## 6. App Store Connect answers

**App Privacy** (must match `PrivacyInfo.xcprivacy`). All items are *linked to the user*, *not used
for tracking*, purpose *App Functionality*: Name, Email Address, Phone Number, Physical Address, Photos
or Videos, Credit Info, Other Financial Info, User ID, Customer Support (complaints), Other User Content
(Ask Atom questions), Other Data (CNIC number). Tracking: **No**.

**Age rating**: answer No to every content question, then set the age rating to **18+**.

**Category**: Finance.

**App Review information**: the review account credentials, a contact phone number, and notes:
"AtomPay is the instalment payment option for purchases on AtomShop.pk. Customers finance goods
bought from the shop; the app does not lend cash and takes no payments. Accounts are deleted in
Account → Delete account (the second review account has no open plans, so it can be deleted).
Identity-document screens block screenshots by design."

**Screenshots**: 6.9" iPhone (1320×2868). Only iPhone is needed, since the app is iPhone-only.

**Privacy policy URL**: `https://atompay.shop/privacy`. **Support URL**: required. Use a public
page with contact details.

**Encryption**: answered by `ITSAppUsesNonExemptEncryption` in Info.plist.

## 7. After approval

- [ ] Send the store URLs to the backend owner for `/app-config.store_url` (`ATOMPAY_APP_STORE_*`).
- [ ] Keep `min_version` at `1.0.0` until a forced update is needed.
