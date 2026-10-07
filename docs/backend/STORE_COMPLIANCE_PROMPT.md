# Prompt for the AtomPay server (Laravel): store-compliance changes

> Paste everything below the line into the backend agent / hand it to the backend developer.
> The mobile app (v1.0.0) is already built against this contract and is waiting on it for the
> Google Play and App Store submissions.

---

You are working on the AtomPay Laravel API (`https://atompay.shop/api/v1`, Sanctum bearer tokens,
customer accounts shared with AtomShop.pk's MySQL database). The mobile app is going to Google Play
and the Apple App Store. Both stores **reject** apps that let users create an account but give them no
way to delete it inside the app, and both need a public privacy-policy page. Implement the four items
below, add feature tests for each, and update the API docs (`docs/api/account.md`,
`docs/api/app-config.md`, `docs/api/README.md` endpoint index, `docs/api/conventions.md` rate limits).

Follow the existing conventions: `{ "data": … }` envelope, `422` with `errors.<field>`, `409` with a
machine `code`, `429` with `Retry-After`, customer-facing messages written in plain English.

## 1. `POST /me/delete` (auth required): delete the signed-in customer's account

Request:

```json
{ "password": "the-current-password" }
```

Responses:

| Status | Body | When |
|---|---|---|
| `204 No Content` | – | Account deleted. |
| `422` | `{"message": "...", "errors": {"password": ["That password isn't right."]}}` | Missing or wrong password. Check it with exactly the same hash check `POST /auth/login` uses. |
| `409` | `{"message": "You still have instalments to pay. You can delete your account once every plan is repaid.", "code": "outstanding_balance"}` | The customer has any order in `Processing`, `Delivered` or `Instalments` with an unpaid balance, or an order awaiting approval. |
| `401` / `403` | as today | Token invalid / not an active customer. |
| `429` | `Too Many Attempts.` + `Retry-After` | Throttle **5/min per account** (it's a password check). |

On `204`, inside one DB transaction:

1. **Revoke every Sanctum token** for the user (all devices) and delete all push-device registrations.
2. **Delete personal data** the business has no legal duty to keep: KYC profile fields, CNIC front/back
   images and the selfie (delete the files from private storage, not only the DB rows), employer/income
   answers on applications that never became an order, notification inbox, preferences, sessions.
3. **The shared AtomShop customer account**: the app tells users that sign-up "also creates your
   AtomShop.pk account", and the delete screen says the AtomShop.pk account is deleted too. Deactivate it
   so it can't sign in on the website either, and anonymise its PII (name → "Deleted user", email/phone →
   unique non-routable placeholders such as `deleted+<id>@invalid`, hashed password → random) so the same
   email/phone can register again later.
4. **Keep** what financial / anti-money-laundering regulation requires (orders, instalment schedules,
   payments, the assessment decision), but detach it from the anonymised identity wherever the schema
   allows. Document the retention period in the privacy policy (item 3).
5. Write an audit log row (user id, timestamp, IP, "self-service deletion") without the PII.
6. Send a "Your AtomPay account has been deleted" email/WhatsApp to the original contact **before** it
   is anonymised (queue the job with the address captured up front).

The app clears its local token on `204` and returns to sign-in. It shows the `409` message as-is, so keep
it customer-friendly.

## 2. `GET /app-config`: add three fields

```json
{
  "data": {
    "...": "existing fields unchanged",
    "privacy_url": "https://atompay.shop/privacy-policy",
    "terms_url": "https://atompay.shop/terms",
    "account_deletion_url": "https://atompay.shop/account/delete"
  }
}
```

- `privacy_url` must always be set (the app falls back to `https://atompay.shop/privacy-policy`).
- `terms_url` may be `null`; the app hides the link then.
- `account_deletion_url` is for the Play Console (see item 4). The app doesn't use it yet but reads the
  config defensively, so adding it is safe.

Make them config/env driven (`ATOMPAY_PRIVACY_URL`, `ATOMPAY_TERMS_URL`, `ATOMPAY_ACCOUNT_DELETION_URL`).

## 3. Public web page: `https://atompay.shop/privacy-policy`

Publicly reachable without login, HTTPS, no geo-blocking (Apple and Google reviewers are outside
Pakistan). It must name **AtomPay / the legal entity** and cover, at minimum:

- What is collected: name, email and/or mobile number, CNIC number, CNIC images, selfie, address/city,
  employment and income, purchase-limit assessment, AtomShop orders and instalment payments, device name
  (for the signed-in devices list), app language/theme settings.
- Why (identity verification, credit assessment, managing instalment plans, notifications, fraud
  prevention, legal compliance), and the legal basis.
- Who it's shared with (AtomShop.pk, email/WhatsApp providers, any credit bureau, regulators on request).
  State plainly that data is **not sold** and **not used for advertising or tracking**.
- Security (encryption in transit, private document storage, staff access controls).
- Retention: how long each category is kept, and what is kept after account deletion and for how long.
- **How to delete the account**: in the app (Account → Delete account) **and** via the web page in item 4.
- Contact for privacy requests (email address), and the date of the last update.

Also publish `https://atompay.shop/terms` if terms exist.

## 4. Public web page: `https://atompay.shop/account/delete`

Google Play requires a **web** link where someone can request deletion **without installing the app**.
The page must name AtomPay, list the steps, say what is deleted and what is kept (same rules as item 1),
and let the user start it: sign in on the website, then confirm with the password and the same
`outstanding_balance` refusal, reusing the item 1 service class. A simple request form that sends a
one-time code to the account's email/WhatsApp and then deletes is also fine.

## 5. Blocking bug: login fails after a password reset

Reported on Android and on the website: after `POST /auth/password/reset` succeeds (the response signs
the device in with a token, so no password check happens there), the **next** `POST /auth/login` with the
new password returns `422 "Those details do not match an AtomShop account."`. The app sends exactly
`{ login: trim(input), password: <as typed> }` every time.

Likely causes to check:
- Double hashing: `Hash::make($password)` assigned to a model that also has a `'password' => 'hashed'`
  cast (or a `setPasswordAttribute` mutator), so the stored hash is a hash of a hash.
- The reset writes the password to one table (AtomPay or AtomShop `users`) while login checks the other.

Add a feature test: forgot → verify → reset → logout → login with the new password → `200`, and the same
password also works on the AtomShop website login. This must be fixed before submission: store reviewers
sign in with a demo account, and the 5/min login throttle locks them out after a few failed tries.

## 6. Reviewer demo account

Create a customer account for the store reviewers (email login, a known password), with an approved
purchase limit and at least one instalment plan in `Instalments` state with a mix of paid and upcoming
instalments, so every screen has content. Give it **no** outstanding balance on the plan used for the
review notes if you want reviewers to be able to test deletion, or create a **second** demo account with
no plans for that purpose: App Review often tests the delete flow, and the item 1 `409` must not look
like a broken feature. Don't block deletion with a `403` (the app treats `403` on a signed-in call as
"session ended"). Instead add an artisan command (`php artisan atompay:seed-review-accounts`) that
re-creates both accounts with the same credentials, so they can be restored after a review.
