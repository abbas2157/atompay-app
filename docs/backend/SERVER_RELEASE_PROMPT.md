# Prompt for the AtomPay server (Laravel): work needed before the store release

> Paste everything below the line into the backend agent, or hand it to the backend developer.
> It replaces `STORE_COMPLIANCE_PROMPT.md` (same items, plus the new fields in item 6). The mobile
> app is already built against every contract here and is waiting on it for the Google Play and App
> Store submissions.

---

You are working on the AtomPay Laravel API (`https://atompay.shop/api/v1`, Sanctum bearer tokens,
customer accounts shared with AtomShop.pk's MySQL database). The mobile app is going to Google Play and
the Apple App Store. Items 1–4, 7 and 8 are **blockers**: the stores reject the app without them. Item 5
switches on push. Item 6 adds optional fields the app already displays when present.

Follow the existing conventions:

- the `{ "data": … }` envelope;
- `422` with `errors.<field>`;
- `409` with a machine-readable `code`;
- `429` with `Retry-After`;
- customer-facing messages in plain English, because the app shows `message` as-is.

For every item, add feature tests and update the API docs (`docs/api/*.md`, plus the endpoint index in
`docs/api/README.md` and rate limits in `docs/api/conventions.md`).

## 1. Account deletion: `POST /me/delete` (auth required)

Both stores require in-app account deletion. The app's **Account → Delete account** screen calls this.

Request:

```json
{ "password": "the-current-password" }
```

| Status | Body | When |
|---|---|---|
| `204 No Content` | none | Account deleted. |
| `422` | `{"message": "…", "errors": {"password": ["That password isn't right."]}}` | Missing or wrong password. Check it with exactly the same hash check `POST /auth/login` uses. |
| `409` | `{"message": "You still have instalments to pay. You can delete your account once every plan is repaid.", "code": "outstanding_balance"}` | Any order in `Processing`, `Delivered` or `Instalments` has unpaid instalments, or an order is awaiting approval (then say so in `message`). |
| `401` / `403` | as today | Token invalid, or not an active customer. |
| `429` | `Too Many Attempts.` + `Retry-After` | Throttle **5/min per account**, because it checks a password. |

On `204`, inside one DB transaction:

1. **Revoke** every AtomPay Sanctum token and push-device registration (`devices` rows). Also revoke
   AtomShop's own app tokens, web sessions and push tokens for the same customer.
2. **Delete** personal data with no legal duty to keep:
   - the KYC profile, plus the CNIC front/back and selfie **files** in private storage (not only the DB
     rows);
   - the notification inbox, preferences, and reset/sign-up OTP records;
   - employer and income answers on applications that never became an order.
3. **Anonymise the shared AtomShop customer**:
   - Block it, so it can't sign in on the website.
   - Overwrite the PII: name → `Deleted user`; email and phone → unique non-routable placeholders such
     as `deleted+<id>@invalid`; password → a random hash.
   - Doing it this way lets the same email or number register again later.
4. **Keep** what financial and anti-money-laundering rules require: orders, instalment schedules,
   payments, and the credit decision behind any order (without the employer name). Keep them attached
   only to the anonymised account.
5. Write an audit log row (user id, timestamp, IP, `self-service deletion`) containing no PII.
6. Queue a "Your AtomPay account has been deleted" email to the original address. **Capture that
   address before anonymising.**

Put the logic in one service class; item 3's web page reuses it.

## 2. Login fails after a password reset (bug)

This is reported on Android and on the website:

1. `POST /auth/password/reset` succeeds. Its response signs the device in, so no password check
   happens at that point.
2. The **next** `POST /auth/login` with the new password returns `422 "Those details do not match an
   AtomShop account."`

The app sends `{ "login": trim(input), "password": <exactly as typed> }` every time.

Check these first:

- **Double hashing.** `Hash::make($password)` is assigned to a model that also has a
  `'password' => 'hashed'` cast (or a `setPasswordAttribute` mutator), so the stored value is a hash of
  a hash.
- **Two tables.** The reset writes the AtomPay `users` table while login checks AtomShop's (or the
  reverse).

Add a feature test that runs forgot → verify → reset → logout → login with the new password and expects
`200`. The same password must also work on the AtomShop website login.

Store reviewers sign in with a demo account, and the 5/min login throttle locks them out after a few
failed tries, so this must be fixed before submission.

## 3. Public web pages

All three must be HTTPS, reachable without signing in, and **not geo-blocked**: Apple and Google
reviewers are outside Pakistan.

### `https://atompay.shop/privacy-policy`

It must name AtomPay and Atomshop's registered company (the seller; there is no separate lender), and
cover:

- **What is collected:**
  - name, email and/or mobile number;
  - CNIC number, CNIC images and the selfie;
  - address, city and area;
  - employment and income, and the purchase-limit assessment;
  - AtomShop orders and instalment payments;
  - device name (shown in the signed-in devices list) and the push notification token;
  - text typed or spoken to Ask Atom (the app sends the text, never the recording).
- **Why it is used:** identity verification, credit assessment, managing instalment plans,
  notifications, fraud prevention and legal compliance, with the legal basis for each.
- **Who it is shared with:** AtomShop.pk, the email/WhatsApp and push providers, any credit bureau, and
  regulators on request. Say plainly that data is **not sold** and **not used for advertising or
  tracking**.
- **Security:** encryption in transit, private document storage, staff access controls.
- **Where data is stored:** the server location. The app currently shows "Your data is stored in
  Pakistan [CONFIRM HOSTING]", so confirm or correct it.
- **Retention:** how long each category is kept, including what remains after account deletion and for
  how long.
- **How to delete the account:** in the app (Account → Settings → Delete account) **and** on the web
  (`/delete-account`).
- **Contact and date:** a contact email for privacy requests, and the date of the last update.

### `https://atompay.shop/delete-account`

Google Play requires a **web** link where someone can request deletion **without installing the app**.

- The page names AtomPay, lists the steps, and says what is deleted and what is kept (same rules as
  item 1).
- The user can start it right there, using either of these:
  - sign in, confirm with the password, and get the same `outstanding_balance` refusal (reuse item 1's
    service class);
  - a request form that sends a one-time code to the account's email or WhatsApp, then deletes.

### `https://atompay.shop/terms` (if terms exist)

### `GET /app-config`

Make the URLs config/env driven (`ATOMPAY_PRIVACY_URL`, `ATOMPAY_TERMS_URL`,
`ATOMPAY_ACCOUNT_DELETION_URL`) and return them:

```json
{
  "data": {
    "…": "existing fields unchanged",
    "privacy_url": "https://atompay.shop/privacy-policy",
    "terms_url": "https://atompay.shop/terms",
    "account_deletion_url": "https://atompay.shop/delete-account"
  }
}
```

- `privacy_url` must always be set.
- `terms_url` may be `null`; the app then hides the Terms row and link.
- `account_deletion_url` must be exactly the URL entered in the Play Console's data-deletion field. The
  app shows it on the delete screen as "Can't sign in? Delete on the web".

## 4. Reviewer demo accounts

Add an artisan command, `php artisan atompay:seed-review-accounts`, that (re)creates two customer
accounts with fixed credentials. It must be safe to run again after a review has changed them.

| Account | Login | State |
|---|---|---|
| **Review A** (full) | email + known password | KYC `verified`; approved purchase limit; at least one order in `Instalments` with a mix of paid, due and upcoming instalments; a few inbox notifications. Every screen has content. |
| **Review B** (empty) | email + known password | Verified, approved limit, **no** orders, so **deleting it succeeds**. App Review often tests deletion, and a `409` on the only demo account looks like a broken feature. |

- Don't block deletion of either account with a `403`. The app treats `403` on a signed-in call as
  "session ended".
- Put both sets of credentials in the release notes for the app reviewers, not in the repository.

## 5. Push notifications (switching on what exists)

`POST /devices` / `DELETE /devices` and the push payloads already exist
(`docs/api/notifications.md`). The app's push client is now built. It needs:

- **Firebase:** the server's FCM service-account credentials must belong to the **same Firebase
  project** the AtomPay app will be registered in. Atomshop and Atom Seller use `atomshop-a726c`.
- **Config:** with those credentials set, `/app-config` returns `features.push: true`. While it is
  `false`, the app never asks for notification permission.
- **Payload rule:** every push carries a `data.screen` (`dashboard`, `plan` with `order_id`, or
  `profile`), with ids as **strings**. The app routes taps through that.

## 6. New fields the app already shows (optional, not blocking)

Each field is **nullable**. When it is missing or `null` the app leaves the line out, so they can ship
one at a time. The app **never computes money itself**, so the figures must come from the server.

### 6a. `GET /dashboard` → `limit.available_after_next` (integer rupees or `null`)

What `limit.available` becomes once `next_due` is paid in full:

```
min(limit.approved, limit.available + (next_due.amount − (next_due.paid_amount ?? 0)))
```

It is `null` when there is no limit or no `next_due`.

- **Home** shows "Your limit frees up as you pay. After 10 Jan you will have **Rs. 44,332** to spend."
- **Ask Atom** shows "Rs. 44,332 once January is paid".

### 6b. `GET /dashboard` → `lowest_eligible_price` (integer rupees or `null`)

The price of the cheapest product that `GET /products` would list as AtomPay-eligible, using the same
eligibility filter. It is `null` when the customer has no limit.

Home's empty "Nothing fits Rs. 28,666 right now" card shows "The lowest-priced eligible product is
Rs. 47,000."

### 6c. `order.delivered_at` (ISO 8601 or `null`) on `GET /plans` and `GET /plans/{order_id}`

- **Value:** when AtomShop marked the order **Delivered**, taken from the order status history.
- **Must stay set:** once the order moves on to `Instalments` or `completed`.
- **`null`:** before delivery and for cancelled orders.

Shown as "AS-01279 · delivered 9 Nov" on the order card and "Placed — Approved — Delivered 9 Nov —
Repaying" on the order detail screen.

### 6d. `paid_via` (string or `null`) on every instalment object

That means `GET /plans/{order_id}` → `instalments[]`, and the `next_due` object in `/plans` and
`/dashboard`.

- **Value:** a display label for how a paid instalment was paid: `"JazzCash"`, `"EasyPaisa"`,
  `"Bank transfer"`, `"Cash"` or `"Card"`.
- **`null`:** while unpaid, or when the method isn't recorded.

Shown as "Due 10 Dec 2026 · paid 9 Dec by JazzCash".

Example (`GET /plans/1279`, trimmed):

```json
{
  "data": {
    "order": {
      "id": 1279,
      "reference": "AS-01279",
      "status": "Instalments",
      "ordered_at": "2026-09-19T10:12:00+05:00",
      "delivered_at": "2026-09-21T15:40:00+05:00"
    },
    "instalments": [
      { "id": 12790, "label": "1st Instalment", "due_date": "2026-10-20", "amount": 15666,
        "paid_amount": 15666, "paid_on": "2026-10-19", "paid_via": "JazzCash", "state": "paid" },
      { "id": 12791, "label": "2nd Instalment", "due_date": "2026-11-19", "amount": 15666,
        "paid_amount": null, "paid_on": null, "paid_via": null, "state": "due" }
    ]
  }
}
```

Document 6a and 6b in `docs/api/dashboard.md` and 6c and 6d in `docs/api/plans.md`. The app repo's
copies already list them as "Proposed, not live yet"; mark them live when shipped.

## 7. Company details, set in the Atomshop admin panel (blocker)

**Atomshop sells on instalments itself.** There is no bank or lender, and AtomPay is **not registered
with the SECP**. Nothing the server returns may claim an SECP licence, and the app no longer shows one.

The app shows the company's details in several places:

- the disclosures screen before sign-in ("Who offers your instalments");
- About;
- the Key Fact Statement ("Sold by");
- the late-payment card;
- the complaint screens.

The app must not hard-code them. Today each one shows a red placeholder such as `[COMPANY NAME]`.

Add an **AtomPay settings** page in the **Atomshop admin panel** where an admin enters:

| Setting (key) | Example | Shown in the app as |
|---|---|---|
| `company_name` | `Atomshop (Pvt) Ltd` | "Who offers your instalments" / KFS "Sold by" |
| `registered_address` | `Office 4, … Lahore` | About → Address |
| `data_hosting` | `Pakistan` | "Your data is stored in Pakistan" |
| `late_payment` | `Rs. 500 per missed month, no interest` | Late card and KFS → Late payment |
| `early_settlement` | `Pay off any time, no extra charge` | KFS → Paying early |
| `complaint_response_time` | `2 working days` | "We reply within 2 working days" |

Serve them in `GET /app-config` as a `business` object, with every key present and `null` while unset:

```json
{
  "data": {
    "…": "existing fields unchanged",
    "business": {
      "company_name": "Atomshop (Pvt) Ltd",
      "registered_address": "Office 4, Main Boulevard, Lahore",
      "data_hosting": "Pakistan",
      "late_payment": "Rs. 500 per missed month, no interest",
      "early_settlement": "Pay off any time, no extra charge",
      "complaint_response_time": "2 working days"
    }
  }
}
```

- **One source:** `GET /plans/{order_id}/kfs` must take `lender.name` (the company name),
  `lender.address`, `late_payment` and `early_settlement` from the same settings, so the two never
  disagree.
- **No licence:** leave `lender.licence` `null`. The app no longer shows it.
- **Complaints text:** the KFS `complaints` text must not mention the SECP. Use something like "In the
  app: Help › Complaints."
- **Caching:** cache `/app-config` as today, and clear the cache when the settings are saved.
- **Audit:** these values are customer-facing terms, so log who changed what and when.

The app is already built to read all of this. It shows each value in normal text, and the red
placeholder only while a value is `null`.

## 8. Key Fact Statement accepted at Atomshop checkout (blocker)

AtomPay customers buy on credit from Atomshop, and the terms include a processing fee and an APR.
Apple guideline 3.2.2(ix) and Google Play's financial-features policy expect every term to be shown up
front, and Pakistani consumer-protection law expects the buyer to agree to them before buying. The
agreement happens when the customer chooses AtomPay at **Atomshop.pk checkout**, so it belongs there,
on the website, not in the app.

When AtomPay is the payment method at checkout:

1. **Before** the order can be placed, show the Key Fact Statement for this order, built from the same
   data as `GET /plans/{order_id}/kfs`:
   - "Sold by" with the company name;
   - the amount (the cash price);
   - advance Rs. 0 and markup 0%;
   - the processing fee and its amount;
   - the APR;
   - 3 monthly instalments with their dates and amounts, the last one taking the rounding;
   - the total payable;
   - late-payment and early-settlement terms;
   - how to complain.
2. Require an explicit checkbox, unticked by default: "I have read the Key Fact Statement and agree to
   these terms". The **Place order** button stays disabled until it is ticked.
3. Store the acceptance with the order:
   - timestamp, IP and user agent;
   - the KFS **version**, or a snapshot of the exact figures shown;
   - the customer id.

   Orders without an acceptance must not be created as AtomPay orders.
4. Email (or WhatsApp) the customer a copy of the accepted KFS. The app's "Email or SMS me a copy"
   already calls `POST /plans/{order_id}/kfs/send`.
5. Add `accepted_at` (ISO 8601, `null` if not accepted) to `GET /plans/{order_id}/kfs`. The app
   then replaces the note "These terms must be shown and accepted at Atomshop checkout before the
   order is approved **[not built yet]**" with "You accepted these terms at Atomshop checkout on
   19 Sep 2026".

## Done means

- [ ] Items 1–4 are live on `https://atompay.shop`, with feature tests passing.
- [ ] Review A and Review B exist, and their credentials are sent to the app team privately.
- [ ] The privacy-policy and delete-account URLs open on a phone outside Pakistan without signing in.
- [ ] The forgot → reset → login test passes against production data (one real test account).
- [ ] Item 5: FCM credentials are set and `features.push` is `true`, or the team has decided to launch
      without push.
- [ ] Item 6: the fields that are ready are shipped and documented.
- [ ] Item 7: an admin has entered every company detail, `/app-config.business` returns no `null`s, and
      no response mentions an SECP licence.
- [ ] Item 8: checkout shows the KFS, requires acceptance, and stores it with the order.
