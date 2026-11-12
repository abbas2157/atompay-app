# AtomPay Mobile API — v1

The contract the AtomPay Flutter app is built against. It has one file per area, and they're
listed below. For one self-contained file to hand to the app builder (PRD, architecture, design, screens,
rules, tasks and this whole API), see [../MOBILE_APP_HANDBOOK.md](../MOBILE_APP_HANDBOOK.md).

- **Server code:** `routes/api.php`, `app/Http/Controllers/Api/V1/`, `app/Http/Resources/Api/V1/`
- **Tests** that pin every example in these files: `tests/Feature/Api/`
- **Status:** Every v1 endpoint is live (49 endpoints).

| | |
|---|---|
| Production base URL | `https://atompay.shop/api/v1` |
| Local (XAMPP) | `http://localhost/atompay/api/v1` |
| Android emulator | `http://10.0.2.2/atompay/api/v1` |
| Auth | `Authorization: Bearer <token>` (Sanctum). Always send `Accept: application/json` |

**Start with [conventions.md](conventions.md).** It covers the envelope, money, dates, CNIC/phone
formats, every error status, the `409` codes, rate limits, and the token lifecycle. Every other file assumes it.

## Files

| File | Covers |
|---|---|
| [conventions.md](conventions.md) | Base URLs, conventions, errors, rate limits, token lifecycle |
| [auth.md](auth.md) | Register, login, logout, logout everywhere, signed-in sessions, **forgot password (OTP by email / WhatsApp)** |
| [account.md](account.md) | `GET /me`, `kyc_status` values, email-alert preference, **account deletion** |
| [profile.md](profile.md) | KYC Section 1 (identity + CNIC/selfie uploads), own documents, cities, **areas** |
| [application.md](application.md) | KYC Section 3 (income → limit), the assessment object, history |
| [dashboard.md](dashboard.md) | Home screen: limit card, status banner, stepper, next due |
| [plans.md](plans.md) | AtomShop instalment orders and their schedules, **Key Fact Statement** (with `accepted_at`) |
| [orders.md](orders.md) | **Buy with AtomPay**: the Key Fact Statement for a product, then the order (Atomshop places it) |
| [products.md](products.md) | AtomPay-eligible products, categories, **plan preview** (public) |
| [ask-atom.md](ask-atom.md) | Ask Atom chips and answers (public) |
| [complaints.md](complaints.md) | In-app complaints (Help › Complaints) |
| [calculator.md](calculator.md) | AtomPay plan calculator and quote (not used by the v2 app, which calls `/plan-preview`), income estimate (all public) |
| [app-config.md](app-config.md) | Launch config (force update, links, support, **company facts: `business`**) and form options (public) |
| [notifications.md](notifications.md) | Push device registration, push payload, notifications inbox, email/push/inbox channels |

## Endpoint index

| Method | Path | Auth | Doc |
|---|---|---|---|
| GET | `/app-config` | – | [app-config.md](app-config.md) |
| GET | `/options` | – | [app-config.md](app-config.md) |
| GET | `/calculator` | – | [calculator.md](calculator.md) |
| POST | `/quote` | – | [calculator.md](calculator.md) |
| POST | `/estimate` | – | [calculator.md](calculator.md) |
| GET | `/plan-preview` | optional | [products.md](products.md#get-plan-preview) |
| GET | `/products` | optional | [products.md](products.md) |
| GET | `/products/categories` | – | [products.md](products.md) |
| GET | `/products/{id}` | optional | [products.md](products.md) |
| GET | `/products/{id}/kfs` | ✓ | [orders.md](orders.md) |
| POST | `/orders` | ✓ | [orders.md](orders.md) |
| GET | `/ask-atom/chips` | – | [ask-atom.md](ask-atom.md) |
| POST | `/ask-atom` | optional | [ask-atom.md](ask-atom.md) |
| POST | `/auth/register` | – | [auth.md](auth.md#sign-up-one-time-code) |
| POST | `/auth/register/verify` | – | [auth.md](auth.md#sign-up-one-time-code) |
| POST | `/auth/register/resend` | – | [auth.md](auth.md#sign-up-one-time-code) |
| POST | `/auth/login` | – | [auth.md](auth.md) |
| POST | `/auth/password/forgot` | – | [auth.md](auth.md#forgot-password-otp) |
| POST | `/auth/password/verify` | – | [auth.md](auth.md#forgot-password-otp) |
| POST | `/auth/password/reset` | – | [auth.md](auth.md#forgot-password-otp) |
| POST | `/auth/logout` | ✓ | [auth.md](auth.md) |
| POST | `/auth/logout-all` | ✓ | [auth.md](auth.md) |
| GET | `/auth/sessions` | ✓ | [auth.md](auth.md) |
| DELETE | `/auth/sessions/{id}` | ✓ | [auth.md](auth.md) |
| GET | `/me` | ✓ | [account.md](account.md) |
| GET | `/me/preferences` | ✓ | [account.md](account.md) |
| PATCH | `/me/preferences` | ✓ | [account.md](account.md) |
| POST | `/me/delete` | ✓ | [account.md](account.md#post-medelete) |
| POST | `/me/password` | ✓ | [account.md](account.md#post-mepassword) |
| GET | `/dashboard` | ✓ | [dashboard.md](dashboard.md) |
| GET | `/profile` | ✓ | [profile.md](profile.md) |
| POST | `/profile` | ✓ | [profile.md](profile.md) |
| GET | `/profile/documents/{document}` | ✓ | [profile.md](profile.md) |
| GET | `/cities` | ✓ | [profile.md](profile.md) |
| GET | `/areas` | ✓ | [profile.md](profile.md#get-areascity_idid) |
| GET | `/application` | ✓ | [application.md](application.md) |
| POST | `/application` | ✓ | [application.md](application.md) |
| GET | `/application/history` | ✓ | [application.md](application.md) |
| GET | `/plans` | ✓ | [plans.md](plans.md) |
| GET | `/plans/{order_id}` | ✓ | [plans.md](plans.md) |
| GET | `/plans/{order_id}/kfs` | ✓ | [plans.md](plans.md#get-plansorder_idkfs) |
| POST | `/plans/{order_id}/kfs/send` | ✓ | [plans.md](plans.md#post-plansorder_idkfssend) |
| GET | `/complaints` | ✓ | [complaints.md](complaints.md) |
| POST | `/complaints` | ✓ | [complaints.md](complaints.md) |
| POST | `/devices` | ✓ | [notifications.md](notifications.md) |
| DELETE | `/devices` | ✓ | [notifications.md](notifications.md) |
| GET | `/notifications` | ✓ | [notifications.md](notifications.md) |
| POST | `/notifications/{id}/read` | ✓ | [notifications.md](notifications.md) |
| POST | `/notifications/read-all` | ✓ | [notifications.md](notifications.md) |

## Suggested app flow

1. Launch: `GET /app-config` (force update?), then `GET /me` if a token is stored.
2. Sign in, or register (`/auth/register` with an email or a mobile, then `/auth/register/verify` with the code
   that arrived by email or on WhatsApp),
   then `POST /devices` (if push is enabled). "Forgot password?" runs
   `/auth/password/forgot`, then `/verify`, then `/reset`, which ends signed in.
3. Home: `GET /dashboard`, and follow `banner.action` to the profile or application form.
4. Profile form: `GET /profile` + `GET /cities` (+ `GET /areas?city_id=` once a city is picked), then `POST /profile` (multipart).
5. Income form: `GET /options` + `GET /application`, then `POST /application`.
6. Orders tab: `GET /plans`, then `GET /plans/{id}` and its `/kfs`.
   Shop tab: `GET /products` (+ `/products/categories`), product detail `GET /products/{id}`, calculator `GET /plan-preview`.
   Ask Atom: `GET /ask-atom/chips`, then `POST /ask-atom`. Help: `POST /complaints`.
7. Inbox: `GET /notifications`. A push tap routes by `data.screen`.

## Rules for changing this API

- Update the endpoint's file here **in the same commit** as the code change, and add a
  changelog line below.
- Within v1 you can add fields and endpoints, but never rename, remove or retype them. A breaking change
  requires `/api/v2`.
- Every endpoint has a feature test in `tests/Feature/Api/`.

## Changelog

| Date | Change |
|---|---|
| 2026-11-12 | **Buy with AtomPay in the app.** New: `GET /products/{id}/kfs`, `POST /orders` ([orders.md](orders.md)); Atomshop places the order. Added field: `/app-config` → `features.in_app_orders` (off until both servers share `ATOMPAY_SERVER_KEY`). New `409` codes: `orders_unavailable`, `limit_required`, `over_limit`, `over_cap`, `address_required`, `order_in_progress`. Nothing renamed or removed. |
| 2026-11-12 | **KYC images are malware-checked.** `POST /profile` can return two new `422` messages on `cnic_front` / `cnic_back` / `selfie` (refused file; scanner briefly unavailable). See [profile.md](profile.md#post-profile-multipartform-data). No shape change. |
| 2026-11-12 | **`/calculator` and `/quote` price AtomPay's plan**, not Atomshop seller financing: tenures `[3]`, no advance, 0% markup. Same response shape; values changed. Added fields: `plan` (both), `processing_fee_percent` (both), `last_monthly` and `processing_fee` (`/quote`). A `months` other than 3 or any non-zero `advance` is a `422` field error. |
| 2026-11-10 | **v2 app endpoints.** New: `GET /areas`, `GET /plan-preview`, `GET /products`, `/products/categories`, `/products/{id}`, `GET /plans/{id}/kfs`, `POST /plans/{id}/kfs/send`, `GET\|POST /complaints`, `GET /ask-atom/chips`, `POST /ask-atom`, `POST /me/password`. Added fields: `/app-config` → `maintenance`, `apps`, `features.voice`; `/options` → `complaint_topics`; `/profile` → `area`. Nothing renamed or removed. |
| 2026-10-10 | **`GET /plans` lists every order**, in any status, including AtomPay-financed ones. `state` gains `pending`, `processing` and `cancelled`, and `?include=completed` is ignored. `GET /dashboard` gains `plans.pending_count`, and `active_count` counts only orders being repaid. `POST /application` can return `409 nothing_changed` once a limit is approved. |
| 2026-09-27 | **Sign-up needs a one-time code.** `POST /auth/register` now takes `name`, `login` (an email **or** a mobile) and `password`, and returns `202` with a `signup_id` and no account. The code is sent by email or on WhatsApp, depending on what was typed. The new `POST /auth/register/verify` creates the account and returns the login body (`201`), and `POST /auth/register/resend` resends the code. Mobile-only accounts have `email: null`. `/app-config` gains `features.signup_channels`. The request and response of `/auth/register` changed, which is allowed because no app has shipped. |
| 2026-09-26 | Forgot password with OTP by email or WhatsApp (`/auth/password/forgot`, `/verify`, `/reset`). `GET/PATCH /me/preferences` for alert emails. New notification type `application_received`, and every notification is also emailed. `/app-config`: `password_reset_url` now points at AtomPay's own page, and `features.password_reset_channels` was added. **Removed `uuid` from `/me`**, because it unlocks AtomShop's reset link. No app has shipped yet, so this is allowed within v1. |
| 2026-09-24 | Docs split into `docs/api/` (one file per area). No API change. |
| 2026-09-24 | v1 complete: `/app-config`, `/options`, `/calculator`, `/quote`, `/estimate`, `/dashboard`, `/application` (+ history), `/plans`, `/devices`, `/notifications`, `/auth/sessions`. Logout now also unregisters the device. |
| 2026-09-24 | v1 Phase 1: auth (register, login, logout, logout-all), `/me`, `/profile`, `/profile/documents/*`, `/cities`. |
