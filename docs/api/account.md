# Account

[← API index](README.md) · [Conventions, errors & limits](conventions.md)

## `GET /me`

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

`phone` / `phone_formatted` can be `null` on older AtomShop accounts.

`kyc_status` is one of:

| Value | Meaning | Suggested UI |
|---|---|---|
| `not_started` | No profile submitted yet | "Complete your profile" call to action |
| `pending` | Submitted; waiting for the address visit and review | "Under review" badge |
| `verified` | Address verified by AtomPay staff | Green tick |
| `rejected` | Verification failed | "Contact support" + let the customer resubmit |

The account's name, email and phone belong to AtomShop and are **read-only** in v1. The
password can be changed only through [forgot password](auth.md#forgot-password-otp).

`uuid` is deliberately **not** returned. AtomShop's own `/password/reset/{uuid}` page resets
a password with nothing but the uuid, so it must never reach the app.

## `POST /me/delete`

Deletes the signed-in customer's account, here **and** on AtomShop.pk. Both stores require this to be possible inside the app.

```json
{ "password": "the-current-password" }
```

| Status | Body | When |
|---|---|---|
| `204` | – | Deleted. Clear the stored token and go to sign-in. |
| `422` | `{"message": "...", "errors": {"password": ["That password isn't right."]}}` | Missing or wrong password (checked exactly as `POST /auth/login` checks it). |
| `409` | `{"message": "You still have instalments to pay. You can delete your account once every plan is repaid.", "code": "outstanding_balance"}` | An order in `Processing`, `Delivered` or `Instalments` still has unpaid instalments, or an order is waiting for approval (its message then says so). Show `message` as-is. |
| `429` | `Too Many Attempts.` + `Retry-After` | More than 5 tries a minute on this account. |

On `204` the server has:

- revoked every AtomPay token and push registration, and AtomShop's own app tokens, web sessions and push tokens;
- deleted the identity profile and the CNIC/selfie files, the inbox, preferences, and reset/sign-up records. Income answers
  are deleted too if the customer never placed an order;
- blocked the AtomShop account and overwritten its name, email, mobile, password and customer details, so the
  same email and number can register again;
- kept orders, instalment schedules, payments and the credit decision behind any order (without the employer name),
  attached only to the anonymised account;
- emailed a confirmation to the account's real email address, if it had one.

## `GET /me/preferences`

```json
{ "data": { "email_alerts": true } }
```

## `PATCH /me/preferences`

```json
{ "email_alerts": false }
```

The response has the same shape as `GET`. `email_alerts` switches off the **alert emails**
(limit decided, KYC outcome, instalment reminders, application received). The in-app inbox and
push are unaffected. Security emails (reset codes, "password changed") and the welcome email
are always sent. The same switch is behind the unsubscribe link in every alert email.
