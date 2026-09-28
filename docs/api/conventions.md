# Conventions, errors & limits

[← API index](README.md) · [Conventions, errors & limits](conventions.md)

| | |
|---|---|
| Production base URL | `https://atompay.shop/api/v1` |
| Local (XAMPP) | `http://localhost/atompay/api/v1` |
| Local from Android emulator | `http://10.0.2.2/atompay/api/v1` |
| Local from a real phone | `http://<your-PC-LAN-IP>/atompay/api/v1` |
| Auth | `Authorization: Bearer <token>` (Laravel Sanctum) |
| Content type | JSON, except `POST /profile`, which is `multipart/form-data` |

Always send:

```
Accept: application/json
Authorization: Bearer <token>        # every endpoint marked "Auth ✓" in the index
```

## Conventions

- **Envelope.** Successful bodies are `{ "data": ... }`. Lists are `{ "data": [ ... ] }`.
- **Money** is a whole number of Pakistani rupees (`int`), never a float or a formatted string.
  The app formats it as `PKR 123,456`.
- **Dates** are `YYYY-MM-DD`. **Timestamps** are ISO-8601 with an offset (`2026-10-24T06:47:14+00:00`).
- **CNIC** is stored and returned as 13 bare digits (`4210176543219`). A `cnic_formatted`
  sibling gives `42101-7654321-9` for display. You can send it with or without dashes.
- **Mobile** is stored and returned as `03XXXXXXXXX`, with a `mobile_formatted` / `phone_formatted`
  sibling (`0300 1234567`). You can send any common form: `0300 1234567`, `+92 300 1234567`,
  `923001234567` or `3001234567`.
- **Nullable fields are always present.** A missing value is `null`, never an absent key,
  unless the table says otherwise.
- **The server does all business math.** Limits, instalment caps, risk and plan pricing are
  computed server-side. The app never computes a number it then submits.

## Errors

Every error is JSON, even if you forget `Accept`.

| Status | When | Body | What the app does |
|---|---|---|---|
| `401` | No token, bad token, expired token, revoked token | `{"message": "Unauthenticated."}` | Delete the stored token and go to the sign-in screen. |
| `403` | Account is not an active customer (staff, seller, blocked). On a protected route **the token has already been revoked.** | `{"message": "Please sign in with an AtomShop customer account."}` | Show the message, delete the token, go to sign-in. |
| `404` | Unknown route, or a record that isn't yours (plans, sessions and notifications all look the same) | `{"message": "..."}` | |
| `409` | Allowed input, but not in the customer's current state | `{"message": "...", "code": "profile_required"}` | Switch on `code` (table below), then show `message`. |
| `422` | Validation failed | `{"message": "...", "errors": {"field": ["msg", ...]}}` | Show `errors[field][0]` under each field. `message` is a summary. |
| `429` | Rate limited | `{"message": "Too Many Attempts."}` + `Retry-After: <seconds>` header | Disable the button and show a countdown from `Retry-After`. |
| `5xx` | Server fault | `{"message": "Server Error"}` | Generic retry UI. Do not show raw text. |

`409` codes:

| `code` | Returned by | Meaning / app action |
|---|---|---|
| `profile_required` | `POST /application` | No identity profile has been submitted yet. Send the customer to the profile form first. |

## Rate limits

| Endpoint | Limit | Keyed by |
|---|---|---|
| `POST /auth/login` | 5/min, and 20/min | identifier + IP, and IP |
| `POST /auth/register` | 5/hour | IP (plus 3 codes/hour per mobile number or email) |
| `POST /auth/register/verify` | 10/min | IP (5 tries per sign-up) |
| `POST /auth/register/resend` | 3/min, and 10/min | IP (60 s cooldown) |
| `POST /profile`, `POST /application` | 10/min | account |
| `GET /profile/documents/*` | 60/min | account |
| `POST /quote` | 60/min | IP |
| `POST /estimate` | 10/min and 40/hour | IP |
| `/app-config`, `/options`, `/calculator` | 600/min | IP |
| `POST /auth/password/forgot` | 3/min, and 10/min | identifier + IP, and IP (plus 5 codes/hour per account) |
| `POST /auth/password/verify`, `/reset` | 10/min | IP |
| Every signed-in endpoint | 120/min | account |

---

## Token lifecycle

1. `register/verify` (sign-up), `login` or `password/reset` returns a token that is valid for **30 days** (`expires_at`).
2. Store it in **secure storage** (`flutter_secure_storage`). Never store it in shared
   preferences, and never log it.
3. On app launch, call `GET /me`. A `200` means you're signed in and the user object is fresh.
   A `401` means go to sign-in.
4. There is no refresh token. When the token expires, the user signs in again.
5. `POST /auth/logout` revokes this device's token. `POST /auth/logout-all` revokes every
   device's token, for example after a lost phone.

Tokens look like `20|atompay_Xu97xvn4…`. Treat the whole string as opaque.

> AtomShop app tokens do **not** work here, and AtomPay tokens do not work on AtomShop.
> The account and password are the same, but the tokens are separate.
