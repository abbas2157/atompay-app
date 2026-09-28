# Calculator & estimate

[← API index](README.md) · [Conventions, errors & limits](conventions.md)

All three are public, so they work before sign-up. They use the same pricing as AtomShop checkout:

```
markup  = per_month% × months × (price − advance)
total   = price + markup
monthly = ceil((total − advance) / months)
```

## `GET /calculator`

The bounds for the calculator controls:

```json
{
  "data": {
    "tenures": [3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
    "per_month_percentage": 4,
    "advance": { "min_ratio": 0.2, "max_ratio": 0.6 },
    "price": { "min": 10000, "max": 300000, "step": 5000 }
  }
}
```

The tenures and percentage come from AtomShop's admin settings and can change (they're cached for up to 10
minutes on the server). Fetch them each time the calculator opens instead of hard-coding them.

## `POST /quote`

```json
{ "price": 100000, "months": 6, "advance": 25000 }
```

`advance` is optional and defaults to the minimum down payment (20% of price).

```json
{
  "data": {
    "price": 100000, "advance": 20000, "months": 6, "per_month_percentage": 4,
    "financed": 80000, "markup": 19200, "total": 119200, "monthly": 16534,
    "advance_bounds": { "min": 20000, "max": 60000 }
  }
}
```

**`422`** returns field errors: `months` gets *"Choose one of: 3, 4, … months."*, and `advance` gets *"Down payment
must be between PKR 20,000 and PKR 60,000."*

Debounce slider changes (for example 300 ms) before calling this endpoint. It's limited to 60 calls/min.

## `POST /estimate`

A "what could I get?" preview from income alone. Nothing is saved, and it is **not** an application.

```json
{ "monthly_income": 150000 }
```
```json
{ "data": { "monthly_income": 150000, "estimated_limit": 45000, "estimated_max_instalment": 15000 } }
```

Always label these figures as an estimate in the UI.
