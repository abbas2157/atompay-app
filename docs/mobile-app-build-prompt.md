# Prompt: build the AtomPay mobile app (v2)

> Paste this whole file into the agent or hand it to the Flutter developer. It is the brief for
> building the app end to end. Where it disagrees with an older document, **this file wins**.

---

## 0. Your task

Build **AtomPay** for Android and iOS in Flutter: the customer app for AtomPay, Atomshop.pk's
"pay in 3 months" option. You build every screen in the design canvas, wire it to the
AtomPay API, and ship something that passes Google Play and App Store review.

Work in this order:

1. Read the sources in §1.
2. Set up the project and design system (§3, §4).
3. Build the app shell, router and guards (§5).
4. Build the features in the phases in §14. Each phase ends with its tests passing.

Ask before inventing anything: copy, numbers, legal text, endpoints, permissions. Every
placeholder in the canvas (`[LICENSED ENTITY NAME]`, `[RESPONSE TIME]`…) stays a visible
placeholder until the business supplies the real value. Never fill one with a guess.

## 1. Sources of truth, in order

| # | Source | Use it for |
|---|---|---|
| 1 | **This file** | Scope, rules, decisions, the new endpoint contracts (§7.2) |
| 2 | **Design canvas**: https://claude.ai/artifact/GbdbQz33JzdFyLpRb8AtNJ | Every screen, state, copy, spacing and the reference boards: Style guide, Navigation rules, States, Compliance, Architecture. *Private: the owner must share it with you.* |
| 3 | `docs/api/*.md` | The live API contract: shapes, errors, rate limits |
| 4 | `docs/MOBILE_APP_HANDBOOK.md` | Architecture (§3), security (§6.3), testing (§6.5), release (§6.6) |
| 5 | `docs/mobile-app-v2-redesign-prompt.md` | Token values and contrast pairs (same as §4 here) |

Superseded parts of the handbook:

- **Navigation:** §5.1's Home · Plans · Profile is replaced by §5 of this file.
- **Calculator:** §5.10's tenure and advance controls are gone (see §2).
- **Languages:** any Urdu UI is out (the app is English only).

## 2. The product in five rules

1. **AtomPay sells nothing.** Customers shop on Atomshop.pk and choose AtomPay at checkout. The
   app shows the limit, eligible products, orders, payments and help.
2. **One plan:** 3 months, **no advance, 0% markup**. Monthly = `intdiv(price, 3)`, and the
   **last** month takes the rounding (Rs. 47,000 → 15,666 · 15,666 · 15,668). A 3% processing
   fee is shown as a disclaimer with every plan; delivery charges apply. The server sends every
   figure. The app formats, never calculates.
3. **One account.** AtomPay signs in with the customer's **AtomShop** account (same users
   table). Sign-up creates an Atomshop.pk account. Password changes and deletion affect both.
4. **Limit** = 30% of monthly income; monthly cap = min(10% of income, disposable income).
   Server-computed; shown, never derived.
5. **English only.** No language switch, no RTL. (Open: SECP wants the Key Fact Statement in
   Urdu too, see §11.)

## 3. Stack and architecture

Follow handbook §3 exactly:

- **Packages:** Flutter stable, Riverpod (code-gen), go_router, dio, freezed + json_serializable,
  flutter_secure_storage.
- **Structure:** feature-first, layered: `presentation → application (notifiers) → repository → data (dio)`.
  Widgets never import dio.
- **Errors:** one sealed `ApiException` (`Unauthenticated`, `Forbidden`, `NotFound`,
  `Conflict(code)`, `Validation(fieldErrors)`, `RateLimited(retryAfter)`, `Server`, `Offline`,
  `Timeout`). Screens switch on its type, never on status codes.
- **Flavors:** dev (`http://10.0.2.2/atompay/api/v1`), staging, prod (`https://atompay.shop/api/v1`).
- **Repository per feature,** each with a fake implementation selected by a flag. Endpoints in
  §7.2 that aren't live yet run on their fake, returning exactly the documented shape.

Extra packages this design needs (nothing else without asking):

| Package | Used for |
|---|---|
| `package_info_plus` | Version on Account, Settings, Rate us |
| `permission_handler` | Permissions screen, camera and microphone status |
| `speech_to_text` | Ask Atom voice input (device recogniser, English) |
| `flutter_tts` | "Listen" (read an answer aloud) |
| `url_launcher` | External links, store pages, tel/mailto/WhatsApp |
| `in_app_review` | `openStoreListing()` only. Never `requestReview()` from a button. |
| `connectivity_plus` | Offline banner |
| `app_links` | Deep links (§5.5) |
| `flutter_windowmanager` or equivalent | `FLAG_SECURE` on KYC capture and document screens |

## 4. Design system

Copy the tokens into a `ThemeExtension`. Never write a hex value or a font size in a widget.

**Colour:**

| Token | Hex | Token | Hex |
|---|---|---|---|
| ink | #14213D | surface | #F5F7FB |
| ink-2 / ink-3 | #1C2740 / #22305A | surface-2 / field | #F8FAFE / #FBFCFE |
| primary | #2747C7 | line / line-2 / line-3 | #E3E8F1 / #DCE2EC / #C9D2E3 |
| primary-dark | #1D3AA6 | grey-soft / skel / glyph | #EEF1F6 / #E9EDF4 / #AAB5C8 |
| primary-soft / primary-line | #EEF2FD / #CFD9F7 | green / green-soft | #18794A / #E8F7EF |
| body | #4F5B76 | amber (fill only) / amber-soft / amber-ink | #F7A928 / #FFF5E0 / #8A5A00 |
| muted | #656F88 | rose (text) / rose-soft / rose-line | #B0283F / #FDEEF1 / #F3C9D1 |
| on-dark / on-dark-2 | #D7DEEC / #B9C2D6 | apay-coral / apay-amber | #F05465 / #FAA53A |
| white | #FFFFFF | apay-wash / apay-line | #FFF6EE / #F6DFD2 |

- **AtomPay gradient:** `linear 135°, #FAA53A → #F05465`. It fills **only** the limit card, which
  carries solid ink text (4.69:1 on coral). Coral and amber are never text.
- **Type:** Plus Jakarta Sans 400–800. The only sizes are **11 · 12 · 13 · 14 · 15 · 17 · 20 · 22 · 24 · 30 · 38**,
  with tabular figures for money.
- **Shape:**
  - cards: 24 radius
  - controls and pills: 999
  - inputs: 14
  - sheets: 24 top
  - list rows: 16
- **Spacing:** steps of 2/4/6/8, 16 px screen gutters.
- **Touch targets:** at least **48 dp**. Small controls (switches, thumbs up/down) keep their look and
  get an invisible 48 dp hit area.
- **Interaction states** on every control:
  - focus: 3 dp primary ring with a 2 dp gap; white on the camera
  - pressed: darker fill and 98% scale
  - disabled
  - busy: the spinner replaces the label and keeps its width
- **Reduced motion:** honour it everywhere (shimmer, waveform, scale).

Build these shared widgets once and use them everywhere:

- AppBar (back, close, title, action)
- `ListRow`: icon tile, title, one-line summary, optional badge, then a chevron, or ↗ for external
  links. Every settings-style row is a `ListRow`.
- Buttons: primary, dark, ghost, amber, danger
- Field and Input: label, hint, inline error
- `PickerField` with `PickerSheet` (§6)
- Card, Badge (paid, due, late, under review, blue, grey), Note (green, rose, blue, wash)
- LimitCard (gradient), Mini3 (three-month bar)
- ProductCard: "AtomPay eligible" badge pinned to the top of the image
- Track (stepper), KeyValue list
- Dialog, BottomSheet
- Skeleton (shimmer)
- `StateView` (icon, title, body, actions, reference)
- OfflineBanner, Toast
- BottomBar (five tabs, with Ask Atom as the raised centre button using the Atomshop app icon) and
  NavigationRail (tablet)

**Adaptive layout:**

| Width | Layout |
|---|---|
| Under 600 dp | Bottom bar, one column |
| 600–839 dp | Navigation rail, two columns |
| 840 dp and up | Rail, two columns, 3–4 product columns, content capped at 1040 |

See the "Home · tablet" board.

## 5. Navigation (canvas board "Navigation rules")

**5.1 Shape.** `StatefulShellRoute.indexedStack` with five tabs: **Home · Shop · Ask Atom ·
Orders · Account**. Each tab keeps its own stack, scroll position and filters. Tab roots have
no back button; every pushed screen does. Ask Atom opens full screen over the current tab with
**Close (×)** and returns to that tab. Settings opens from Account (gear icon and row).

**5.2 Back is the same everywhere.** The app-bar arrow, Android back and the iOS edge swipe all
call `pop()`. Routes never hard-code where back goes.

| Where you are | What back does |
|---|---|
| Shop, Orders or Account root | Home tab |
| Home root | Leaves the app |
| Apply wizard | Previous step, keeping what was typed |
| Dirty form | **"Discard your changes?"** (Keep editing is the default) |
| Request in flight | Blocked |
| Sheet or dialog open | Closes it first |
| Update, Maintenance, First run | `PopScope(canPop: false)` |

Enable Android predictive back (`enableOnBackInvokedCallback`). Never use `WillPopScope`.

**5.3 Guards,** checked in this order on every navigation:

1. version below `min_version` → Update required
2. maintenance (app-config flag, or any 503) → Maintenance
3. no consent → First run
4. no token → Sign in with `?from=`
5. 401/403 anywhere → clear the token, "You've been signed out", Sign in with `from`; never loops
6. limit-only route without a limit → Home

Gates use `go()`, which replaces the stack, so back can't step past them. Sign-out and deletion
also use `go()`.

**5.4 No duplicates.** A control that navigates disables itself until the push completes.
Pushing the route already on top does nothing. Tapping the current tab scrolls to the top, then
pops to that tab's root.

**5.5 Deep links** (`https://atompay.shop/app/...`, plus push taps through the same table).
Each link opens with its parent underneath and passes every guard; when signed out it goes to
Sign in, then continues to the link. Unknown paths go to Home with "That link isn't available".
No token or personal data in any URL.

| Link | Opens |
|---|---|
| `/app` | Home |
| `/app/orders/{id}` | Order detail |
| `/app/orders/{id}/kfs` | Key Fact Statement |
| `/app/apply` | Apply |
| `/app/application` | KYC and verification |
| `/app/notifications` | Notifications |
| `/app/ask` | Ask Atom |
| `/app/account` | Account |

Push `data.screen` maps as `dashboard` → Home, `plan` (+`order_id`) → Order detail,
`profile` → Account.

**5.6 Where you land after an action:**

| Action | Lands on |
|---|---|
| Application sent | KYC and verification; the wizard is removed and back goes Home |
| CNIC or selfie captured | Documents, with that photo ticked |
| Password changed | Settings, with a toast |
| Reset by code | Signed in, at Home |
| Complaint sent | Complaint sent (success); back goes to Help |
| Signed in after a 401 | The `from` route |
| Account deleted | Welcome screen, with the stack cleared |

**Route table** (go_router paths):

| Area | Paths |
|---|---|
| Launch | `/splash` · `/update` · `/maintenance` · `/welcome` |
| Auth | `/login` · `/register` · `/register/verify` · `/forgot` · `/forgot/verify` · `/forgot/reset` |
| Home | `/home` · `/home/notifications` |
| Apply | `/application?step=1..4` · `/application/capture/:doc` · `/application/status` · `/application/history` · `/profile/document/:doc` |
| Shop | `/shop` · `/shop/:productId` · `/calculator` |
| Ask Atom | `/atom` |
| Orders | `/plans` · `/plans/:orderId` · `/plans/:orderId/kfs` |
| Account | `/account` · `/account/settings` · `/account/settings/security` · `/account/settings/permissions` · `/account/settings/notifications` · `/account/settings/password` · `/account/devices` · `/account/delete` · `/account/about` · `/account/ecosystem` · `/account/rate` |
| Help | `/help` · `/help/topic/:topic` · `/help/complaint` · `/help/complaint/sent` |

## 6. Dropdowns: every one searches

Every list choice uses `PickerField`, which opens `PickerSheet` (canvas boards "Picker sheet"
and City, Area, Employment, Income, Topic, Order pickers). The sheet has:

- title and a live count ("4 of 99 cities")
- a focused search field with a clear (×) button; search ignores case and extra spaces and
  matches anywhere in the label
- the current value ticked and announced
- an empty state with "Clear search"
- a sticky **Use {value}** button

Close, back and swipe-down all leave the value unchanged.

| Dropdown | Source |
|---|---|
| City | `GET /cities` |
| Area | `GET /areas?city_id=` (§7.2); disabled with "Choose a city first" until a city is set; changing the city clears the area |
| Employment status, Income source | `GET /options` |
| Complaint topic | `GET /options` → `complaint_topics` (§7.2) |
| Complaint order | `GET /plans`, plus "Not about an order" |

Date of birth is a date picker, not a list.

## 7. API

### 7.1 Live today (contract in `docs/api/`)

- `GET /app-config`, `GET /options`, `GET /calculator`, `POST /estimate`
- `POST /auth/register` · `/register/verify` · `/register/resend` · `/login` · `/logout` ·
  `/logout-all` · `/password/forgot` · `/password/verify` · `/password/reset`
- `GET /auth/sessions` · `DELETE /auth/sessions/{id}`
- `GET /me` · `POST /me/delete` (409 `outstanding_balance`) · `GET|PATCH /me/preferences`
- `GET /dashboard`
- `GET|POST /profile` (multipart) · `GET /profile/documents/{doc}` (never cache)
- `GET|POST /application` (409 `profile_required`, `nothing_changed`) · `GET /application/history`
- `GET /plans` · `GET /plans/{order}`
- `POST|DELETE /devices` · `GET /notifications` · `POST /notifications/{id}/read` · `/read-all`
- `GET /cities`

**Do not use `POST /quote`.** It prices Atomshop's seller financing (advance and markup), not
AtomPay. The calculator uses `GET /plan-preview` (below).

### 7.2 New endpoints: being built now, build against these shapes

All follow `docs/api/conventions.md`: `{ "data": … }`, money as int rupees, the same error
statuses. Until each ships, its repository uses the fake.

```http
GET /app-config                       # added keys (existing keys unchanged)
→ data.maintenance: { "active": false, "message": null, "until": null }   # until: ISO-8601 | null
  data.apps: {
    "atomshop":   { "android": "https://play.google.com/…atomshop", "ios": "https://apps.apple.com/…id6744655747", "web": "https://atomshop.pk" },
    "atompay":    { "android": "…", "ios": "…", "web": "https://atompay.shop" },
    "atomseller": { "android": "…", "ios": "…", "web": "https://atomshop.pk/smart-seller" },
    "atombrand":  { "android": null, "ios": "…", "web": "https://atomshop.pk/brand-partners" } }
  data.features.voice: true            # hide the mic when false
```

```http
GET /areas?city_id=1                  # auth
→ { "data": [ { "id": 12, "title": "Johar Town" }, … ] }        # sorted by title; 422 bad city
```

```http
POST /profile                         # existing; adds the field
  area_id: int (required when the city has areas; must belong to city_id)
GET /profile → data.area: { "id": 12, "title": "Johar Town" } | null
```

```http
GET /plan-preview?price=47000         # public, throttle 60/min
→ { "data": { "price": 47000, "advance": 0, "markup": 0, "months": 3,
     "instalments": [15666, 15666, 15668], "total": 47000,
     "processing_fee_percent": 3, "processing_fee": 1410,
     "fits_limit": true | null } }    # fits_limit only when signed in; null otherwise
```

```http
GET /products?category=tv|phone|…&q=&within_limit=1&page=1     # auth optional
→ { "data": [ { "id": 51, "title": "OXY 3218L Android", "brand": "OXY",
     "category": { "id": 3, "title": "TVs" }, "price": 47000,
     "monthly": 15666, "last_monthly": 15668,
     "image_url": "https://atomshop.pk/public/images/products/…webp" | null,
     "url": "https://atomshop.pk/product/…", "within_limit": true | null } ],
    "meta": { "current_page": 1, "last_page": 3, "total": 52 } }
GET /products/categories → { "data": [ { "id": 3, "title": "TVs", "count": 18 } ] }
GET /products/{id}       → { "data": { …card fields, "description": "…" } }   # 404 if not eligible
```

```http
GET /plans/{order}/kfs                # auth; 404 if not yours
→ { "data": { "order_number": "AS-01279", "product": "OXY 3218L Android",
     "lender": { "name": null, "licence": null, "address": null },   # null until supplied, render as placeholder
     "amount_financed": 47000, "advance": 0, "markup_percent": 0,
     "processing_fee_percent": 3, "processing_fee": 1410, "apr_percent": 18.5,
     "months": 3, "instalments": [ { "number": 1, "due_date": "2026-12-10", "amount": 15666 }, … ],
     "total_repayable": 47000, "late_payment": null, "early_settlement": null,
     "complaints": "In the app: Help › Complaints. Then the SECP.",
     "issued_at": "2026-11-09T10:00:00+05:00" } }
POST /plans/{order}/kfs/send { "channel": "email" | "sms" }  → 202
```

```http
POST /complaints                      # auth, throttle 5/hour
  { "topic": "payment|order|limit|account|other", "order_id": 1043 | null, "message": "10–2000 chars" }
→ 201 { "data": { "id": 7, "reference": "CMP-1042", "status": "open", "created_at": "…" } }
GET /complaints → { "data": [ { "id", "reference", "topic", "order_number", "status": "open|answered|closed", "created_at", "reply": null|"…" } ] }
GET /options → data.complaint_topics: [ { "value": "payment", "label": "A payment" }, … ]
```

```http
GET  /ask-atom/chips                  # auth optional
→ { "data": [ "What does AtomPay cost?", … ] }
POST /ask-atom { "question": "1–300 chars" }      # auth optional; throttle 20/min
→ { "data": { "paragraphs": [ "…", "…" ],
     "table": [ { "label": "Month 1", "value": 15666 } ] | null,
     "actions": [ { "label": "See eligible products", "route": "/shop" } ],
     "chips": [ "…" ] } }
```

Ask Atom is rules-based (no AI, no model). Render `paragraphs` as plain text. `**bold**`
spans may appear: render them bold and nothing else. Action `route`s are app paths from §5.

```http
POST /me/password                     # auth, throttle 5/min
  { "current_password", "password", "password_confirmation" }
→ 204; every OTHER session is signed out.   422 errors.current_password when wrong.
```

**Not supported, so don't build:** data export (Settings says to ask through Help) and editing
email or mobile (done on Atomshop.pk; shown masked).

## 8. States: every data screen has all of them

Each data screen takes `AsyncValue` and renders. The canvas "States" row has every case.

| State | Rule |
|---|---|
| **Loading** | A **skeleton in the screen's own shape** (Home, Orders, Shop, Notifications, Order detail drawn); never a full-screen spinner. `Semantics(label: 'Loading your orders')`, shimmer off under reduced motion. |
| **Error** | `StateView` in the content area; the app bar and tab bar stay. One message per `ApiException` type (examples below). Never show raw server text for 5xx. |
| **Empty** | One sentence and one action: no orders → See eligible products; nothing in a category → Show all; notifications → "You're all caught up". |
| **Offline with cache** | Banner "You're offline. Showing … from 10:42 am", cached data readable, submits disabled. |
| **Success** | A full screen for outcomes with a reference (Complaint sent: reference and Copy); a toast for small confirmations. |
| **Form** | Inline field errors (422), busy buttons, 429 countdown from `Retry-After`, 401 dialog. |

Error messages by type:

| Error | Screen |
|---|---|
| `Offline` | "You're offline" |
| `Server` | "Something went wrong on our side", plus a reference |
| `Timeout` | "This is taking too long" |
| `NotFound` | "We can't find this order" |

Keep the last good data on screen when a refresh fails (show a toast, not the error screen).
Pull to refresh on every list.

## 9. Feature notes

- **Launch:** `GET /app-config`, then `GET /me` when a token exists; apply the guards (§5.3).
  First run (consent) is shown once, before sign-in.
- **Apply:** a four-step wizard (personal, documents, income, review). City and Area pickers;
  CNIC and selfie are **camera only** (no gallery), compressed to 4 MB or less, never written to
  disk after upload, `FLAG_SECURE` on.
- **Home:** three states (no limit, approved, repaying), driven by `/dashboard`. Tablet layout
  on medium widths.
- **Shop:** eligible products from `/products`; the card's "AtomPay eligible" badge is pinned
  to the image top. Product detail shows the 3-month plan from `/plan-preview`; "Buy on
  Atomshop.pk" opens `url` externally.
- **Orders:** list, detail, the late-payment state, the Key Fact Statement (§7.2) with
  Email/SMS a copy and the system share sheet (no saving to the gallery).
- **Ask Atom:**
  - Start screen: "Atom noticed" cards from `/dashboard`, chips from `/ask-atom/chips`.
  - The chat answers come from `/ask-atom`.
  - Thumbs up/down rows keep a 48 dp hit area.
  - **Voice:** a mic button next to Send. The **first tap** shows the explanation sheet
    ("Ask Atom with your voice … we keep the text, never the recording"), *then* the system
    prompt. While listening it shows a waveform, the live transcript, a timer, and Cancel or Done.
    It is English only and stops on a pause. Only the text is sent. If permission is denied, the
    mic opens Permissions.
  - **Listen** reads one answer aloud with `flutter_tts`, and toggles to Stop.
- **Help:**
  - Ask Atom card, topic tiles, common questions and "All questions" all open Help topic
    (expandable answers).
  - Talk to us: WhatsApp, call and email from `app-config.support`; hide any row whose value
    is null.
  - Complaints, then Complaint sent.
- **Account:** profile card, Your AtomPay (KYC, applications, limit review, estimate), Settings,
  Help, Our ecosystem, **Rate AtomPay**, About, and the app logo, name and version
  (`package_info_plus`, "Version 1.0.0 (1)").
- **Settings,** in sections:
  - **Account:** personal details, notifications
  - **Security:**
    - Account security: password, masked email/mobile, devices, and **Sign out everywhere**, which
      uses `/auth/logout-all`, includes this phone and goes to Sign in
    - Change password: discard dialog when dirty
    - Active sessions
  - **Privacy:**
    - Permissions: live status for camera, notifications and microphone, Open phone settings,
      and the "never asked for" list
    - Privacy policy
    - Terms: hidden while `terms_url` is null
  - **Your data:** delete account (409 → the "can't delete yet" screen)
  - **Sign out:** confirmation dialog
  - **Version** at the bottom
- **Ecosystem:** four apps with Google Play, App Store and web links from `app-config.apps`.
  A null link shows "Android soon" / "iOS soon"; AtomPay shows "You are here".
- **Rate AtomPay:** a screen with the app logo, name, version and an honest ask.
  - **Rate on Google Play** (`openStoreListing`; iOS uses `?action=write-review`).
  - **Send us feedback** goes to Help.
  - **No** "Do you like us?" question first, **no** star rating that routes happy users to the
    store, **no** reward: these break both stores' rules.
  - An in-app review prompt (`requestReview`) may appear at most after an on-time payment,
    never after an error.

## 10. Permissions

| Permission | When it's asked |
|---|---|
| Camera | On the first capture, after the CameraPermission explainer |
| Notifications | After the NotifPermission explainer; Android 13+ runtime permission |
| Microphone (+ iOS speech recognition) | First mic tap, after the explainer |

Nothing is asked at launch.

**Never declare:** contacts, `READ_EXTERNAL_STORAGE`, `READ_MEDIA_*`, `WRITE_EXTERNAL_STORAGE`,
location, phone state or numbers, call log, SMS, `QUERY_ALL_PACKAGES`. Google Play's personal
loan policy and SECP forbid them for lending apps, even with consent. CI must fail if the merged
manifest contains any of them.

iOS: write purpose strings for camera, microphone and speech recognition in plain English that
match the explainers.

## 11. Compliance (canvas board "Compliance")

- **Google Play Financial Services:** proof of SECP approval to offer or facilitate lending in
  Pakistan, plus the Personal Loan App Declaration. **Blocked** until the licensed entity is
  named.
- **SECP Circular 15/2022:**
  - corporate name and licence on First run, the KFS and About
  - the Key Fact Statement before disbursement
  - an in-app grievance route (Complaints)
  - data stored in Pakistan
  - no coercive recovery language anywhere (late-payment copy is "Talk to us")
- **Apple 3.2.2(ix):** disclose APR including fees and due dates. APR is **18.5%** if the 3%
  fee is charged, otherwise 0%. Open decision; the KFS shows both as placeholders until it's
  decided.
- **Open: Urdu KFS.** The app is English only by decision; SECP asks for the KFS in Urdu too.
  Do not build Urdu; leave the KFS ready to show a second language if the business decides so.
- **Account deletion:** in-app (Settings) and on the web (`app-config.account_deletion_url`),
  both required by the stores.

## 12. Security and privacy (handbook §6.3, enforced)

- Token in `flutter_secure_storage` only.
- No PII in logs, analytics, crash reports, push payloads or URLs.
- Document images streamed, never cached.
- `FLAG_SECURE` on capture, document and KFS screens.
- Certificate pinning: not required; HTTPS only, cleartext only in the dev flavor.
- Sign-out clears the token, Riverpod state, image cache and any cached API responses.

## 13. Accessibility

- Touch targets at least 48 dp.
- Contrast pairs from the style guide.
- Every icon button has a label.
- Badges and money read out properly ("Rupees 15,666").
- Errors are announced (live region) and focus moves to the first invalid field.
- Text scales to 200% without clipping; test at 1.0, 1.3 and 2.0.
- TalkBack and VoiceOver pass on every screen.
- Reduced motion respected.

## 14. Phases and done criteria

| Phase | Scope | Done when |
|---|---|---|
| 0 | Project, flavors, theme tokens, shared widgets, the `ApiException` mapper, fakes | A widget gallery screen shows every component and state |
| 1 | Shell, router, guards, deep links, launch (config, update, maintenance, first run), auth (sign in, sign up, code, forgot ×3) | Guard and back-behaviour tests pass (§5) |
| 2 | Home (3 states and tablet), notifications, Apply wizard, pickers, capture, status and history | A new customer can apply end to end against dev |
| 3 | Shop, product plan, calculator (`/plan-preview`), Orders, detail, late, KFS | Every money figure matches the API exactly |
| 4 | Ask Atom (text, voice, listen), Help, topics, complaints, success | Voice works with permission granted, denied and permanently denied |
| 5 | Account, Settings, security, sessions, permissions, password, delete, ecosystem, rate us, about | Every Account and Settings row is opened by a test and lands on the right screen |
| 6 | Accessibility pass, golden tests for every canvas board, store assets, release builds | §15 checklist complete |

## 15. Release checklist

- [ ] Golden test for each canvas board (phone, plus the tablet home)
- [ ] Unit tests for every repository (live and fake) and every `ApiException` mapping
- [ ] Widget tests: every screen's loading, error, empty, offline and success states
- [ ] The manifest check passes (§10); iOS purpose strings reviewed
- [ ] No hard-coded colours or font sizes (lint rule)
- [ ] Every canvas placeholder still visible as a placeholder (nothing invented)
- [ ] Store listing: data-safety form matches §10 and §12; privacy URL and account-deletion URL
      set; Financial Services declaration and SECP proof attached
