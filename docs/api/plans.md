# Plans

[← API index](README.md) · [Conventions, errors & limits](conventions.md)

The customer's AtomShop orders that are paid in instalments.

## `GET /plans`

Returns orders that still have repayments running (`Processing`, `Delivered`, `Instalments`). Add
`?include=completed` to also list fully repaid orders, which is useful for a "History" tab.

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

- `state` is `on_track`, `late` (any instalment overdue) or `completed`.
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
