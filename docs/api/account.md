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
