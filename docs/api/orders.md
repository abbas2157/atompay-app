# Buy with AtomPay (in-app orders)

[← API index](README.md) · [Conventions, errors & limits](conventions.md)

The customer orders one AtomPay-eligible product from the app: 3 months, no advance, 0% markup,
delivered to their **verified KYC address**. Nothing is paid in the app.

AtomPay never writes Atomshop's tables. **Atomshop places the order** (server to server,
`POST {ATOMSHOP_API_URL}/atompay/orders` with the shared `ATOMPAY_SERVER_KEY`) through the same code as its
website checkout, and records the Key Fact Statement acceptance. AtomPay first checks what Atomshop leaves to
staff: the whole price within the customer's available limit (less any AtomPay orders still awaiting approval), and the largest month within their monthly cap.

**Switch:** `GET /app-config` → `features.in_app_orders`. When `false`, keep "Buy on Atomshop.pk"; both
endpoints answer `409 orders_unavailable`. On when `ATOMPAY_IN_APP_ORDERS=true` and `ATOMPAY_SERVER_KEY` is set
(the same key in Atomshop's `.env`).

## The flow

1. Product page → `GET /products/{id}/kfs`. A `409` means the customer can't order it (show `message`).
2. The app shows the statement with an **unticked** "I have read the Key Fact Statement…" box.
3. `POST /orders` with `accept_kfs: true` and `kfs_amount` = the statement's `amount_financed`.
4. `201` → "Order placed". The order is in `GET /plans` at once (`state` pending); dates are set on delivery.

## `GET /products/{id}/kfs`  · Auth ✓

The same keys as [`GET /plans/{order}/kfs`](plans.md), before an order exists:
`order_id` and `order_number` are `null`, `schedule_final` is `false`, every `due_date` is `null`,
`accepted_at` is `null`.

```json
{ "data": {
  "order_id": null, "order_number": null, "product": "OXY 3218L Android",
  "lender": { "name": "Atomshop (Pvt) Ltd", "licence": null, "address": null },
  "amount_financed": 47000, "advance": 0, "markup_percent": 0,
  "processing_fee_percent": 3, "processing_fee": 1410, "apr_percent": 18.5,
  "months": 3, "schedule_final": false,
  "instalments": [
    { "number": 1, "due_date": null, "amount": 15666 },
    { "number": 2, "due_date": null, "amount": 15666 },
    { "number": 3, "due_date": null, "amount": 15668 }
  ],
  "total_repayable": 47000, "late_payment": null, "early_settlement": null,
  "complaints": "In the app: Help › Complaints.", "accepted_at": null,
  "issued_at": "2026-11-12T12:00:00+00:00"
} }
```

`404` if the product isn't AtomPay-eligible or visible. `409` codes below.

## `POST /orders`  · Auth ✓ · 5/min per account

```json
{ "product_id": 812, "kfs_amount": 47000, "accept_kfs": true }
```

`201`:

```json
{ "data": {
  "order_id": 1280, "order_number": "AS-01280", "product": "OXY 3218L Android",
  "total": 47000, "advance": 0, "months": 3, "instalments": [15666, 15666, 15668],
  "area": "Johar Town", "status": "pending"
} }
```

| Status | When |
|---|---|
| `409` | See the codes below. Nothing was ordered. |
| `422` | `accept_kfs` not true, or `errors.order[0]`: Atomshop refused it, in words for the customer (the price changed since the statement: show it again; the product went out of stock). |
| `5xx` | Atomshop didn't answer. **The order may not exist:** check `GET /plans` before offering to try again. |

A second `POST /orders` while one is being placed answers `409 order_in_progress`, so a double tap never orders twice.

`409` codes (also from `GET /products/{id}/kfs`):

| `code` | Meaning / app action |
|---|---|
| `orders_unavailable` | Switched off. Offer "Buy on Atomshop.pk". |
| `limit_required` | No approved limit. Send to "Apply for your limit". |
| `over_limit` | The price is more than what's available, counting the customer's AtomPay orders still awaiting approval (`available` doesn't include those yet). Show `message`. |
| `over_cap` | A month is more than the monthly cap. Show `message`. |
| `address_required` | The profile has no city, area or address. Send to the profile form. |
| `order_in_progress` | An order is being placed. Show `message`, then My orders. |
