# Application (KYC Section 3)

[← API index](README.md) · [Conventions, errors & limits](conventions.md)

The income and financial profile that leads to a limit. The customer must have submitted a profile
([Profile](profile.md)) first.

## `GET /application`

```json
{
  "data": {
    "can_apply": true,
    "requires": null,
    "latest": { "...": "assessment, see below" },
    "active": { "...": "assessment, or null" }
  }
}
```

- When `can_apply` is `false`, `requires` is `"profile"`. Send the customer to the profile form.
- Pre-fill the form from `latest` when it exists.
- `active` is the limit in force, which can differ from `latest` while a re-application is pending.

**Assessment object:**

```json
{
  "id": 311,
  "status": "pending",
  "status_label": "Pending",
  "is_usable": false,
  "employment_status": "salaried",
  "employment_status_label": "Salaried",
  "employer_name": "Acme Ltd",
  "income_source": "salary",
  "income_source_label": "Salary",
  "monthly_income": 200000,
  "existing_instalments": 10000,
  "monthly_expenses": 90000,
  "disposable_income": 100000,
  "approved_limit": null,
  "max_instalment": null,
  "approved_tenure": null,
  "notes": null,
  "submitted_at": "2026-09-24T07:10:00+00:00",
  "decided_at": null
}
```

`approved_limit`, `max_instalment`, `approved_tenure` and `notes` stay `null` **until staff
decide**. The server computes a provisional figure but never shows it, because staff may change it.
`is_usable` is `true` for `approved` and `conditional`.

## `POST /application` (JSON)

```json
{
  "employment_status": "salaried",
  "employer_name": "Acme Ltd",
  "income_source": "salary",
  "monthly_income": 200000,
  "existing_instalments": 10000,
  "monthly_expenses": 90000
}
```

| Field | Rules |
|---|---|
| `employment_status` | required, a `value` from `/options` |
| `employer_name` | ≤ 255. **Required** when that status has `has_employer: true` |
| `income_source` | required, a `value` from `/options` |
| `monthly_income` | required, whole rupees, 1,000 – 100,000,000 |
| `existing_instalments` | optional (default 0), monthly amount paid on other loans/instalments |
| `monthly_expenses` | optional (default 0) |

**`201 Created`** returns the new assessment, with `status: "pending"`.
**`409`** with `code: "profile_required"` means no profile has been submitted yet.
**`409`** with `code: "nothing_changed"` means the customer already has a limit and sent exactly the
figures already on file. Show `message`; nothing was created.

Once a limit is approved, submitting again is a **limit review** (label the button "Request limit
review", not "Submit application"): it opens a new pending assessment, or updates the one already
pending, just as on the website. The limit in force (`active` from `GET /application`) keeps working
until staff decide the review.

## `GET /application/history`

`{ "data": [ assessment, ... ] }` lists every assessment, newest first.
