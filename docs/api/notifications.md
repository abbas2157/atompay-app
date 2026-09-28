# Push devices & notifications

[← API index](README.md) · [Conventions, errors & limits](conventions.md)

Register after every sign-in and every time FCM hands the app a new token
(`FirebaseMessaging.instance.onTokenRefresh`).

## `POST /devices`

```json
{ "fcm_token": "dXk…", "platform": "android", "app_version": "1.0.0" }
```

`platform` is `android` or `ios`. The response is **`201`** for a new device or **`200`** if the token was already
registered:

```json
{ "data": { "id": 7, "platform": "android", "app_version": "1.0.0", "registered_at": "2026-09-24T07:06:09+00:00" } }
```

A device is tied to the sign-in that registered it:

- Signing out (`/auth/logout`, `/auth/logout-all` or `DELETE /auth/sessions/{id}`) removes it automatically.
- If another account signs in on the same phone and registers the same FCM token, the device
  moves to that account.

## `DELETE /devices` → `204 No Content`

```json
{ "fcm_token": "dXk…" }
```

Use this when the customer turns notifications off in the app's settings.

## Push payload

Each push has a `notification` block (title + body, shown by the OS) and a `data` block for
routing. Every `data` value is a **string**:

| Key | Present | Example |
|---|---|---|
| `notification_id` | always | `"57"`. Mark it read with `POST /notifications/57/read` |
| `type` | always | `"instalment_due"` |
| `screen` | always | `"dashboard"` · `"plan"` · `"profile"` |
| `order_id` | `screen = plan` | `"1043"`. Open `/plans/1043` |
| `instalment_id` | `screen = plan` | `"812"` |
| `assessment_id` | `type = limit_decided` | `"311"` |

On Android, create the notification channel **`atompay_default`** at startup.

---

## Notifications inbox

Everything that was pushed is also stored here, including for customers who haven't allowed push.

### Delivery channels

Each notification is delivered three ways, once:

| Channel | When |
|---|---|
| Inbox (`GET /notifications`) | Always |
| Push (FCM) | The server has FCM credentials and the phone registered via `POST /devices` |
| Email | Unless the customer turned alert emails off (`PATCH /me/preferences`, or the email's unsubscribe link) |

### When notifications are created

The server checks every 10 minutes. Each event is announced **once**.

| `type` | When | Title example |
|---|---|---|
| `application_received` | An income application was submitted (app or website) and isn't decided yet | "We've received your application" |
| `limit_decided` | Staff approve, conditionally approve or reject an application (in AtomPay or AtomShop admin) | "Your AtomPay limit is approved" |
| `kyc_verified` | The address visit is recorded as verified | "Your address is verified" |
| `kyc_rejected` | Verification failed (body = reviewer's note if any) | "We could not verify your details" |
| `instalment_due` | 3 days before and on the due date | "Instalment due in 3 days" / "Instalment due today" |
| `instalment_overdue` | 1 and 7 days after the due date, if still unpaid | "Instalment overdue" |

Reminders are only sent between 09:00 and 21:00 Pakistan time.

### `GET /notifications?page=1`

Returns 20 notifications per page, newest first. This uses Laravel's pagination format, and `meta.unread_count` is added.

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

`payload` has the same keys as the push `data` block. Here the ids are numbers, but in a push
they are strings.

### `POST /notifications/{id}/read`

Returns the updated notification. Returns `404` if it isn't the customer's.

### `POST /notifications/read-all` → `204 No Content`
