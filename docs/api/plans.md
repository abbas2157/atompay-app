# Plans

[← API index](README.md) · [Conventions, errors & limits](conventions.md)

The customer's AtomShop orders, in every status, with their instalment plans.

## `GET /plans`

Returns **every** order the customer has placed, newest first, whatever its status: waiting for
approval, being repaid, repaid or cancelled. Group or filter them in the app by `state` (for example
an "Active" tab and a "History" tab). AtomPay-financed orders are included. `?include=completed` is
no longer needed and is ignored.

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
      "next_due": { "...": "instalment object, or null" }
    }
  ]
}
```

- `state` is one of:

  | `state` | Meaning | Suggested pill |
  |---|---|---|
  | `pending` | Waiting for AtomShop's approval (`order.status` `Pending` or `Varification`). No schedule yet. | amber, "Awaiting approval" / "In verification" |
  | `processing` | Approved (`Processing` or `Delivered`) but the schedule isn't set yet. | amber, `order.status_label` |
  | `on_track` | Being repaid, nothing overdue | green |
  | `late` | Being repaid, an instalment is overdue | coral |
  | `completed` | Fully repaid | green |
  | `cancelled` | Cancelled. Never `late`, even if unpaid rows remain | grey |

- When `progress.total_count` is `0` (`pending`, `processing`, usually `cancelled`), there is no
  schedule to show yet. Show `order.total_price`, `order.advance`, `order.financed` and `order.tenure`
  instead, with a line about what happens next.
- `order.status_label` is the display form of `order.status` (`Varification` is shown as "Verification").
- `product` can be `null` if the AtomShop product was removed.
- `product.picture_url` is public (served by AtomShop), so no auth header is needed.

## `GET /plans/{order_id}`

Returns the same object plus the full schedule. It returns `404` if the order isn't the customer's.

```json
{
  "data": {
    "order": { "...": "..." }, "product": { "...": "..." }, "state": "late", "progress": { "...": "..." },
    "next_due": { "...": "..." },
    "instalments": [
      { "id": 811, "order_id": 1043, "label": "Instalment 1", "due_date": "2026-08-05",
        "amount": 19334, "paid_amount": 19334, "paid_on": "2026-08-04", "state": "paid" },
      { "id": 812, "order_id": 1043, "label": "Instalment 2", "due_date": "2026-09-05",
        "amount": 19334, "paid_amount": null, "paid_on": null, "state": "late" }
    ]
  }
}
```

`label` is AtomShop's own text (e.g. "1st Instalment"), so display it as it is.

Instalment `state` and colour:

| State | Meaning | Colour |
|---|---|---|
| `paid` | Paid | green |
| `late` | Past its due date and unpaid | coral |
| `due` | Due within 14 days | amber |
| `upcoming` | Due later | muted |

Payments are made through AtomShop's existing channels. The app only shows status.
