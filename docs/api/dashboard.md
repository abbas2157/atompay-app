# Dashboard

[← API index](README.md) · [Conventions, errors & limits](conventions.md)

## `GET /dashboard`

The whole home screen in one call. Refresh it on pull-to-refresh and when the app resumes.

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
    "plans": { "active_count": 1, "pending_count": 0, "has_late": false },
    "unread_notifications": 2
  }
}
```

| Field | Notes |
|---|---|
| `application_status` | `null` (never applied) · `pending` · `approved` · `conditional` · `rejected`. This is the **latest** application, which may be a pending re-application while an older limit is still in force. |
| `banner.tone` | `pending` (amber) · `blocked` (coral) · `done` (green). |
| `banner.action` | Where the button goes. `apply` means start with the profile, then the application. `profile` opens the profile form. `application` opens the income form. The `text` may be the reviewer's own note. |
| `limit` | The limit **in force**. When `has_limit` is `false`, show "Not set yet": the money fields are `0`, and `status` and `tenure` are `null`. `status` is `approved` or `conditional`. |
| `limit.used` | Unpaid AtomShop instalments. `available = max(0, approved − used)`. |
| `stages[].state` | `done` · `current` · `upcoming` · `blocked`. There are always six stages in this order. |
| `next_due` | The earliest unpaid monthly instalment across all orders, or `null`. `state` is `paid`, `late`, `due` (within 14 days) or `upcoming`. |
