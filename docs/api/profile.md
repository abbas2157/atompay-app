# Profile (KYC Section 1) & cities

[← API index](README.md) · [Conventions, errors & limits](conventions.md)

## `GET /profile`

Returns the customer's identity profile. Before the first submission, this is a draft
**pre-filled from AtomShop** (name, phone, and CNIC/address if the shop has them) with
`status: "not_started"`. Use it to pre-populate the form.

```json
{
  "data": {
    "status": "pending",
    "full_name": "Ayesha Khan",
    "cnic": "4210176543219",
    "cnic_formatted": "42101-7654321-9",
    "mobile": "03995556666",
    "mobile_formatted": "0399 5556666",
    "date_of_birth": "1992-03-14",
    "residential_address": "House 7, Street 3, Gulshan, Karachi",
    "city": { "id": 1, "name": "Karachi" },
    "documents": {
      "cnic_front": { "uploaded": true,  "url": "https://atompay.shop/api/v1/profile/documents/cnic_front" },
      "cnic_back":  { "uploaded": true,  "url": "https://atompay.shop/api/v1/profile/documents/cnic_back" },
      "selfie":     { "uploaded": false, "url": null }
    },
    "address_verified": false,
    "verified_at": null,
    "submitted_at": "2026-09-24T06:50:02+00:00"
  }
}
```

`status` uses the same values as `kyc_status` above.

## `POST /profile` (multipart/form-data)

Creates or updates the profile. Send **every text field every time**. The images are:

- **required on the first submission**, all three of them
- **optional after that**. Omit an image to keep the one on file, or send it to replace it

| Field | Rules |
|---|---|
| `full_name` | required, ≤ 255, as printed on the CNIC |
| `cnic` | required, 13 digits (dashes optional), first digit 1–7, not already used by another customer |
| `mobile` | required, Pakistani mobile |
| `date_of_birth` | required, `YYYY-MM-DD`, customer must be **18+** |
| `residential_address` | required, ≤ 1000 |
| `city_id` | optional, an `id` from `GET /cities` |
| `cnic_front`, `cnic_back`, `selfie` | image files: jpg / jpeg / png / webp, **≤ 4 MB each** |

**`201 Created`** on the first submission and **`200 OK`** on an update. Both return the profile
object above.

> **Changing name, CNIC, date of birth, address or any document sends the profile back to
> `pending`**, so staff verify it again. Warn the customer before they save changes to a
> `verified` profile.

Client tips:

- Compress photos before upload (longest side ~1600 px, JPEG quality ~85). Phone cameras
  easily exceed 4 MB.
- Use the camera for the selfie (front lens) and the gallery or camera for the CNIC.
- For client-side checks, mirror the server rules: 13 digits with the first digit 1–7,
  `03` + 9 digits, age ≥ 18.

## `GET /profile/documents/{document}`

`{document}` is `cnic_front`, `cnic_back` or `selfie`. It streams the customer's **own** image
(`Cache-Control: private, no-store`) and needs the bearer header, so load it like this:

```dart
Image.network(url, headers: {'Authorization': 'Bearer $token'})
```

Don't cache these images to disk. They are identity documents.

`404` means that document hasn't been uploaded.

---

## `GET /cities`

AtomShop's active cities, sorted A–Z, for the profile's city picker.

```json
{ "data": [ { "id": 59, "name": "Ahmadpur East" }, { "id": 99, "name": "Alipur" } ] }
```

The list changes rarely. Caching it for the session is fine.
