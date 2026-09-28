# AtomPay Mobile App — Complete Build Handbook

**For:** the team or tool building the AtomPay Android / iOS app
**Version:** 1.0 · **Date:** 2026-09-27 · **Backend status:** API v1 is live and complete (34 endpoints) · **App status:** not started

This one file has everything needed to build the app: the product (PRD), the architecture, the design
system, every screen, the rules, the task list, and the **full API reference**. It is self-contained,
so you do not need access to the Laravel server code.

---

## Contents

1. [Product requirements (PRD)](#1-product-requirements-prd)
2. [How the system works](#2-how-the-system-works)
3. [App architecture](#3-app-architecture)
4. [Design system](#4-design-system)
5. [Screens & flows](#5-screens--flows)
6. [Rules](#6-rules)
7. [Tasks & acceptance criteria](#7-tasks--acceptance-criteria)
8. [API reference](#8-api-reference)
9. [Appendix: Dart helpers, copy, glossary, open questions](#9-appendix)

---

# 1. Product requirements (PRD)

## 1.1 What AtomPay is

AtomPay is the **buy-now-pay-in-instalments** service behind **AtomShop.pk**, a Pakistani online store.

1. A customer is assessed **once**: identity (CNIC + selfie), a physical address visit, and income.
2. AtomPay staff give them a **purchase limit** (e.g. PKR 60,000), a **max monthly instalment**, and a **tenure** (months).
3. The customer shops on **atomshop.pk**, picks AtomPay at checkout, and repays monthly.

The website `atompay.shop` already does all of this. **The mobile app brings the customer side to Android and iOS.**

> **AtomPay does not sell products.** Shopping happens on AtomShop. AtomPay is the payment method, the limit
> and the repayment schedule. The app never lists products for sale and never takes payments (v1).

## 1.2 Who it's for

| User | In the app? |
|---|---|
| **Customer** (an AtomShop account with role `customer` and status active) | **Yes. This is the only audience.** |
| Staff (admin / manager / recovery…) | No. They use the website's review queue. The API refuses them (`403`). |
| Sellers, blocked accounts | No. They get `403` at sign-in. |

**Typical customer:** salaried or self-employed, mid-income, Android-first, often on slow mobile data, at home
with WhatsApp-style UIs and less at home with long forms. The UI is English in v1, with **Urdu (RTL) planned**.

## 1.3 Goals

1. **Fast onboarding.** A customer completes identity + income from the phone in **under 5 minutes**.
2. **"How much can I spend?" in one tap.** The limit card is the home screen.
3. **Fewer missed payments.** They can see what's due next, and get push reminders before each due date.
4. **One account.** The same login and password as AtomShop.pk. Signing up in the app creates an AtomShop account too.

### Success metrics

| Metric | Target |
|---|---|
| Registration → identity profile submitted | ≥ 60% within 7 days |
| Median time to complete the KYC form | < 5 min |
| Late instalments (app users vs web-only) | 20% fewer |
| Crash-free sessions | ≥ 99.5% |

## 1.4 The core process

The app shows this as a 6-step **stepper**. The server works out each step's state, so the app only draws it.

```
1. KYC  →  2. Address verification  →  3. Income assessment  →  4. Risk assessment  →  5. Purchase limit  →  6. AtomShop purchase
(customer)     (staff visit the home)      (customer)               (system + staff)       (staff decide)          (on atomshop.pk)
```

Each step is `done`, `current`, `upcoming` or `blocked`.

The app collects **two forms** from the customer:

| Form | API | What |
|---|---|---|
| **Identity profile** (KYC section 1) | `POST /profile` | Full name, CNIC, mobile, date of birth, address, city, CNIC front photo, CNIC back photo, selfie |
| **Income application** (KYC section 3) | `POST /application` | Employment, employer, income source, monthly income, existing instalments, monthly expenses |

Everything else (address visit, risk, the limit decision) is done by AtomPay staff. The app **shows the outcome**.

## 1.5 Scope by phase

The API for **all phases is already live**. The phases are the order the **app** gets built in.

### Phase 1: Foundation, Auth & Profile

- **Launch:** `GET /app-config` (force update, feature flags), then `GET /me` if a token is stored.
- **Sign in:** email **or** mobile, and password.
- **Sign up (2 screens):** name + **one "Email or mobile" field** + password, then a **6-digit code**. An email gets the code
  **by email** and a mobile gets it **on WhatsApp**. The account is created only once the code is right.
- **Forgot password (3 screens):** email or mobile, then a 6-digit code, then a new password. The customer ends up signed in.
- **Profile (identity):** read view with a status badge, and a form with camera/gallery upload of CNIC front, CNIC back and selfie.
- **Account:** name/email/phone (read-only), signed-in devices, sign out, sign out everywhere, and an email-alerts switch.

### Phase 2: Application & Dashboard

- **Dashboard (home):** status banner, limit card, 6-step stepper, next instalment due, and an unread badge.
- **Income application form**, with picker values from `/options`.
- **Application status + history.**
- **Income estimator:** "What could I get?" This is public and must be labelled *estimate*.

### Phase 3: Plans & Calculator

- **My plans:** each AtomShop order paid by instalments, with its product, progress and full schedule. Active and History tabs.
- **Plan calculator:** price, down payment (20–60%) and tenure give the monthly amount. The server does the math (`/quote`).
- **"Shop on AtomShop.pk"** hand-off to the browser.

### Phase 4: Engagement

- **Push notifications (FCM):** application received, limit decided, KYC verified/rejected, instalment due in 3 days,
  due today, and overdue (1 and 7 days).
- **Notifications inbox** (paginated) with read / read-all.
- **Urdu (RTL)**, **biometric unlock**, and **dark mode**.

### Out of scope

- **Paying instalments in the app.** Payment goes through AtomShop's existing channels, and the app only shows status.
- Browsing or buying products (that's AtomShop).
- Staff/admin features.
- Editing name, email, phone or password directly. AtomShop owns these. The password can only change through *Forgot password*.

## 1.6 Functional requirements

| # | Requirement |
|---|---|
| F1 | A user can sign up with **name + one contact (email *or* Pakistani mobile) + password (≥ 8, confirmed)**, then confirm a 6-digit code sent by email (email) or WhatsApp (mobile). Errors show under each field. |
| F2 | A user can sign in with email **or** mobile in any common format (`0300 1234567`, `+92 300 1234567`, `923001234567`, `3001234567`). |
| F3 | Non-customer accounts are refused with the server's message (*"Please sign in with an AtomShop customer account."*). |
| F4 | A session lasts **30 days**. After any `401` the app returns to sign-in without crashing or looping. |
| F5 | Sign out revokes the token on the server. "Sign out everywhere" revokes every token. The customer can see and revoke individual devices. |
| F6 | The profile form is pre-filled from `GET /profile`. CNIC and mobile are formatted as you type. |
| F7 | CNIC photos come from the camera or gallery. The selfie comes from the front camera. Images are compressed before upload (≤ 4 MB each). |
| F8 | The first profile submission needs all 3 images. Later edits can keep the existing images. |
| F9 | Uploaded documents can be viewed (with auth) but are **never cached to disk**. |
| F10 | A `429` shows a wait message and a countdown from the `Retry-After` header. |
| F11 | The mobile-number option for sign-up and reset is hidden when `/app-config.features.*_channels` doesn't include `whatsapp`. |
| F12 | Forgot password never reveals whether an account exists. |
| F13 | The app blocks use with an "Update required" screen when its version is below `min_version`. |
| F14 | Dashboard, plans and inbox support pull-to-refresh, and the dashboard refreshes when the app resumes. |
| F15 | A push tap opens the right screen (`data.screen`) and marks the notification read. |

## 1.7 Non-functional requirements

| Area | Requirement |
|---|---|
| Platforms | Android 8+ (API 26+) first, and iOS 14+. |
| Network | Usable on 3G. Every request has a timeout (connect 15 s, receive 30 s, **upload 120 s**) and a retry option. A failed submit never loses what the user typed. |
| Security | Token in secure storage only. No CNIC, selfie, DOB, address, income, email, phone or token in logs, analytics or crash reports. Screenshots blocked on KYC screens (Android `FLAG_SECURE`). HTTPS only in release. |
| Accessibility | Text scales to 200% without clipping. Touch targets ≥ 48 dp. WCAG AA contrast. Status is shown by text, not colour alone. |
| Size | Release APK < 25 MB (per-ABI split). |
| Performance | Cold start to the dashboard < 3 s on a mid-range Android over 4G. |

---

# 2. How the system works

```
 ┌──────────────────────┐     HTTPS + Bearer token      ┌────────────────────────────────┐
 │  AtomPay mobile app  │ ────────────────────────────▶ │  AtomPay server (Laravel 12)   │
 │  Android / iOS       │ ◀────────── JSON ──────────── │  https://atompay.shop/api/v1   │
 └──────────┬───────────┘                               └───────┬───────────────┬────────┘
            │ opens browser                                     │               │
            ▼                                                   ▼               ▼
 ┌──────────────────────┐      same database        ┌────────────────────┐ ┌───────────────────┐
 │  atomshop.pk (store) │ ────────────────────────▶ │  MySQL (shared)    │ │ Private KYC files │
 └──────────────────────┘                           └────────────────────┘ └───────────────────┘
                                   Firebase Cloud Messaging ◀── server sends push (every 10 min sweep)
                                   Email / WhatsApp        ◀── server sends codes and alerts
```

What the app builder needs to know:

- **One account, two sites.** AtomPay signs in against AtomShop's user accounts. The same email/mobile + password work on both.
  **Tokens are separate**, though: an AtomShop app token does not work here, and an AtomPay token does not work on AtomShop.
- **Staff decisions happen on the server**, sometimes in AtomShop's admin panel. The app finds out by refetching
  (`/dashboard`) and through push / inbox.
- **Notifications** come from a server job that runs every 10 minutes. Each event is announced **once**, through the inbox (always),
  push (if the device is registered) and email (unless the user turned email alerts off).
- **WhatsApp** is used for **one-time codes only** (sign-up and password reset to a mobile number). The app never talks to WhatsApp itself.
- **Money** is always a whole number of rupees (`int`) in the API.

---

# 3. App architecture

> **Framework:** Flutter (Dart 3), one codebase for Android + iOS. The server docs and push setup assume Flutter.
> The state-management choice below (Riverpod) is a recommendation. If your team is much stronger in Bloc, use it
> consistently, and decide before Phase 1 begins.

## 3.1 Stack

| Concern | Package | Why |
|---|---|---|
| Language | Dart 3 (null-safe, records, sealed classes) | |
| State + DI | `flutter_riverpod` + `riverpod_annotation` / `riverpod_generator` | Compile-safe DI, `AsyncValue` fits API screens, and it's easy to test |
| Navigation | `go_router` | Declarative routes, redirect guard for auth, deep links from push |
| HTTP | `dio` | Interceptors, multipart upload with progress, timeouts, cancel tokens |
| Models | `freezed` + `json_serializable` | Immutable models, `copyWith`, sealed unions |
| Secure storage | `flutter_secure_storage` | Keychain / Keystore for the bearer token |
| Images | `image_picker` + `flutter_image_compress` | Camera/gallery, and compressing to ≤ 4 MB |
| Formatting | `intl` | `PKR 45,000`, dates, ARB localisation |
| Fonts | Bundled TTF/WOFF (Bricolage Grotesque, Inter, JetBrains Mono) | Works offline on first launch |
| Screenshots | `flutter_windowmanager` (or a platform channel) | `FLAG_SECURE` on KYC screens |
| Push | `firebase_core`, `firebase_messaging`, `flutter_local_notifications` | Server sends FCM HTTP v1 |
| Biometrics (P4) | `local_auth` | Gate on the stored token |
| Device info | `device_info_plus`, `package_info_plus` | `device_name`, `app_version`, force-update check |
| Links | `url_launcher` | AtomShop, store links, support phone/WhatsApp/email |
| Crash reporting | `firebase_crashlytics` (or Sentry) | **PII scrubbed** (see Rules) |
| Lints | `very_good_analysis` | |
| Tests | `flutter_test`, `mocktail`, `http_mock_adapter` | |

## 3.2 Folder structure (feature-first, layered)

```
lib/
  main.dart                       # bootstrap: flavor, Firebase, ProviderScope, error zone
  app.dart                        # MaterialApp.router, theme, locale, l10n
  l10n/                           # app_en.arb (app_ur.arb later)
  core/
    config/env.dart               # base URL per flavor
    network/
      api_client.dart             # Dio instance: baseUrl, timeouts, headers
      auth_interceptor.dart       # adds Bearer; on 401/403 → clear token → signed out
      api_exception.dart          # sealed ApiException (see 3.4)
      error_mapper.dart           # DioException → ApiException (the ONLY place status codes are read)
    storage/token_storage.dart    # flutter_secure_storage wrapper
    router/app_router.dart        # go_router + auth redirect + push deep links
    theme/                        # tokens.dart, app_theme.dart, typography.dart
    utils/                        # pk_formatters.dart, money.dart, dates.dart
    widgets/                      # PrimaryButton, AppTextField, CnicField, MobileField, OtpField,
                                  # StatusPill, Banner, LimitCard, ProcessStepper, ErrorView, EmptyState
  features/
    launch/        # app-config, force update, splash
    auth/          # sign in, sign up + code, forgot password (3), sessions
    account/       # account screen, preferences
    profile/       # KYC section 1: read, form, document viewer, cities
    dashboard/     # home
    application/   # KYC section 3: form, status, history, estimator
    plans/         # list, detail
    calculator/    # plan calculator
    notifications/ # inbox, push handling, device registration
    # each feature: data/ (api + repository + models), domain/ (state), presentation/ (screens, controllers, widgets)
test/              # mirrors lib/
```

**Layer rules**

- `presentation` → `data` (repository) → `api` (Dio). **Widgets never import Dio. Repositories never import Flutter widgets.**
- A repository returns models or throws an `ApiException`. A controller (`AsyncNotifier`) turns that into UI state.
- Models mirror section 8 exactly. JSON is `snake_case`, and Dart uses `camelCase` via `@JsonSerializable(fieldRename: FieldRename.snake)`.

## 3.3 Environments (flavors)

| Flavor | Base URL | Notes |
|---|---|---|
| `dev` | `http://10.0.2.2/atompay/api/v1` (Android emulator) · `http://<PC-LAN-IP>/atompay/api/v1` (real phone) · `http://localhost/atompay/api/v1` (iOS simulator) | Cleartext HTTP allowed **in dev only** |
| `staging` | TBD | |
| `prod` | `https://atompay.shop/api/v1` | HTTPS only |

Select the flavor with `--dart-define=FLAVOR=prod` (or `--dart-define-from-file=env/prod.json`).

In `dev`, one-time codes are **not** really sent. The server writes them to its log (`storage/logs/laravel.log`), so ask the backend dev for the code.

## 3.4 Networking

Every request sends:

```
Accept: application/json
Authorization: Bearer <token>      # on every signed-in endpoint
```

`ApiException`, a sealed class that screens switch on (never on status codes or strings):

```dart
sealed class ApiException implements Exception { const ApiException(this.message); final String message; }
class Unauthorized extends ApiException { ... }                       // 401
class Forbidden    extends ApiException { ... }                       // 403 (token already revoked on the server)
class NotFound     extends ApiException { ... }                       // 404
class Conflict     extends ApiException { final String code; ... }    // 409 {message, code}
class Validation   extends ApiException { final Map<String, List<String>> errors; ... } // 422
class RateLimited  extends ApiException { final Duration retryAfter; ... }             // 429 + Retry-After
class ServerError  extends ApiException { ... }                       // 5xx
class NetworkError extends ApiException { ... }                       // timeout / no connection
```

- `422`: show `errors[field][0]` under each field. `message` is only a summary.
- Some `422` errors are keyed on a field **that isn't on screen** (`signup`, `reset_token`). Handle them at screen level (section 5).
- `401` / `403` on any signed-in call: the interceptor deletes the token, sets the auth state to `signedOut`, and the router goes to Sign in (for a `403`, show its `message`).

## 3.5 Auth state machine

```
launch ──▶ GET /app-config ──┬─ version < min_version ──▶ [Update required] (blocking)
                             └─ ok / offline ──▶ read token ─┬─ none ─────────────────▶ [Sign in]
                                                             └─ found ─▶ GET /me ─┬─ 200 ─▶ signedIn(user) ─▶ [Home]
                                                                                  ├─ 401/403 ─▶ clear ─▶ [Sign in]
                                                                                  └─ network ─▶ signedIn(cached user) + offline banner
sign in / sign-up verify / password reset ──▶ save token ──▶ signedIn(user) ──▶ POST /devices (if push) ──▶ [Home]
any 401/403 ──▶ clear token ──▶ signedOut ──▶ router redirects to [Sign in]
sign out ──▶ POST /auth/logout (best effort) ──▶ clear token ──▶ [Sign in]
```

`AuthState` is sealed: `unknown` (splash), `signedIn(User)`, `signedOut`.

## 3.6 Local data

| Data | Where | Notes |
|---|---|---|
| Bearer token + `expires_at` | `flutter_secure_storage` | Nowhere else, ever |
| Last `User` (for offline launch) | secure storage or encrypted prefs | Contains PII, so no plain SharedPreferences |
| `/cities`, `/options`, `/calculator` | memory (per session) | Refetch `/calculator` each time the calculator opens |
| FCM token | memory. Re-register on each sign-in | |
| UI prefs (theme, biometric on/off, language) | SharedPreferences | Not PII |
| KYC images | **never on disk** after upload. Delete temp compressed files after the POST | |

---

# 4. Design system

The app must feel like the website: a warm paper background, near-black **"nucleus"** surfaces for money,
a five-colour **spectrum** accent from the atom logo, a grotesque display face, and monospace eyebrow labels.

## 4.1 Colour tokens

| Token | Hex | Use |
|---|---|---|
| `nucleus` | `#050708` | Primary buttons, dark cards (limit card, calculator), logo disc |
| `paper` | `#FBFAF7` | App background (light) |
| `surface` | `#FFFFFF` | Cards on paper |
| `ink` | `#14151A` | Body text |
| `muted` | `#6C6C74` | Secondary text, eyebrows, hints |
| `line` | `#1A14151A` (ink @ 10%) | Borders, dividers |
| `line2` | `#0F14151A` (ink @ 6%) | Table row dividers |
| `amber` | `#FAA53A` | Due soon, highlights (never as text on white) |
| `coral` | `#F05465` | Late / error / destructive |
| `rose` | `#D45771` | Spectrum only |
| `violet` | `#62459B` | Focus ring, links, active tab, current step |
| `royal` | `#3D5DAB` | Info, spectrum |
| `ok` | `#1E9E6A` | Paid, verified, approved |

**Spectrum gradient** (left → right): `amber → coral → rose → violet → royal`. Use it for progress bar fills, the stepper's
connector up to the current step, the splash, and at most **one headline word per screen**. Never put it behind body text.

**Dark mode (Phase 4, but define the tokens now):** background `#0B0D0F`, surface `#15181C`, ink `#F2F1EC`, muted `#9A9AA3`,
line `#1AFFFFFF`. `nucleus` cards become `#000000` with a `line` border. The accents stay the same.

## 4.2 Status mapping (the same on every screen)

| API value(s) | Colour | Label |
|---|---|---|
| `paid`, `verified`, `approved`, `done`, banner `tone: done` | `ok` | Paid · Verified · Approved |
| `due`, `pending`, `conditional`, banner `tone: pending` | `amber` | Due · Under review · Conditional |
| `late`, `rejected`, `blocked`, banner `tone: blocked` | `coral` | Late · Rejected |
| `upcoming`, `not_started` | `muted` | Upcoming · Not started |
| stepper `current` | `violet` | — |

## 4.3 Typography

| Style | Font | Size / weight | Use |
|---|---|---|---|
| `display` | Bricolage Grotesque | 32 / 800, letter-spacing −0.5 | Limit amount, splash |
| `headline` | Bricolage Grotesque | 24 / 700, height 1.1 | Screen titles |
| `title` | Bricolage Grotesque | 18 / 700 | Card titles |
| `body` | Inter | 16 / 400, height 1.5 | Body text |
| `bodySmall` | Inter | 14 / 400 | Hints, secondary |
| `label` | Inter | 15 / 600 | Buttons (sentence case) |
| `eyebrow` | JetBrains Mono (or system mono) | 11 / 700, letter-spacing 1.8, UPPERCASE, `muted` | Section and field labels |
| `figure` | Inter + `FontFeature.tabularFigures()` | inherits | Every money amount and date in lists |

Bundle the fonts in the app. Don't fetch them at runtime.

## 4.4 Shape, spacing, motion

- Spacing scale: `4, 8, 12, 16, 20, 24, 32, 40`. Screen gutter is **20**.
- Radius: cards `20`, dark cards `24`, inputs `12`, buttons and pills fully rounded (`999`).
- **No elevation / shadows.** Separate things with `line` borders. Dark cards may have a soft violet radial glow.
- Minimum touch target is **48 × 48**.
- Motion is short (150–250 ms, ease-out). With reduce-motion on, drop the splash orbit animation and any count-up effects.

## 4.5 Logo

A `nucleus` circle with two thin ellipse orbits (amber at +28°, coral at −28°) and a white bold **"A"** in the centre.
Source SVG (44 × 44):

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 44 44"><circle cx="22" cy="22" r="20" fill="#050708"/><ellipse cx="22" cy="22" rx="17" ry="7" fill="none" stroke="#FAA53A" stroke-width="1.6" transform="rotate(28 22 22)"/><ellipse cx="22" cy="22" rx="17" ry="7" fill="none" stroke="#F05465" stroke-width="1.6" transform="rotate(-28 22 22)"/><text x="22" y="27" font-family="sans-serif" font-weight="800" font-size="17" fill="#fff" text-anchor="middle">A</text></svg>
```

Use it for the app icon (with an adaptive-icon background of `nucleus`), the splash and empty states.

## 4.6 Components

| Component | Spec |
|---|---|
| **PrimaryButton** | `nucleus` fill, white label, pill shape, height 52, full width in forms. When loading, show an inline spinner, keep the width, and disable it. |
| **GhostButton** | Transparent, `line` border, `ink` label. |
| **DestructiveButton** | `coral` label (and border). Always confirm first. |
| **AppTextField** | `paper` fill, `line` border, radius 12, **focus border `violet` 2 px**. Label above in `eyebrow` style. Error text in `coral` below. |
| **CnicField** | Numeric keypad, mask `#####-#######-#`, 13 digits, first digit 1–7. |
| **MobileField** | Phone keypad, mask `03## #######`, accepts pasted `+92…` and normalises it. |
| **LoginField** (email *or* mobile) | Text keyboard. When the input is all digits/`+`/spaces, format it as a mobile. The hint below follows what's typed (see 5.3). |
| **OtpField** | 6 boxes, numeric, `autofillHints: [AutofillHints.oneTimeCode]`, paste fills all 6, auto-submit on the 6th digit. |
| **StatusPill** | Coloured dot + label on a 10% tint of the status colour. |
| **Banner** | Full width. Tint by `tone`: pending = amber tint, blocked = coral tint, done = ok tint, info = royal tint. Title, text and an optional CTA button. |
| **LimitCard** | `nucleus` card. Eyebrow "AVAILABLE TO SPEND", `display` amount (`available`), spectrum progress bar (`used_percent`), then rows for Limit · Used · Max instalment · Tenure (white @ 80% text, white @ 10% dividers). When `has_limit` is false, show "Not set yet". |
| **ProcessStepper** | Vertical list of 6 stages. Dot colour: `ok` done, filled `violet` current, `line` upcoming, `coral` blocked. The connector uses the spectrum up to the current stage. Shows title + hint. |
| **InstalmentRow** | Label, due date, amount (tabular), StatusPill by `state`. |
| **PlanCard** | Product image (4:3, rounded 12), title, order reference, spectrum progress bar, "PKR x of y paid", next due line, `late` pill if late. |
| **DocumentTile** | 4:3 thumbnail or dashed placeholder, label, a "Take photo / Retake" action, an uploaded tick. |
| **EmptyState / ErrorView** | Logo mark, one sentence, one action ("Try again"). |
| **Skeleton** | A `line2`-coloured shimmer for loading lists and cards. |

## 4.7 Content & tone

- Plain, reassuring and short. Say **"Your limit"**, not "Credit facility".
- Money: **`PKR 45,000`**. Never `Rs.`, `45000` or `45,000.00`.
- Dates: `24 Oct 2026` in lists, `Thursday, 24 October` for the next-due card.
- Errors say what to do next.
- **Never** say "No account found" in forgot password.
- Show server `message`s as they are (they are written for customers), e.g. banner text and staff notes.

## 4.8 Accessibility

- AA contrast minimum. Don't use `amber` text on white. Use amber only for dots, fills and tints.
- Every status has a text label as well as a colour.
- Text scale up to 2.0. Semantics labels on icon-only buttons. The OTP field is read as one field.
- Respect reduce-motion.

---

# 5. Screens & flows

## 5.1 Navigation map

```
(outside the shell)
  Splash → Update required
  Sign in ─┬─ Sign up → Enter code
           └─ Forgot password → Enter code → New password

(shell: bottom navigation)
  ┌──────── Home ────────┬──────── Plans ────────┬────── Profile ──────┐
  │ Dashboard            │ Plans (Active|History)│ Profile (identity)  │
  │  ├ Application form  │  └ Plan detail        │  ├ Profile form     │
  │  ├ Application status│ Calculator            │  ├ Document viewer  │
  │  │  └ History        │                       │  └ Account          │
  │  └ Notifications     │                       │     ├ Devices       │
  │                      │                       │     └ Notification settings
  └──────────────────────┴───────────────────────┴─────────────────────┘
Public (reachable signed out too): Calculator, Income estimator
```

The bottom bar is **Home · Plans · Profile**. Until Phase 3 ships, Plans is hidden. A bell icon with the unread badge sits in the Home app bar.

**go_router paths (suggested):** `/splash`, `/update`, `/login`, `/register`, `/register/verify`, `/forgot`, `/forgot/verify`,
`/forgot/reset`, `/home`, `/home/notifications`, `/application`, `/application/status`, `/application/history`,
`/estimate`, `/plans`, `/plans/:orderId`, `/calculator`, `/profile`, `/profile/edit`, `/profile/document/:doc`,
`/account`, `/account/devices`, `/account/notifications`.

## 5.2 Splash & Update required

- **Splash:** a `nucleus` background with the logo (orbit animation unless reduce-motion is on). Calls `GET /app-config`, then `GET /me` (section 3.5).
- **Update required** (blocking): "A new version of AtomPay is available. Please update to continue." The button opens `store_url[platform]`. If that's `null`, hide the button and show the support contacts.
- Save `/app-config` in memory. Later screens read `features`, `support` and `shop_url` from it.

## 5.3 Sign in

- Logo, a headline, "Sign in with your AtomShop account".
- `login` field (email or mobile), a password field with show/hide, and **Sign in**.
- Links to "Create account" and "Forgot password?".
- API: `POST /auth/login` with `device_name` (e.g. `"Pixel 7 · Android 14"` from `device_info_plus`).
- `422` → show under `login`. `403` → dialog with the server `message`. `429` → countdown.

## 5.4 Sign up (2 screens)

**Screen 1: Your details**

- Fields: Full name · **Email or mobile number** · Password · Confirm password.
- The hint under the contact field follows what's typed:
  - contains `@` → "We'll email you a code."
  - looks like a mobile → "We'll send the code on WhatsApp."
- If `app-config.features.signup_channels` has **no** `whatsapp`, label the field **"Email"**, use the email keyboard, and drop the WhatsApp hint.
- Small print: "This also creates your AtomShop.pk account."
- API: `POST /auth/register` → `202` with `signup_id`, `channel`, `destination` (masked), `expires_in`, `resend_in`.
- Keep the form values if the user comes back from screen 2.

**Screen 2: Enter your code**

- "We sent a 6-digit code to **{destination}** by {email | WhatsApp}."
- OtpField. A **"Send a new code"** link, disabled while `resend_in` counts down.
- **Create account** → `POST /auth/register/verify` (`signup_id`, `code`, `device_name`) → `201` with the token + user → Home.
- Resend → `POST /auth/register/resend` → the new `resend_in`.
- Errors:
  - `errors.code` → show under the OtpField, and clear the boxes.
  - `errors.signup` (expired / too many wrong codes / contact taken meanwhile) → show a dialog, then **go back to screen 1**.
- Keep `signup_id` in memory only. If the app is killed, the user starts again.

## 5.5 Forgot password (3 screens)

1. **Email or mobile.** Note: "Mobile numbers get the code on WhatsApp" (hide this when `password_reset_channels` has no `whatsapp`).
   `POST /auth/password/forgot` → `202`. **It always succeeds for well-formed input, even for an unknown account.**
   Copy: "If this belongs to an AtomShop account, we've sent a code to {destination}."
2. **Enter code.** OtpField, masked destination, and a resend countdown from `resend_in`. **Resend = call `/auth/password/forgot`
   again with the same login** (within 60 s the server returns the same request and sends no new code).
   `POST /auth/password/verify` → `reset_token` (valid 15 min).
   `errors.code` saying "Too many wrong codes" or "expired" → back to step 1.
3. **New password** + confirm. `POST /auth/password/reset` → token + user (signed in) → Home, with a toast:
   **"Password changed. It works on AtomShop.pk too."** Every other device is now signed out.
   `errors.reset_token` → dialog → back to step 1.

## 5.6 Home / Dashboard (`GET /dashboard`)

Top to bottom:

1. App bar: "Hi, {short_name}" (from `/me`) and a bell with `unread_notifications`.
2. **Banner** (`banner.tone`, `title`, `text`, `cta`). The CTA routes by `banner.action`:

   | `action` | Opens |
   |---|---|
   | `apply` | Profile form (then the Application form once the profile is saved) |
   | `profile` | Profile form |
   | `application` | Application form (pre-filled from `latest`) |

3. **LimitCard** (`limit`).
4. **Next due** card (`next_due`), shown only when it isn't null: "Thursday, 24 October · PKR 12,500 · {product_title}", a pill by `state`. Tap it to open the plan.
5. **Plans summary**: "{active_count} active plans", with a `late` warning if `has_late`. Tap it to open Plans.
6. **ProcessStepper** (`stages`).
7. **Shop on AtomShop.pk** button (`app-config.shop_url`).

Refresh on pull, on app resume, after any form submit, and when a push arrives in the foreground.

## 5.7 Profile (identity, KYC section 1)

**Read view** (`GET /profile`): a StatusPill (`status`), rows for name, CNIC (`cnic_formatted`), mobile, DOB, address and city,
3 DocumentTiles (a thumbnail when `uploaded`), and an "Edit" button (or "Complete your profile" when `not_started`).
When `status = rejected`, show a coral banner (the dashboard banner has the reviewer's note).

**Form** (one scrolling form, sections **Identity · Address · Documents**, with a sticky **Submit for review** button):

- Pre-fill from `GET /profile` (even when `not_started`, it's pre-filled from AtomShop).
- City: a searchable picker from `GET /cities` (optional).
- DOB: a date picker, max date = today − 18 years.
- Documents: CNIC front / back (camera or gallery), selfie (**front camera**). Compress each one (longest side about 1600 px, JPEG quality about 85, ≤ 4 MB).
- First submission: all 3 images are required. Later: send only the images that changed.
- `POST /profile` as **multipart** with an upload progress bar. `201` (first) / `200` (update) → the read view.
- If the current status is `verified`, confirm first: **"Changing these details sends your profile back for verification."**
- `FLAG_SECURE` on this screen.

**Document viewer:** full screen, pinch to zoom, loaded with the auth header, **no disk cache**, `FLAG_SECURE`.

## 5.8 Application (income, KYC section 3)

- `GET /application` + `GET /options`.
- If `can_apply` is false (`requires: "profile"`) → "First, verify your identity", with a button to the profile form.
- Form: Employment status (picker) · Employer / business name (**shown and required only when `has_employer`**) · Income source
  (picker) · Monthly income · Existing monthly instalments (optional) · Monthly expenses (optional). Money fields take digits only and are formatted as you type (`PKR 200,000`).
- Pre-fill from `latest` when present.
- Submit → `POST /application` → `201` → the status screen. `409 profile_required` → the profile form.
- **Status screen:** the latest assessment's status pill, what was declared, and, once decided, the limit / max instalment / tenure / `notes`.
  If `active` differs from `latest`, show "Your current limit stays in force while we review your new application."
- **History:** `GET /application/history`, newest first.
- **Income estimator** (public): one income field → `POST /estimate` → "Estimated limit PKR 45,000 · Estimated max instalment PKR 15,000". The label **"Estimate. Your real limit is decided after review."** is required.

## 5.9 Plans

- **List** (`GET /plans`, and `?include=completed` for the History tab). PlanCards. Empty state: "No instalment plans yet. Choose AtomPay at AtomShop checkout." with a Shop button.
- **Detail** (`GET /plans/{order_id}`): the product header (image, title, "View on AtomShop" → `product.shop_url`), order totals
  (total price, down payment, financed, tenure), progress, and the full schedule of InstalmentRows.
  Footer note: "Pay through AtomShop's usual payment channels." (plus support contacts).
- `product` may be `null`. In that case show the order reference and a placeholder image.

## 5.10 Calculator (public)

- `GET /calculator` each time it opens.
- Price: a slider (`price.min`…`price.max`, step `price.step`) plus a text field.
- Down payment: a slider from `advance.min_ratio` to `max_ratio` × price (20–60%).
- Tenure: chips from `tenures`.
- A **debounced (300 ms)** `POST /quote` → a `nucleus` result card: **monthly**, financed, markup, total. Show any `422` field errors next to the right control.
- Label: "Estimate. The exact figures are confirmed at AtomShop checkout."

## 5.11 Notifications inbox

- `GET /notifications?page=n` with infinite scroll (20 per page, follow `links.next`).
- Unread items are bold with a violet dot. Tap → `POST /notifications/{id}/read`, then route by `payload.screen` (section 8.11).
- "Mark all as read" → `POST /notifications/read-all`.

## 5.12 Account

- Name, email (hide it when `null`), phone, member since. Read-only, with the note "Change these on AtomShop.pk."
- **Signed-in devices** (`GET /auth/sessions`): device name, "This device" for `current`, last used. Swipe or tap to sign out (`DELETE /auth/sessions/{id}`).
- **Notification settings:** an email-alerts switch (`GET/PATCH /me/preferences`). Hide it when `email` is `null` (mobile-only accounts get no email). There's also a push on/off switch (device-level: `DELETE /devices` / `POST /devices`).
- **Change password** → the forgot-password flow, pre-filled with their email/phone.
- **Support:** phone / WhatsApp / email from `app-config.support` (hide any that are `null`).
- **Sign out** and **Sign out of all devices** (destructive, with a confirmation).

## 5.13 Loading / empty / error states

Every data screen implements all four: **loading** (skeleton) · **empty** (EmptyState) · **error** (ErrorView + "Try again") · **data**.
When offline, show a thin banner "You're offline. Showing your last update." and disable submit buttons.

---

# 6. Rules

These rules are not optional. If one blocks you, raise it with the backend owner. Don't quietly work around it.

## 6.1 Contract

1. **Section 8 is the source of truth** for every endpoint, field and error. Models follow the doc, not guesses from a response.
2. **Ignore unknown JSON fields** (the server may add fields within v1). Never fail parsing on an extra key.
3. **Nullable fields are always present as `null`.** Model them as nullable.
4. If the API seems to be missing something, ask the backend. Don't compute it client-side.

## 6.2 Business logic

5. **The server does the math.** Limits, instalment caps, disposable income, plan pricing and risk come from the API. The app never computes a number and then submits it. A visual preview is fine only if it's labelled "estimate".
6. **Money is `int` rupees.** Never `double`. Format only at the UI edge (`PKR 123,456`).
7. CNIC and mobile are validated and formatted client-side for UX, but the **server's normalised value** is what you store and compare.
8. Staff decisions can change at any time on the server. Always refetch rather than trusting cached status.

## 6.3 Security & privacy

9. The bearer token lives **only** in `flutter_secure_storage`. Never put it in SharedPreferences, logs, analytics, crash reports, deep links or URLs.
10. **No PII** in logs, analytics or crash reports: no CNIC, selfie, DOB, address, income, email, phone or token. Use the user `id` if you must correlate. Turn off Dio body logging in release.
11. KYC screens and the document viewer set `FLAG_SECURE` (no screenshots, no recents preview). On iOS, blur the app-switcher snapshot.
12. Document images load with the auth header and are **not** written to disk (no `cached_network_image` for them).
13. Delete temporary compressed images right after upload.
14. Release builds: HTTPS only (Android `network_security_config` allows cleartext in the dev flavor only), obfuscated (`--obfuscate --split-debug-info`).
15. Forgot password must not reveal whether an account exists.
16. Never show, store or ask for a user's AtomShop `uuid`. The API deliberately doesn't return it.

## 6.4 Code

17. Feature-first structure (section 3.2). Widgets never import Dio. Repositories never import Flutter widgets.
18. Riverpod for all state and DI. No global mutable singletons, and no `setState` for anything that touches the network.
19. Models use `freezed` + `json_serializable`. Commit the generated files or generate them in CI, and pick one approach.
20. Errors are mapped **once** (`error_mapper.dart`) into the sealed `ApiException`. Screens switch on the type.
21. Every data screen handles loading, empty, error (with retry) and data.
22. `flutter analyze` is clean with `very_good_analysis`.
23. **No hard-coded user-facing strings.** Use ARB files from day one (Urdu is coming).
24. **No hard-coded colours or sizes** in widgets. Use `AppTokens` / `Theme.of(context)`.
25. Every mutating button is disabled while its request is in flight (no double submits).

## 6.5 Testing

26. Unit tests: CNIC / mobile / money formatters and validators (mirror section 9.1), `error_mapper`, and repositories (`http_mock_adapter`).
27. Widget tests: sign in, sign up + code, forgot password, profile form, application form, including `422` field errors.
28. Test the **401 → signed out → sign-in screen** path explicitly.
29. A golden or screenshot test for LimitCard and ProcessStepper in all states.

## 6.6 Git & release

30. Branch from `main`. Keep commits small with an imperative subject ("Add profile document viewer").
31. Never commit keystores, `google-services.json` / `GoogleService-Info.plist` with production keys, `.env` files or tokens.
32. Bump `version` in `pubspec.yaml` for every store build. `/app-config.min_version` compares against it (semver).

---

# 7. Tasks & acceptance criteria

Tick them as they land. Keep them in phase order.

## Phase 0: Setup

- [ ] Confirm the open questions in section 9.5 (package name, store accounts, payments).
- [ ] Create the Flutter project `atompay_mobile` with flavors `dev` / `staging` / `prod`.
- [ ] Add `very_good_analysis`, the folder skeleton (section 3.2) and CI (analyze + test on every PR).
- [ ] Create the Firebase project (Android + iOS apps), and send the **service-account JSON to the backend owner** (the server needs it to send push).

## Phase 1: Foundation, Auth & Profile

- [ ] Theme: `AppTokens`, `AppTheme` (light), bundled fonts, typography (section 4).
- [ ] Core: `ApiClient`, `AuthInterceptor`, `ApiException` + `ErrorMapper`, `TokenStorage`.
- [ ] Core widgets: PrimaryButton, GhostButton, AppTextField, CnicField, MobileField, LoginField, OtpField, StatusPill, Banner, ErrorView, EmptyState, Skeleton.
- [ ] `pk_formatters.dart` + unit tests (section 9.1).
- [ ] Launch: `/app-config` → force-update gate → `/me` (section 3.5).
  *Accept:* with a version below `min_version` the app is blocked. With no network it opens with the cached user and an offline banner.
- [ ] Sign in. *Accept:* email and every mobile format work. A staff account shows the 403 message and gets no token.
- [ ] Sign up (2 screens). *Accept:* an email gets a code by email and a mobile gets one on WhatsApp. A wrong code shows "N tries left". Resend is disabled for 60 s. An expired sign-up goes back to screen 1. Success lands on Home, signed in.
- [ ] Forgot password (3 screens). *Accept:* an unknown account gets the same neutral message. Success signs in and shows the toast.
- [ ] Handle 401/403/409/422/429 end to end. *Accept:* a revoked token from another device's "sign out everywhere" returns the app to Sign in without a crash.
- [ ] Profile read + form (prefill, city picker, camera/gallery, compression, upload progress, verified-edit warning).
  *Accept:* a 12 MB camera photo uploads as ≤ 4 MB. The first submit without images shows 3 field errors. The re-submit keeps the old images.
- [ ] Document viewer (auth header, no disk cache, `FLAG_SECURE`).
- [ ] Account: details, devices list + revoke, sign out, sign out everywhere, email-alerts switch.
- [ ] Widget tests for login, sign-up, forgot password and the profile form.

## Phase 2: Application & Dashboard

- [ ] Dashboard: Banner (routes on `banner.action`), LimitCard, Next-due card, plans summary, ProcessStepper, pull-to-refresh, refresh on resume.
  *Accept:* all 7 banner states render (section 8.8). `has_limit: false` shows "Not set yet".
- [ ] Application form driven by `/options` (employer only when `has_employer`). `409 profile_required` goes to the profile.
- [ ] Application status + history.
- [ ] Income estimator (public, labelled estimate).

## Phase 3: Plans & Calculator

- [ ] Plans list (Active / History tabs), plan detail with the schedule. *Accept:* `product: null` renders a placeholder. A `404` shows "Plan not found".
- [ ] Calculator (bounds from `/calculator`, debounced `/quote`, field errors).
- [ ] "Shop on AtomShop" hand-off (`shop_url`, `product.shop_url`).

## Phase 4: Engagement

- [ ] FCM: permission prompt (only if `features.push`), Android channel `atompay_default`, `POST /devices` after every sign-in and on `onTokenRefresh`.
- [ ] Push handling in the foreground (local notification + dashboard refresh), background and terminated states. The tap routes by `data.screen` and marks it read.
- [ ] Notifications inbox (paginated) + unread badge.
- [ ] Urdu (RTL), biometric unlock, dark mode.

## Release

- [ ] Android: `network_security_config` (dev cleartext only), release signing, obfuscation, per-ABI split, adaptive icon.
- [ ] iOS: camera + photo library usage strings, push entitlement + APNs key uploaded to Firebase, ATS on.
- [ ] Store listings, privacy policy URL, data-safety form (collects: name, phone/email, CNIC, photos, financial info).
- [ ] Internal testing (Play internal track / TestFlight).
- [ ] Send the backend owner the store URLs and the minimum version, so they can set `ATOMPAY_APP_STORE_*` / `ATOMPAY_APP_MIN_*`.

## Backend items the app depends on (owned by the server team, for your awareness)

- [ ] Production has real SMTP + WhatsApp credentials (otherwise codes aren't delivered).
- [ ] Production has `FCM_CREDENTIALS` (otherwise `features.push` is `false` and no push is sent).
- [ ] Cron runs `schedule:run` every minute (otherwise no notifications are created).
- [ ] Review the sign-up rate limit (5/hour per IP) before launch. Pakistani carriers put many users behind one IP.

---

# 8. API reference

## 8.1 Basics

| | |
|---|---|
| Production base URL | `https://atompay.shop/api/v1` |
| Local (XAMPP) | `http://localhost/atompay/api/v1` |
| Android emulator | `http://10.0.2.2/atompay/api/v1` |
| Real phone on the same Wi-Fi | `http://<PC-LAN-IP>/atompay/api/v1` |
| Auth | `Authorization: Bearer <token>` (Laravel Sanctum) |
| Content type | JSON, **except `POST /profile`, which is `multipart/form-data`** |

Always send `Accept: application/json`.

### Conventions

- **Envelope:** a success body is `{ "data": … }`, and a list is `{ "data": [ … ] }`.
- **Money:** a whole number of rupees (`int`). Never a float or a string.
- **Dates:** `YYYY-MM-DD`. **Timestamps:** ISO-8601 with an offset, in UTC (`2026-10-24T06:47:14+00:00`). Show them in local time.
- **CNIC:** 13 bare digits (`4210176543219`), plus `cnic_formatted` (`42101-7654321-9`). You can send it with or without dashes.
- **Mobile:** `03XXXXXXXXX`, plus `mobile_formatted` / `phone_formatted` (`0300 1234567`). You can send any common form.
- **Nullable fields are always present** (as `null`).
- **Tokens** look like `20|atompay_Xu97…`. Treat the whole string as opaque.

## 8.2 Errors

Every error is JSON.

| Status | When | Body | App action |
|---|---|---|---|
| `401` | No, bad, expired or revoked token | `{"message":"Unauthenticated."}` | Delete the token and go to Sign in |
| `403` | Not an active customer (staff, seller, blocked). **On a signed-in route the token is already revoked** | `{"message":"Please sign in with an AtomShop customer account."}` | Show the message, delete the token, go to Sign in |
| `404` | Unknown route, or a record that isn't yours | `{"message":"…"}` | "Not found" view |
| `409` | Allowed input, wrong state | `{"message":"…","code":"profile_required"}` | Switch on `code` |
| `422` | Validation | `{"message":"…","errors":{"field":["msg",…]}}` | `errors[field][0]` under the field |
| `429` | Rate limited | `{"message":"Too Many Attempts."}` + header `Retry-After: <seconds>` | Disable the button and show a countdown |
| `5xx` | Server fault | `{"message":"Server Error"}` | Generic retry UI. Never show the raw text |

**`409` codes:**

| `code` | Returned by | Action |
|---|---|---|
| `profile_required` | `POST /application` | Send the customer to the profile form first |

## 8.3 Rate limits

| Endpoint | Limit | Keyed by |
|---|---|---|
| `POST /auth/login` | 5/min, and 20/min | identifier + IP, and IP |
| `POST /auth/register` | 5/hour (+ 3 codes/hour per email or number) | IP |
| `POST /auth/register/verify` | 10/min (+ 5 tries per sign-up) | IP |
| `POST /auth/register/resend` | 3/min, and 10/min (+ 60 s cooldown) | IP |
| `POST /auth/password/forgot` | 3/min, and 10/min (+ 5 codes/hour per account) | identifier + IP, and IP |
| `POST /auth/password/verify`, `/reset` | 10/min | IP |
| `POST /profile`, `POST /application` | 10/min | account |
| `GET /profile/documents/*` | 60/min | account |
| `POST /quote` | 60/min | IP |
| `POST /estimate` | 10/min and 40/hour | IP |
| `/app-config`, `/options`, `/calculator` | 600/min | IP |
| Every other signed-in endpoint | 120/min | account |

## 8.4 Token lifecycle

1. `POST /auth/login`, `POST /auth/register/verify` and `POST /auth/password/reset` return a token valid for **30 days** (`expires_at`).
2. Store it in secure storage.
3. On launch, `GET /me`: `200` means you're signed in, `401` means go to sign-in.
4. **There is no refresh token.** When the token expires, the user signs in again. (Optional: when `expires_at` is < 3 days away, prompt the user to sign in again at a convenient moment.)
5. `POST /auth/logout` revokes this device. `POST /auth/logout-all` revokes every device. A password reset also revokes every device.

## 8.5 Endpoint index (34)

| # | Method | Path | Auth | Section |
|---|---|---|---|---|
| 1 | GET | `/app-config` | – | 8.12 |
| 2 | GET | `/options` | – | 8.12 |
| 3 | GET | `/calculator` | – | 8.10 |
| 4 | POST | `/quote` | – | 8.10 |
| 5 | POST | `/estimate` | – | 8.10 |
| 6 | POST | `/auth/register` | – | 8.6 |
| 7 | POST | `/auth/register/verify` | – | 8.6 |
| 8 | POST | `/auth/register/resend` | – | 8.6 |
| 9 | POST | `/auth/login` | – | 8.6 |
| 10 | POST | `/auth/password/forgot` | – | 8.6 |
| 11 | POST | `/auth/password/verify` | – | 8.6 |
| 12 | POST | `/auth/password/reset` | – | 8.6 |
| 13 | POST | `/auth/logout` | ✓ | 8.6 |
| 14 | POST | `/auth/logout-all` | ✓ | 8.6 |
| 15 | GET | `/auth/sessions` | ✓ | 8.6 |
| 16 | DELETE | `/auth/sessions/{id}` | ✓ | 8.6 |
| 17 | GET | `/me` | ✓ | 8.7 |
| 18 | GET | `/me/preferences` | ✓ | 8.7 |
| 19 | PATCH | `/me/preferences` | ✓ | 8.7 |
| 20 | GET | `/dashboard` | ✓ | 8.8 |
| 21 | GET | `/profile` | ✓ | 8.9 |
| 22 | POST | `/profile` | ✓ | 8.9 |
| 23 | GET | `/profile/documents/{document}` | ✓ | 8.9 |
| 24 | GET | `/cities` | ✓ | 8.9 |
| 25 | GET | `/application` | ✓ | 8.9b |
| 26 | POST | `/application` | ✓ | 8.9b |
| 27 | GET | `/application/history` | ✓ | 8.9b |
| 28 | GET | `/plans` | ✓ | 8.10b |
| 29 | GET | `/plans/{order_id}` | ✓ | 8.10b |
| 30 | POST | `/devices` | ✓ | 8.11 |
| 31 | DELETE | `/devices` | ✓ | 8.11 |
| 32 | GET | `/notifications` | ✓ | 8.11 |
| 33 | POST | `/notifications/{id}/read` | ✓ | 8.11 |
| 34 | POST | `/notifications/read-all` | ✓ | 8.11 |

---

## 8.6 Auth & sessions

### Sign-up (one-time code)

The customer signs up with **one** contact in a single `login` field:

| Typed | Code sent by | The account gets |
|---|---|---|
| Email address | **Email** | that email (marked verified), no phone |
| Pakistani mobile (any format) | **WhatsApp** | that mobile. `email` is `null` in the API |

- The code is **6 digits**, valid for **10 minutes**. The whole sign-up must finish within **30 minutes**.
- **5** verify attempts, then *"Too many wrong codes. Please start again."*
- Resend cooldown **60 s**. At most **3 codes an hour** per email / number.
- **Mobile-only accounts** have `email: null` and get **no emails at all**. They get everything through the inbox and push. They sign in and reset their password with the mobile number.

#### `POST /auth/register` → `202 Accepted`

```json
{ "name": "Ayesha Khan", "login": "0300 1234567", "password": "at-least-8-chars", "password_confirmation": "at-least-8-chars" }
```

| Field | Rules |
|---|---|
| `name` | required, ≤ 255 |
| `login` | required. **Either** a valid email **or** a Pakistani mobile (landlines refused), not already on an account |
| `password` | required, ≥ 8, must match `password_confirmation` |

```json
{
  "data": {
    "signup_id": "4c949005-3a2c-4ddc-8d3c-15c9b7c6399f",
    "channel": "whatsapp",
    "destination": "0300*****67",
    "expires_in": 1799,
    "resend_in": 60
  }
}
```

`channel` is `email` or `whatsapp`. `destination` is masked (`ay****@gmail.com` / `0300*****67`). `expires_in` is the seconds left in the whole sign-up.

**`422` on `login`:**

| Message | When |
|---|---|
| "Enter a valid email address." | malformed email |
| "An account with this email already exists. Sign in or reset your password." | email taken |
| "An account with this mobile number already exists. Sign in or reset your password." | number taken |
| "That looks like a landline. Enter a mobile number so we can text you about payments." | landline |
| "Enter your email address or mobile number, e.g. 0300 1234567." | neither |
| "We couldn't send a code to this email just now. Please check it and try again." | email delivery failed |
| "We couldn't send a WhatsApp code to this number. Make sure it has WhatsApp, or sign up with your email." | WhatsApp delivery failed |
| "We can't send codes to mobile numbers right now. Sign up with your email address instead." | WhatsApp not configured |
| "Too many codes have been sent to this number / email. Please try again in an hour." | hourly cap |

#### `POST /auth/register/verify` → `201 Created`

```json
{ "signup_id": "4c949005-…", "code": "482913", "device_name": "Pixel 7 · Android 14" }
```

The response is **the same as `POST /auth/login`** (token, expires_at, user). Email sign-ups also get a welcome email.

**`422`:**

- `errors.code`: "That code isn't right. 4 tries left." · "This code has expired. Send a new one."
- `errors.signup`: "This sign-up has expired. Please start again." · "Too many wrong codes. Please start again." ·
  "An account with this email / mobile number was created while you were signing up. Please sign in instead."
  → **All `signup` errors mean going back to the details screen.**

#### `POST /auth/register/resend` → `200 OK`

```json
{ "signup_id": "4c949005-…" }
```

Same body as `/auth/register` (`resend_in` back to 60). Errors are on `errors.code`, e.g. *"Please wait N seconds before asking for another code."*,
or the hourly cap / delivery failure message. `errors.signup` when the sign-up has expired.

### `POST /auth/login` → `200 OK`

```json
{ "login": "ayesha@example.com", "password": "…", "device_name": "Pixel 7 · Android 14" }
```

`login` is an email **or** a phone number in any format. `device_name` is optional (≤ 100) and shows in the sessions list.

```json
{
  "data": {
    "token": "20|atompay_Xu97xvn4yedZao8gERnNirmcXXAZtjHCook97B6P8cfcbf8b",
    "token_type": "Bearer",
    "expires_at": "2026-10-24T06:47:14+00:00",
    "user": { "…": "User object, see 8.7" }
  }
}
```

- `422` `errors.login`: "Those details do not match an AtomShop account."
- `403`: the account isn't an active customer. No token is issued.

### `POST /auth/logout` → `204`

Revokes this device's token **and unregisters its push device**.

### `POST /auth/logout-all` → `204`

Revokes every token and every registered device.

### `GET /auth/sessions`

```json
{
  "data": [
    { "id": 140, "device_name": "Pixel 7 · Android 14", "current": true,
      "signed_in_at": "2026-09-24T07:06:04+00:00", "last_used_at": "2026-09-24T07:06:07+00:00",
      "expires_at": "2026-10-24T07:06:04+00:00" }
  ]
}
```

Newest first, live tokens only. The token itself is never returned. `last_used_at` may be `null`.

### `DELETE /auth/sessions/{id}` → `204`

Signs that device out and stops its pushes. `404` if the id isn't yours. Deleting the `current` one is the same as logout, so clear the local token too.

### Forgot password (OTP)

| Typed | Code sent by |
|---|---|
| Email | Email |
| Pakistani mobile | WhatsApp (message with a copy-code button) |

- The code is **6 digits**, valid for **10 min**, with **5 attempts**. Only the newest code works.
- Asking again within **60 s** returns the **same** request and sends no new code. Use `resend_in` for the timer.
- At most 5 codes/hour per account.
- **Unknown accounts get exactly the same `202` response.** Never say "no account found".
- Only active customer accounts can reset here.

#### `POST /auth/password/forgot` → `202 Accepted`

```json
{ "login": "0300 1234567" }
```

```json
{
  "data": {
    "request_id": "34fc3e23-3052-4366-88c4-ffcb8c2a1919",
    "channel": "whatsapp",
    "destination": "0300*****67",
    "expires_in": 599,
    "resend_in": 60
  }
}
```

| `422` on `login` | Meaning |
|---|---|
| "Enter your email address or mobile number, e.g. 0300 1234567." | Neither an email nor a mobile |
| "Codes by WhatsApp aren't available right now. Enter your email address instead." | WhatsApp not configured |
| "We couldn't send your code just now. Please try again in a minute." | Provider failure |

#### `POST /auth/password/verify` → `200 OK`

```json
{ "request_id": "34fc3e23-…", "code": "863230" }
```

```json
{ "data": { "reset_token": "N0gfGI…(64 chars)", "expires_in": 900 } }
```

`422` `errors.code`: "That code isn't right. 4 tries left." · "Too many wrong codes. Request a new one." · "This code has expired. Request a new one."
(The last two mean going back to step 1.)

#### `POST /auth/password/reset` → `200 OK`

```json
{ "reset_token": "N0gfGI…", "password": "new-pass-456", "password_confirmation": "new-pass-456", "device_name": "Pixel 7" }
```

On success: the password changes (on AtomShop.pk too), **every** AtomPay sign-in and push device is revoked, a "password changed" email is sent (to real emails only), and **this device is signed in**. The response is the same as login.

`422`: `password` (≥ 8, confirmed). `reset_token`: "This reset has expired. Please start again." (after 15 min, or already used).

---

## 8.7 Account

### `GET /me` → the **User object**

```json
{
  "data": {
    "id": 5012,
    "name": "Ayesha Khan",
    "short_name": "Ayesha K.",
    "email": "ayesha@example.com",
    "email_verified": false,
    "phone": "03001234567",
    "phone_formatted": "0300 1234567",
    "member_since": "2026-09-24",
    "kyc_status": "not_started"
  }
}
```

- `email` is `null` for mobile-only accounts. `phone` / `phone_formatted` can be `null` on older accounts.
- `kyc_status`:

| Value | Meaning | UI |
|---|---|---|
| `not_started` | No profile submitted | "Complete your profile" CTA |
| `pending` | Submitted, waiting for the address visit / review | "Under review" (amber) |
| `verified` | Address verified by staff | Green tick |
| `rejected` | Verification failed | Coral, and allow resubmitting |

Name, email and phone are **read-only**. The password can change only through forgot password.

### `GET /me/preferences` → `{ "data": { "email_alerts": true } }`

### `PATCH /me/preferences`

```json
{ "email_alerts": false }
```

Same response shape. This turns off **alert emails** (application received, limit decided, KYC outcome, instalment reminders).
The inbox and push are unaffected. Security emails (codes, password changed) and the welcome email are always sent.

---

## 8.8 Dashboard

### `GET /dashboard`

The whole home screen in one call.

```json
{
  "data": {
    "kyc_status": "verified",
    "application_status": "approved",
    "banner": {
      "tone": "done",
      "title": "Verification complete",
      "text": "Your limit below is confirmed and ready to use at AtomShop checkout.",
      "cta": "Improve my limit",
      "action": "application"
    },
    "limit": {
      "has_limit": true,
      "status": "approved",
      "approved": 60000,
      "used": 20000,
      "available": 40000,
      "used_percent": 33,
      "max_instalment": 20000,
      "tenure": 12
    },
    "stages": [
      { "key": "kyc", "title": "KYC", "hint": "Identity details and CNIC uploaded", "state": "done" },
      { "key": "address", "title": "Address verification", "hint": "One-time physical visit by our team", "state": "done" },
      { "key": "income", "title": "Income assessment", "hint": "Your financial profile", "state": "done" },
      { "key": "risk", "title": "Risk assessment", "hint": "Reviewed by AtomPay", "state": "done" },
      { "key": "limit", "title": "Purchase limit", "hint": "Approved limit, instalment cap and tenure", "state": "done" },
      { "key": "shop", "title": "AtomShop purchase", "hint": "Choose AtomPay at checkout", "state": "current" }
    ],
    "next_due": {
      "id": 812, "order_id": 1043, "label": "2nd Instalment", "due_date": "2026-10-05",
      "amount": 12500, "paid_amount": null, "paid_on": null, "state": "due",
      "order_reference": "AS-01043", "product_title": "Poco C75 8GB RAM"
    },
    "plans": { "active_count": 1, "has_late": false },
    "unread_notifications": 2
  }
}
```

| Field | Notes |
|---|---|
| `application_status` | `null` (never applied) · `pending` · `approved` · `conditional` · `rejected`. This is the **latest** application. |
| `banner.tone` | `pending` (amber) · `blocked` (coral) · `done` (green) |
| `banner.action` | `apply` · `profile` · `application` (see 5.6). `text` may be the reviewer's own note. |
| `limit` | The limit **in force**. When `has_limit` is `false`, the money fields are `0` and `status` and `tenure` are `null`. Show "Not set yet". |
| `limit.status` | `approved` · `conditional` · `null` |
| `limit.used` | Unpaid AtomShop instalments. `available = max(0, approved − used)`. `used_percent` is 0–100. |
| `stages` | Always 6, in this order. `state` is `done` · `current` · `upcoming` · `blocked`. |
| `next_due` | The earliest unpaid instalment across all orders, or `null`. `product_title` may be `null`. |

**The 7 banner states** (so you can design for each):

| Situation | tone | title | cta → action |
|---|---|---|---|
| No profile yet | pending | Start your AtomPay application | Apply now → `apply` |
| Latest application rejected | blocked | Application not approved | Re-apply → `application` |
| Identity verification rejected | blocked | Verification unsuccessful | Update details → `profile` |
| Limit approved / conditional | done | Verification complete / Limit approved with conditions | Improve my limit → `application` |
| Profile in, no income yet | pending | Tell us about your income | Add income → `application` |
| Waiting for the address visit | pending | Address verification pending | Update details → `profile` |
| Address verified, under review | pending | Risk assessment in progress | Update income → `application` |

Always display the server's `title` / `text` / `cta`. The table is for design only.

---

## 8.9 Profile (identity, KYC section 1) & cities

### `GET /profile` → the **Profile object**

Before the first submission this is a draft **pre-filled from AtomShop** with `status: "not_started"`.

```json
{
  "data": {
    "status": "pending",
    "full_name": "Ayesha Khan",
    "cnic": "4210176543219",
    "cnic_formatted": "42101-7654321-9",
    "mobile": "03995556666",
    "mobile_formatted": "0399 5556666",
    "date_of_birth": "1992-03-14",
    "residential_address": "House 7, Street 3, Gulshan, Karachi",
    "city": { "id": 1, "name": "Karachi" },
    "documents": {
      "cnic_front": { "uploaded": true,  "url": "https://atompay.shop/api/v1/profile/documents/cnic_front" },
      "cnic_back":  { "uploaded": true,  "url": "https://atompay.shop/api/v1/profile/documents/cnic_back" },
      "selfie":     { "uploaded": false, "url": null }
    },
    "address_verified": false,
    "verified_at": null,
    "submitted_at": "2026-09-24T06:50:02+00:00"
  }
}
```

Any text field and `city` can be `null` in a draft. `status` uses the `kyc_status` values.

### `POST /profile` (multipart/form-data)

Creates or updates. Send **every text field every time**. Images are **required on the first submission** and
**optional later** (omit one to keep it, send one to replace it).

| Field | Rules |
|---|---|
| `full_name` | required, ≤ 255, as printed on the CNIC |
| `cnic` | required, 13 digits (dashes optional), first digit 1–7, not used by another customer |
| `mobile` | required, Pakistani mobile |
| `date_of_birth` | required, `YYYY-MM-DD`, **18+** ("You must be at least 18 to apply.") |
| `residential_address` | required, ≤ 1000 |
| `city_id` | optional, an `id` from `/cities` |
| `cnic_front`, `cnic_back`, `selfie` | image files: jpg / jpeg / png / webp, **≤ 4 MB each** |

**`201`** first time / **`200`** on update, returning the Profile object.

> Changing name, CNIC, DOB, address or any document sends the profile back to **`pending`** (staff re-verify). Warn the customer before changing a `verified` profile.

Dart (dio):

```dart
final form = FormData.fromMap({
  'full_name': p.fullName, 'cnic': p.cnic, 'mobile': p.mobile,
  'date_of_birth': p.dob, 'residential_address': p.address,
  if (p.cityId != null) 'city_id': p.cityId,
  if (front != null) 'cnic_front': await MultipartFile.fromFile(front.path, filename: 'cnic_front.jpg'),
  if (back != null)  'cnic_back':  await MultipartFile.fromFile(back.path,  filename: 'cnic_back.jpg'),
  if (selfie != null) 'selfie':    await MultipartFile.fromFile(selfie.path, filename: 'selfie.jpg'),
});
await dio.post('/profile', data: form, onSendProgress: (s, t) => progress(s / t),
    options: Options(sendTimeout: const Duration(seconds: 120)));
```

### `GET /profile/documents/{document}`

`{document}` is `cnic_front` · `cnic_back` · `selfie`. It streams the customer's **own** image (`Cache-Control: private, no-store`) and
**needs the bearer header**:

```dart
Image.network(url, headers: {'Authorization': 'Bearer $token'})   // no disk cache
```

`404` = not uploaded.

### `GET /cities`

```json
{ "data": [ { "id": 59, "name": "Ahmadpur East" }, { "id": 99, "name": "Alipur" } ] }
```

Active cities, A–Z. Cache for the session.

---

## 8.9b Application (income, KYC section 3)

### `GET /application`

```json
{
  "data": {
    "can_apply": true,
    "requires": null,
    "latest": { "…": "Assessment object or null" },
    "active": { "…": "Assessment object or null" }
  }
}
```

- `can_apply: false` → `requires: "profile"`. Send the customer to the profile form.
- Pre-fill the form from `latest`.
- `active` is the limit **in force**, which can differ from `latest` while a re-application is pending.

**Assessment object:**

```json
{
  "id": 311,
  "status": "pending",
  "status_label": "Pending",
  "is_usable": false,
  "employment_status": "salaried",
  "employment_status_label": "Salaried",
  "employer_name": "Acme Ltd",
  "income_source": "salary",
  "income_source_label": "Salary",
  "monthly_income": 200000,
  "existing_instalments": 10000,
  "monthly_expenses": 90000,
  "disposable_income": 100000,
  "approved_limit": null,
  "max_instalment": null,
  "approved_tenure": null,
  "notes": null,
  "submitted_at": "2026-09-24T07:10:00+00:00",
  "decided_at": null
}
```

- `status`: `pending` · `approved` · `conditional` · `rejected`. `is_usable` is true for `approved` and `conditional`.
- `approved_limit`, `max_instalment`, `approved_tenure` and `notes` stay **`null` until staff decide**.
- `notes` is written by staff for the customer. Show it.
- `disposable_income` can be negative (income < obligations).

### `POST /application` (JSON) → `201 Created` (the Assessment object)

```json
{
  "employment_status": "salaried",
  "employer_name": "Acme Ltd",
  "income_source": "salary",
  "monthly_income": 200000,
  "existing_instalments": 10000,
  "monthly_expenses": 90000
}
```

| Field | Rules |
|---|---|
| `employment_status` | required, a `value` from `/options` |
| `employer_name` | ≤ 255. **Required when that status has `has_employer: true`** ("Please tell us your employer or business name.") |
| `income_source` | required, a `value` from `/options` |
| `monthly_income` | required, integer, 1,000 – 100,000,000 |
| `existing_instalments` | optional (default 0), integer ≥ 0 |
| `monthly_expenses` | optional (default 0), integer ≥ 0 |

`409 profile_required` means no profile has been submitted yet. Every submission creates a **new** pending assessment, and the limit in force is not affected until staff decide. Re-applying is how a customer asks for a higher limit.

### `GET /application/history`

`{ "data": [ Assessment, … ] }`, newest first.

---

## 8.10 Calculator & estimate (public)

Pricing (the same as AtomShop checkout):

```
markup  = round(per_month% × months × (price − advance))
total   = price + markup
monthly = ceil((total − advance) / months)
```

### `GET /calculator`

```json
{
  "data": {
    "tenures": [3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
    "per_month_percentage": 4,
    "advance": { "min_ratio": 0.2, "max_ratio": 0.6 },
    "price": { "min": 10000, "max": 300000, "step": 5000 }
  }
}
```

The values come from AtomShop's admin and can change, so fetch them each time the calculator opens. `per_month_percentage` may be a decimal (e.g. `3.5`).

### `POST /quote`

```json
{ "price": 100000, "months": 6, "advance": 25000 }
```

`advance` is optional (defaults to the minimum, 20%).

```json
{
  "data": {
    "price": 100000, "advance": 20000, "months": 6, "per_month_percentage": 4,
    "financed": 80000, "markup": 19200, "total": 119200, "monthly": 16534,
    "advance_bounds": { "min": 20000, "max": 60000 }
  }
}
```

`422` field errors: `months` → "Choose one of: 3, 4, … months." · `advance` → "Down payment must be between PKR 20,000 and PKR 60,000."
Debounce about 300 ms (limit 60/min).

### `POST /estimate`

```json
{ "monthly_income": 150000 }
```

```json
{ "data": { "monthly_income": 150000, "estimated_limit": 45000, "estimated_max_instalment": 15000 } }
```

Nothing is saved, and this is not an application. **Always label it "estimate".** `monthly_income`: 1,000 – 100,000,000.

---

## 8.10b Plans

### `GET /plans` (`?include=completed` for history)

Orders with repayments running (`Processing`, `Delivered`, `Instalments`). With `include=completed`, also fully repaid ones. Newest first.

```json
{
  "data": [
    {
      "order": {
        "id": 1043, "reference": "AS-01043", "status": "Instalments", "status_label": "Instalments",
        "ordered_at": "2026-07-02T10:15:00+00:00",
        "total_price": 140000, "advance": 24000, "financed": 116000, "tenure": 6
      },
      "product": {
        "id": 47, "title": "Poco C75 8GB RAM",
        "picture_url": "https://atomshop.pk/uploads/…jpg",
        "shop_url": "https://atomshop.pk/product/poco-c75"
      },
      "state": "on_track",
      "progress": {
        "paid_count": 2, "total_count": 6, "paid_amount": 38666, "total_amount": 116000,
        "remaining_amount": 77334, "percent": 33
      },
      "next_due": { "…": "Instalment object or null" }
    }
  ]
}
```

- `state`: `on_track` · `late` (any instalment overdue) · `completed`.
- `product` can be `null` (removed from AtomShop). `picture_url` is public (no auth header, OK to cache).
- `order.status` values: `Processing`, `Delivered`, `Instalments`, `Completed` (plus rare `Pending`, `Varification`, `Cancelled` on the detail endpoint). Display `status_label`.

### `GET /plans/{order_id}`

The same object **plus** `instalments` (the full schedule). `404` if it isn't yours.

**Instalment object:**

```json
{ "id": 812, "order_id": 1043, "label": "2nd Instalment", "due_date": "2026-09-05",
  "amount": 19334, "paid_amount": null, "paid_on": null, "state": "late" }
```

`label` is AtomShop's own text, so display it as it is. `order_reference` and `product_title` are present **only** on the dashboard's `next_due`.

| `state` | Meaning | Colour |
|---|---|---|
| `paid` | Paid | ok |
| `late` | Past due and unpaid | coral |
| `due` | Due within 14 days | amber |
| `upcoming` | Later | muted |

Payments are made through AtomShop's channels. The app only shows status.

---

## 8.11 Push devices & notifications

### `POST /devices` → `201` (new) / `200` (already registered)

Call this after **every sign-in** and on every `FirebaseMessaging.instance.onTokenRefresh`.

```json
{ "fcm_token": "dXk…", "platform": "android", "app_version": "1.0.0" }
```

`platform`: `android` | `ios`. `app_version` ≤ 20 chars.

```json
{ "data": { "id": 7, "platform": "android", "app_version": "1.0.0", "registered_at": "2026-09-24T07:06:09+00:00" } }
```

A device is tied to the sign-in that registered it. Signing out removes it. If another account signs in on the same phone, the device moves to that account.

### `DELETE /devices` → `204`

```json
{ "fcm_token": "dXk…" }
```

Use this when the customer turns push off in the app.

### Push payload

Each push has a `notification` block (title + body, shown by the OS) and a `data` block. **Every `data` value is a string.**

| Key | Present | Example |
|---|---|---|
| `notification_id` | always | `"57"` → `POST /notifications/57/read` |
| `type` | always | `"instalment_due"` |
| `screen` | always | `"dashboard"` · `"plan"` · `"profile"` |
| `order_id` | `screen = plan` | `"1043"` → open `/plans/1043` |
| `instalment_id` | `screen = plan` | `"812"` |
| `assessment_id` | `application_received`, `limit_decided` | `"311"` |

**Routing on tap:** `dashboard` → Home · `plan` → Plan detail (`order_id`) · `profile` → Profile. Unknown value → Home.
On Android, create the channel **`atompay_default`** at startup. In the foreground, show a local notification and refresh the dashboard.

### Notification types

| `type` | When | Example title |
|---|---|---|
| `application_received` | Income application submitted, not decided yet | "We've received your application" |
| `limit_decided` | Approved / conditional / rejected | "Your AtomPay limit is approved" · "Your limit is approved with conditions" · "Application not approved" |
| `kyc_verified` | Address verified | "Your address is verified" |
| `kyc_rejected` | Verification failed (body = reviewer's note) | "We could not verify your details" |
| `instalment_due` | 3 days before, and on the due date | "Instalment due in 3 days" · "Instalment due today" |
| `instalment_overdue` | 1 and 7 days after, if unpaid | "Instalment overdue" |

Created by a server job every 10 minutes. Each event is announced once. Reminders only go out 09:00–21:00 Pakistan time.
Each notification reaches the **inbox (always)**, **push** (if registered and the server has FCM) and **email** (unless turned off, or the account has no real email).

### `GET /notifications?page=1`

20 per page, newest first (Laravel pagination + `meta.unread_count`).

```json
{
  "data": [
    {
      "id": 57,
      "type": "instalment_due",
      "title": "Instalment due in 3 days",
      "body": "PKR 12,500 for Poco C75 8GB RAM is due on 5 Oct.",
      "payload": { "screen": "plan", "order_id": 1043, "instalment_id": 812 },
      "read": false,
      "created_at": "2026-10-02T04:00:00+00:00"
    }
  ],
  "links": { "first": "…?page=1", "last": "…?page=3", "prev": null, "next": "…?page=2" },
  "meta": { "current_page": 1, "last_page": 3, "per_page": 20, "total": 47, "unread_count": 2 }
}
```

`payload` has the same keys as the push `data`, but here the **ids are numbers** (in push they are strings). `meta` also contains Laravel's standard `from`, `to`, `path` and `links` keys, which you can ignore.

### `POST /notifications/{id}/read` → the updated notification (`404` if it isn't yours)

### `POST /notifications/read-all` → `204`

---

## 8.12 App config & options (public)

### `GET /app-config`

Call this on every launch, before `/me`.

```json
{
  "data": {
    "min_version": { "android": "1.0.0", "ios": "1.0.0" },
    "store_url": { "android": "https://play.google.com/…", "ios": null },
    "shop_url": "https://atomshop.pk",
    "password_reset_url": "https://atompay.shop/forgot-password",
    "support": { "phone": null, "whatsapp": null, "email": null },
    "features": {
      "push": true,
      "password_reset_channels": ["email", "whatsapp"],
      "signup_channels": ["email", "whatsapp"]
    }
  }
}
```

- App version < `min_version[platform]` (semver compare) → the blocking **Update required** screen → `store_url[platform]`.
- `features.push: false` → skip the notification permission prompt and don't register devices.
- `*_channels` is `["email"]` or `["email","whatsapp"]`. Without `whatsapp`, hide the mobile option.
- `password_reset_url` is a website fallback only. The app's flow is native.
- Hide any `support` entry that is `null`.

### `GET /options`

```json
{
  "data": {
    "employment_statuses": [
      { "value": "salaried", "label": "Salaried", "has_employer": true },
      { "value": "self_employed", "label": "Self-employed", "has_employer": true },
      { "value": "business_owner", "label": "Business owner", "has_employer": true },
      { "value": "freelancer", "label": "Freelancer", "has_employer": false },
      { "value": "retired", "label": "Retired", "has_employer": false },
      { "value": "unemployed", "label": "Unemployed", "has_employer": false }
    ],
    "income_sources": [
      { "value": "salary", "label": "Salary" }, { "value": "business", "label": "Business" },
      { "value": "rental", "label": "Rental" }, { "value": "remittance", "label": "Remittance" },
      { "value": "pension", "label": "Pension" }, { "value": "other", "label": "Other" }
    ]
  }
}
```

Send `value` and display `label`. Show the employer field only when `has_employer` is true.

---

## 8.13 API versioning promise

- The API is versioned in the path (`/api/v1`). Within v1 the server **may add** fields and endpoints but will **never rename, remove or retype** them.
  A breaking change means `/api/v2`, and v1 keeps working.
- So: ignore unknown keys, and treat unknown enum values gracefully (fall back to a neutral style and show the `*_label` / text the server sent).

---

# 9. Appendix

## 9.1 Dart helpers (these mirror the server's validation exactly)

```dart
/// Pakistani CNIC and mobile helpers, matching the server's rules.
class Pk {
  static const _provinces = {'1', '2', '3', '4', '5', '6', '7'};

  static String digits(String? v) => (v ?? '').replaceAll(RegExp(r'\D'), '');

  // ---- CNIC: 13 digits, first digit 1–7, not all zeros ----
  static String normalizeCnic(String? v) => digits(v);

  static bool isValidCnic(String? v) {
    final d = digits(v);
    return d.length == 13 && _provinces.contains(d[0]) && d.replaceAll('0', '').isNotEmpty;
  }

  static String formatCnic(String? v) {
    final d = digits(v);
    return d.length == 13 ? '${d.substring(0, 5)}-${d.substring(5, 12)}-${d.substring(12)}' : (v ?? '');
  }

  // ---- Mobile: every form → 03XXXXXXXXX, or '' if not a PK mobile ----
  static String normalizeMobile(String? v) {
    var d = digits(v);
    for (final p in ['0092', '92']) {
      if (d.startsWith(p) && d.length > p.length) { d = d.substring(p.length); break; }
    }
    if (RegExp(r'^3\d{9}$').hasMatch(d)) d = '0$d';
    return RegExp(r'^03\d{9}$').hasMatch(d) ? d : '';
  }

  static bool isValidMobile(String? v) => normalizeMobile(v).isNotEmpty;

  static String formatMobile(String? v) {
    final d = normalizeMobile(v);
    return d.isEmpty ? (v ?? '') : '${d.substring(0, 4)} ${d.substring(4)}';
  }

  static bool isEmail(String v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());

  /// For the sign-up / forgot "email or mobile" field.
  static bool looksLikeMobile(String v) => RegExp(r'^[\d\s+\-()]+$').hasMatch(v.trim());
}

/// Money: int rupees → "PKR 45,000".
String pkr(int amount) => 'PKR ${NumberFormat.decimalPattern('en_US').format(amount)}';

/// Age check for the DOB picker (server: at least 18 years old).
bool isAdult(DateTime dob, {DateTime? now}) {
  final t = now ?? DateTime.now();
  return !DateTime(dob.year + 18, dob.month, dob.day).isAfter(t);
}
```

Test cases that must pass:

| Input | `normalizeMobile` |
|---|---|
| `0300 1234567` | `03001234567` |
| `+92 300 1234567` | `03001234567` |
| `0092-300-1234567` | `03001234567` |
| `923001234567` | `03001234567` |
| `3001234567` | `03001234567` |
| `021 34567890` (landline) | `''` |

| Input | `isValidCnic` |
|---|---|
| `42101-7654321-9` | true |
| `8210176543219` (first digit 8) | false |
| `0000000000000` | false |
| `421017654321` (12 digits) | false |

Note: the server tells a landline apart from a mobile and gives a specific message. Client-side, "not a valid mobile" is enough.

## 9.2 Suggested copy (English, for `app_en.arb`)

| Key | Text |
|---|---|
| signInTitle | Sign in with your AtomShop account |
| signUpSmallPrint | This also creates your AtomShop.pk account. |
| hintCodeByEmail | We'll email you a code. |
| hintCodeByWhatsapp | We'll send the code on WhatsApp. |
| codeSentTo | We sent a 6-digit code to {destination}. |
| resendIn | Send a new code in {seconds}s |
| forgotNeutral | If this belongs to an AtomShop account, we've sent a code to {destination}. |
| passwordChangedToast | Password changed. It works on AtomShop.pk too. |
| verifiedEditWarning | Changing these details sends your profile back for verification. |
| limitNotSet | Not set yet |
| availableToSpend | AVAILABLE TO SPEND |
| estimateLabel | Estimate. Your real limit is decided after review. |
| quoteLabel | Estimate. The exact figures are confirmed at AtomShop checkout. |
| payOffline | Pay through AtomShop's usual payment channels. |
| reapplyNote | Your current limit stays in force while we review your new application. |
| offline | You're offline. Showing your last update. |
| rateLimited | Too many attempts. Try again in {seconds}s. |
| genericError | Something went wrong. Please try again. |
| updateRequired | A new version of AtomPay is available. Please update to continue. |

## 9.3 Glossary

| Term | Meaning |
|---|---|
| **AtomShop** | The online store (atomshop.pk). It owns user accounts, orders and products. |
| **AtomPay** | The instalment service and this app. It owns assessments, KYC and notifications. |
| **KYC** | Know Your Customer: identity (section 1), address visit (section 2), income (section 3), risk (section 4), decision (section 5). |
| **Profile** | KYC section 1 in the app (identity + CNIC photos + selfie). |
| **Application / Assessment** | KYC section 3 (income). Each submission is a new assessment. |
| **Limit** | The approved amount the customer can have outstanding at once. |
| **Used / Available** | Unpaid instalments against the limit / what's left to spend. |
| **Max instalment** | The highest monthly payment the customer is approved for. |
| **Tenure** | Number of months for repayment. |
| **Advance / Down payment** | The upfront payment, 20–60% of the price. |
| **Conditional** | Approved with conditions (the conditions are in `notes`). It's still a usable limit. |
| **CNIC** | Pakistani national ID card number (13 digits). |

## 9.4 Test data & local setup

- Run the server locally (XAMPP, `http://localhost/atompay`). Ask the backend owner for a **test customer account** and a seeded order with instalments.
- Codes in local dev are in `storage/logs/laravel.log` (email codes are logged, and WhatsApp codes are logged when it isn't configured).
- A Postman / Bruno collection can be generated from section 8. Every example there is pinned by the server's automated tests.

## 9.5 Open questions (decide before the listed phase)

| # | Question | Needed by |
|---|---|---|
| 1 | Package name / bundle id (e.g. `pk.atomshop.atompay`), and whether it publishes under AtomShop's store accounts | Phase 0 |
| 2 | Staging server URL | Phase 1 |
| 3 | In-app payments (JazzCash / Easypaisa / card), or payments stay offline through AtomShop? (v1: offline) | Post-v1 |
| 4 | Sign-up rate limit of 5/hour per IP may hit users behind carrier NAT. The server may need to change it before launch | Launch |
| 5 | Support phone / WhatsApp / email values for `/app-config` | Release |
| 6 | Privacy policy URL for the store listings | Release |

---

*Server-side source of truth: `routes/api.php` and `docs/api/` in the AtomPay repo. When the API changes, the backend
updates both, and this handbook should be regenerated from them.*
