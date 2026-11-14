# Prompt: redesign the AtomPay mobile app to match the v2 website

> Hand this whole file to the agent or developer working in the **AtomPay Flutter app** repository.
> It is self-contained: every colour, size and string below is taken from the live website's
> stylesheets and views (`atompay.shop`, design "v2"), not invented.

---

## Your task

Redesign the AtomPay Flutter app (Android + iOS, one codebase) so it looks and reads like the
website at **https://atompay.shop**, which was rebuilt in November 2026 on Atomshop.pk's
"storefront v2" design system.

This is a **visual and copy redesign**. Keep the app's architecture, navigation map, auth state
machine, API client, and business logic exactly as they are. Change the theme, the shared
components, the screens' layout and wording — nothing else, unless a section below says otherwise.

Open https://atompay.shop in a browser before you start and keep it open. Every screen you build
has a counterpart on the site (mapped in §9); when this document and the site disagree on a
visual detail, **the site wins**, and say so in your summary.

---

## 1. What this replaces in `MOBILE_APP_HANDBOOK.md`

The handbook was written for the **old** website design. These sections are now wrong and are
**replaced** by this document — do not implement them:

| Handbook section | Status |
|---|---|
| §4.1 Colour tokens (`nucleus`, `paper`, the five-colour "spectrum") | **Replaced** by §3 here |
| §4.3 Typography (Bricolage Grotesque, Inter, JetBrains Mono) | **Replaced** by §4 here |
| §4.4 "No elevation / shadows", violet focus ring | **Replaced** by §5 here |
| §4.5 Logo (the dark disc with two orbit ellipses and an "A") | **Wrong brand — remove it** (§2) |
| §4.6 Components | **Replaced** by §6 here |
| §4.7 "Money: `PKR 45,000`. Never `Rs.`" | **Reversed** — use `Rs.` (§7) |
| §5.10 Calculator (down-payment slider 20–60%, tenure chips, markup) | **Wrong product — replaced** by §8 |

Everything else in the handbook — architecture (§3), the system (§2), auth, networking, storage,
the API contract in `docs/api/`, accessibility intent (§4.8) — **still applies**.

---

## 2. Brand and logo

The AtomPay mark is a **charcoal "A"** joined to a **coral "P"**, with an **amber step** beneath.
The old orbit-ring logo in the handbook is not the brand; it was a placeholder and has already
been removed from the website. Delete it from the app (icon, splash, empty states).

Source files, from the website repository:

| File | Size | Use |
|---|---|---|
| `public/web/v2/img/atompay-mark.png` | 256 × 256, transparent | In-app mark, splash, empty states |
| `public/web/v2/img/atompay-logo.png` | 462 × 360 | Full wordmark |

**The 256 px mark is too small for an iOS app icon (1024 × 1024).** Ask for a vector or 1024 px
source before generating launcher icons; do not upscale the PNG. iOS icons have no transparency, so
render the iOS icon on **white**. The Android adaptive icon foreground is the mark; its background
is white.

The header lockup on the site is: mark (10 px corner radius) · **ATOMPAY** (800, letter-spacing
−0.4) · beneath it **PAY IN STEPS** (small, uppercase, widely tracked, muted).

---

## 3. Colour tokens

Define these once in the theme. Every screen reads from the theme, never a literal.

### Core (Atomshop storefront v2)

| Token | Hex | Role |
|---|---|---|
| `ink` | `#14213D` | Headings, primary text, dark buttons, footer |
| `primary` | `#2747C7` | Primary buttons, links, eyebrows, current step, focus |
| `primaryDark` | `#1D3AA6` | Pressed primary; text on `primarySoft` notes |
| `primarySoft` | `#EEF2FD` | Info notes, selected rows, blue badges |
| `body` | `#4F5B76` | Body copy |
| `muted` | `#656F88` | Secondary text, hints, captions |
| `surface` | `#F5F7FB` | Screen background, image tiles, read-only fields |
| `line` | `#E3E8F1` | Card borders, dividers |
| `line2` | `#DCE2EC` | Input borders, ghost-button borders |
| `amber` | `#F7A928` | Amber button fill — **never as text** |
| `amberSoft` | `#FFF5E0` | Amber badge background |
| `amberInk` | `#8A5A00` | Text on `amberSoft` (the only "amber" text colour) |
| `green` | `#18794A` | Paid, verified, approved |
| `greenSoft` | `#E8F7EF` | Green badge / success note background |
| `rose` | `#B0283F` | Late, rejected, errors, and **all coral-family text** |
| `roseSoft` | `#FDEEF1` | Rose badge / error note background |
| `greySoft` | `#EEF1F6` | Neutral badge background |

**`muted` is `#656F88`, not v2's `#69738C`.** The website darkened it because `#69738C` on
`surface` measures 4.42:1, just under WCAG AA's 4.5 for normal text. Use `#656F88`.

### AtomPay's own accent (from the logo)

| Token | Hex | Role |
|---|---|---|
| `apayCoral` | `#F05465` | Fills and graphics only — fails contrast as text on white |
| `apayAmber` | `#FAA53A` | Fills and graphics only |
| `apayWash` | `#FFF6EE` | Highlighted / "this is AtomPay" card background |
| `apayLine` | `#F6DFD2` | Border on `apayWash` cards |
| `apayGradient` | `LinearGradient(135°, #FAA53A → #F05465)` | The spend (limit) card, and nothing else |

Rule: **coral and amber fill graphics; coral-family _text_ uses `rose`.**

### Contrast — already measured, keep these pairs

| Pair | Ratio |
|---|---|
| `body` on white / on `surface` | 6.80 / 6.34 |
| `muted` on white / on `surface` | 5.02 / 4.68 |
| `primary` on white | 7.47 |
| white on `primary` / on `ink` | 7.47 / 15.97 |
| `ink` on `apayCoral` / on `apayAmber` | **4.69** / 7.99 |
| `rose` on `roseSoft` · `green` on `greenSoft` · `amberInk` on `amberSoft` · `primary` on `primarySoft` · `body` on `greySoft` | 5.80 · 4.90 · 5.47 · 6.67 · 6.00 |

No dark mode in this pass. Define the tokens so one can be added later.

---

## 4. Typography

**Plus Jakarta Sans**, weights 400, 500, 600, 700, 800. Bundle the font files in the app — never fetch
them at runtime. One family for everything; the website has no serif, no mono, no second sans.

Mobile scale, derived from the website's stylesheet (`site.css`):

| Style | Size / weight | Letter-spacing | Web source | Use |
|---|---|---|---|---|
| `display` | 34 / 800, height 1.05 | −1.2 | `.spend .amt` (32–44) | The available-to-spend figure |
| `h1` | 30 / 800, height 1.05 | −1.0 | `.h1` (36–60, −1.8) | Screen titles |
| `h2` | 24 / 800, height 1.08 | −0.6 | `.h2` (28–42, −1) | Section titles |
| `h3` | 20 / 800 | −0.3 | `.h3` | Card titles |
| `lead` | 17 / 500, height 1.6, `body` | 0 | `.lead` | One-line intro under a title |
| `body` | 15 / 500, height 1.6, `body` | 0 | body copy | Paragraphs |
| `small` | 13 / 600, `muted` | 0 | hints | Hints, captions, secondary rows |
| `label` | 15 / 700 | 0 | `.btn` | Buttons (sentence case) |
| `eyebrow` | 12 / 800, **UPPERCASE**, `primary` | +1.6 | `.eyebrow` | Kicker above a title |
| `badge` | 11 / 800, **UPPERCASE** | +0.6 | `.badge` | Status pills |
| `figure` | inherits, **tabular figures** | — | — | Every amount and date in a list |

Weights in use are 600, 700 and 800 almost everywhere; 400 is rare. Body copy is 500.

---

## 5. Shape, spacing, elevation, motion

| | Value | Web source |
|---|---|---|
| Card radius | **24** | `--radius: 24px` |
| Product card radius | 22 | `.p-card` |
| Spend card radius | 20 | `.spend` |
| Input radius | 12 | `.field input` |
| Buttons, badges, pills | fully rounded (999) | `.btn`, `.badge` |
| Button height | **48**; large **54** | `.btn`, `.btn-lg` |
| Input height | 48 | `.field input` |
| Card padding | 24 (20 on narrow screens) | `.card` |
| Screen gutter | 16 (20 on tablets) | site's mobile gutter |
| Spacing scale | 4, 6, 8, 10, 12, 14, 16, 18, 20, 24, 32, 40, 64 | |
| Card border | 1 px `line` | `.card` |
| Card shadow | `0 16 40` blur, `ink` at 8% — optional, subtle | `--shadow` |
| Focus | 2 px `primary` outline, 2 px offset | `:focus-visible` |
| Touch targets | **48 × 48 minimum** | |
| Motion | 150–250 ms ease-out; respect reduce-motion | |

---

## 6. Components

Build these as shared widgets first, put them on a hidden **component gallery** screen, and get the
gallery right before touching any real screen.

**Buttons.** Pill, height 48, label 15/700, 22 horizontal padding.
- `Primary` — `primary` fill, white label. The main action on a screen.
- `Dark` — `ink` fill, white label.
- `Ghost` — white fill, `line2` 1 px border, `ink` label.
- `Amber` — `amber` fill, **`ink`** label (never white on amber).
- **Busy state:** when a submit is in flight, replace the label with an 18 px spinner (2 px ring,
  top segment transparent) in the label's own colour — white on `Primary`/`Dark`, `ink` on
  `Ghost`/`Amber`. Keep the width, disable the button, don't dim it. A dimmed button reads as
  "broken", not "working".

**Badge / StatusPill.** Pill, 11/800 uppercase, +0.6 tracking, padding 4 × 10, never wraps. Always a
soft background with its strong text colour — see the status map below.

**Status map** (the same on every screen):

| API value(s) | Badge | Label |
|---|---|---|
| `paid`, `verified`, `approved`, `done` | `greenSoft` / `green` | Paid · Verified · Approved |
| `due`, `pending`, `conditional` | `amberSoft` / `amberInk` | Due · Under review · Conditional |
| `late`, `rejected`, `blocked` | `roseSoft` / `rose` | Late · Rejected |
| `current`, info | `primarySoft` / `primary` | — |
| `upcoming`, `not_started` | `greySoft` / `body` | Upcoming · Not started |

**SpendCard** (the limit). `apayGradient` background, radius 20, padding 20, **all text solid `ink`**.
- Label `AVAILABLE TO SPEND` — 12/800 uppercase, +1.2 tracking, solid `ink`.
- Figure — `display`, `Rs. 28,666`.
- A row beneath (13/700, solid `ink`): limit, used, max instalment.
- **Do not use translucent ink for the label or row.** The website did, and `ink` at 72% over the
  coral end of the gradient measures 3.31:1 — an AA failure. Solid `ink` is 4.69:1 on coral and
  7.99:1 on amber, so it passes across the whole sweep.
- No limit yet: label `NO LIMIT YET` and a `Primary` button to apply.

**ProductCard.** White, radius 22, 1 px `line`, clips its children.
- Image tile: `surface` background, **220 high** (200 on narrow phones), picture centred at 72%,
  `BoxFit.contain`.
- `ATOMPAY ELIGIBLE` badge (`roseSoft`/`rose`) **pinned top-left, 12 from both edges**. `OUT OF
  STOCK` (`greySoft`/`body`) pinned top-right at the same height. Neither sits in the image's layout
  flow — on the website a badge left in the flow ended up halfway down the picture and pushed the
  photo off centre.
- **Placeholder:** a thin-stroked box glyph (76, `#AAB5C8`) shown **only when there is no
  picture, or the picture fails to load**. Never render it underneath a loaded picture — at 72%
  with `contain` the picture does not cover it, and it shows round every image.
- Body: brand (12/700 uppercase, +0.6 tracking, `muted`) · title (15/700 `ink`, height 1.35) ·
  monthly figure (20/800 `ink`, −0.4 tracking, tabular) · `per month × 3 · no advance` (13/600
  `muted`) · `Cash price Rs. 231,995` (13, `muted`). The monthly block is pushed to the bottom of the
  card so prices line up across a row.
- Pressed / focused: border becomes `apayCoral`.
- Tapping opens the product **on Atomshop** (`https://atomshop.pk/{slug}`) — the order is placed
  there, not in AtomPay. Use the external browser or an in-app browser tab.

**Stepper (Track).** The website's `.track`, used for the KYC process and the application wizard.
- Each step: a 20 px circle, then title (13/700) and a hint line (11.5/600).
- `done` — `green` fill with a white tick; title `ink`; hint `green`, prefixed `✓`.
- `now` — white centre with a 6 px `primary` ring; title and hint `primary`.
- upcoming — white with a 2 px `#C9D2E3` ring; title `muted`.
- `stop` — `roseSoft` fill, `rose` ring; title `rose`.
- Connector: 2 px `line`, turning `green` between completed steps.
- Horizontal on tablets; on phones, vertical.

**KeyValue rows (`.kv`).** Label 12/700 uppercase `muted`; value 15/700 `ink`; an optional sub-line
12/600 `muted`. Used for verification details and the review step.

**Note (banner).** Rounded 14, padding 14 × 16, icon + text.
- `blue` — `primarySoft` / `primaryDark`: information.
- `green` — `greenSoft` / `green`: success, "your limit stays active".
- `rose` — `roseSoft` / `rose`: "Some details need attention".

**TextField.** Height 48, radius 12, 1 px `line2`, fill `#FBFCFE`, text 15 `ink`. Label above
(14/600 `ink`), hint below (12/500 `muted`).
- **Invalid:** border `#D23C4E`, fill `#FFF7F8`, error message below in `rose` 13/600 — on the
  field, not only in a banner at the top.
- **Read-only figure** (e.g. disposable income): `surface` fill, 17/800; a negative value turns
  `rose` on `roseSoft`.

**SearchablePicker.** Every dropdown is searchable — the website made all of them so, because the
lists are long: **99 cities, and 474 areas in Lahore alone**.
- Looks like a TextField with a chevron. Tapping opens a modal bottom sheet: a search field with
  focus, a filtered list, the current choice marked with a tick, and "No match" when empty.
- Matching is case-insensitive substring.
- Used for: city, **area**, employment status, income source.

**City → Area.** Area sits directly after City.
- Disabled with the hint **"Choose a city first"** until a city is chosen.
- Changing city clears the area and reloads the list for the new city.
- An area from a different city must never be submittable.
- Hint under the field: **"Helps us deliver to the right part of {City}."**

**DocumentTile.** Dashed 1.5 px `#C9D2E3` border, radius 14, `#F8FAFE` fill, min height 150, centred
icon + label + caption. Captions: "Front of the card", "Back of the card", "Hold your CNIC next to
your face". When a file is chosen show its name; when one is on file show **"On file — choose a file
to replace it"**. Filled state: solid border.

**Empty / error states.** The AtomPay mark (not the old orbit logo), one sentence, one action.

---

## 7. Copy and formatting

- **Money: `Rs. 157,999`.** This reverses the handbook. The website uses `Rs.` in 54 places and
  Atomshop — where the customer actually pays — uses `Rs.` too. Never `PKR`, never decimals, always
  a thousands separator, always tabular figures in lists.
- Dates: `10 Dec 2026` in lists.
- Plain and short. "Your limit", not "credit facility".
- Use these strings exactly, because the website uses them:

| Where | Text |
|---|---|
| Spend card | `AVAILABLE TO SPEND` · `NO LIMIT YET` |
| Product card | `AtomPay eligible` · `per month × 3 · no advance` · `Cash price Rs. …` |
| Products section | eyebrow `ELIGIBLE PRODUCTS` · title `Look for the badge on the listing.` |
| Wizard steps | `Personal details` · `Identity documents` · `Income & financials` · `Review & submit` |
| Wizard hints | `As printed on your CNIC` · `CNIC photos and a selfie` · `Work, income and outgoings` · `Check everything once` |
| Wizard title | `Apply for your AtomPay limit` · `Update your application` · `Request a limit review` |
| Error banner | `Some details need attention — we've opened the step that has them.` |
| Area | `Choose a city first` · `Helps us deliver to the right part of {City}.` |
| Area error | `Choose an area that is inside the city you selected.` |
| Documents note | `Your documents are used only to verify your identity for AtomPay and are never shown on Atomshop.` |
| Declaration | `I confirm these details are accurate and I authorise AtomPay to verify them, including a one-time visit to my residential address, for the purpose of setting my purchase limit.` |
| Provisional figures | `Final figures are set by our team after the risk assessment.` |

Show the server's own `message` fields as they are — they are written for customers.

---

## 8. The plan rule — the calculator is a different product now

**AtomPay is not seller financing.** The handbook's calculator (a 20–60% down-payment slider,
tenure chips, a markup line) describes Atomshop's *other* instalment product. The owner fixed
AtomPay's terms on 24 Oct 2026:

| | |
|---|---|
| Products | Eligible listed products only. Never custom orders or offers. |
| Term | **3 months, always.** The customer does not choose it. |
| Advance | **Rs. 0.** |
| Markup | **0%.** The customer repays exactly the cash price. |
| Monthly | `price ~/ 3`; the **last month takes the rounding**, so the three add up to the price. |
| Processing fee | **3% of the price, shown as a disclaimer. Never added to the total.** |
| Delivery | "Delivery charges apply", stated next to the fee. |
| Limit | Must cover the **whole** price, since no advance reduces it. |

Worked example — `Rs. 47,000`: months of **15,666 · 15,666 · 15,668** (= 47,000); processing fee
**Rs. 1,410** as a disclaimer; total **Rs. 47,000**.

So the calculator screen becomes: **one price input** → three monthly amounts with their months, the
total, and the fee line as a disclaimer. **No down-payment control. No tenure control. No markup.**

Limit estimate (the website's "Get approved" card): limit ≈ **30%** of monthly income; max monthly
instalment = **the smaller of 10% of income and disposable income**. Read both ratios from the
server — do not hardcode `0.3` and `0.1`.

---

## 9. Screens — and the web page each one must match

| App screen | Match against |
|---|---|
| Splash | The mark on white |
| Sign in / Sign up / OTP / Forgot password | https://atompay.shop/login · `/register` · `/forgot-password` — the navy panel with the plan rule and the store badges |
| Home / Dashboard | `/my` — SpendCard, "Where you are" stepper ("Six stages, from your CNIC to your first purchase.") |
| Eligible products | `/products` — 2-up grid on phones (the site is 4-up on desktop), ProductCards |
| Application (KYC + income) | `/my/application` — the 4-step wizard |
| Verification status | `/my/verification` — stepper, KV rows (CNIC and mobile **masked** once verified), documents |
| Applications history | `/my/applications` |
| Plans / orders | `/my/orders` — each order, its 3-month schedule, paid/due/late |
| Calculator | the "The plan" section on the home page |
| Notifications, Account, Delete account | `/my/delete` and the site's account navigation |

**Application wizard** — one submission, four steps, exactly as on the site:
1. **Personal details** — full name, CNIC (`#####-#######-#`), mobile (`03## #######`), date of birth,
   **City**, **Area**, residential address.
2. **Identity documents** — CNIC front, CNIC back, selfie with CNIC (3 DocumentTiles).
3. **Income & financials** — employment status, income source, **employer / business name only when
   the status is salaried, self-employed or business owner**, monthly income, existing monthly
   instalments, monthly household expenses, read-only **disposable income** (income − instalments −
   expenses, `rose` when negative), and a SpendCard-style preview of the provisional limit and cap
   once income ≥ 1,000.
4. **Review & submit** — KV rows of everything, a declaration checkbox (the whole row is the touch
   target), and the submit button **disabled until it is ticked**.

Behaviour to keep: "Continue" validates only the current step; any step already reached can be
re-opened from the stepper; after a server `422`, open the **earliest** step that owns an errored
field and show each error on its field. When a limit is already approved, the title is "Request a
limit review" and a green note says the current limit stays active during the review.

---

## 10. Server dependencies — check these before you build the screens that need them

The website's backend serves the app. Four things the redesign needs are **not in the API yet**.
Do not work around them in the app; report them, and build the rest.

| Needed for | Status today | What's required |
|---|---|---|
| **Calculator / plan quotes** | `GET /api/v1/calculator` and `POST /api/v1/quote` **still return seller financing** (advance bounds, tenures, markup). | Server must return the AtomPay plan (§8). **Do not ship the calculator, and do not build a down-payment slider, until it does.** Do not compute the plan in the app as a stopgap — that makes two sources of truth for money. |
| **Area picker** | No areas endpoint, and the profile resource has no `area_id`. | `GET` areas for a city, and `area_id` read/write on `/api/v1/profile`. The server already validates area-within-city. |
| **Eligible products** | No products endpoint (the website reads it server-side). | A paginated eligible-products endpoint with each product's plan figures. |
| **Limit-estimate ratios** | Check `/app-config` and `/options`. | If absent, expose `limit_ratio` and `instalment_ratio`. |

Ask Atom (the website's help assistant) is web-only; leave it out of this pass.

---

## 11. Accessibility

- WCAG AA on every text pair — use only the pairs in §3. Never `amber` or `apayCoral` as text.
- Every status has a text label, never colour alone.
- 48 × 48 minimum touch targets, including the picker rows and the stepper (if tappable).
- Text scale up to 2.0 without clipping; the SpendCard figure may shrink, not truncate.
- Semantics labels on icon-only buttons; the OTP field reads as one field; the busy button announces
  "loading".
- Respect reduce-motion: no spinner spin acceleration, no count-ups.

---

## 12. How to work

1. Read the app's theme/token file and its shared widgets. Report what exists before changing it.
2. Replace the theme (§3–§5). Remove the old palette and fonts entirely — no dead tokens left behind.
3. Build the components (§6) and a component gallery screen. Compare each against the website.
4. Restyle screens in this order: auth → dashboard → application wizard → verification → plans →
   products → calculator (last, and only once §10's calculator fix exists).
5. For every screen, take a phone screenshot next to the matching website page at 390 px wide, and
   fix the differences before moving on.
6. Run the app's tests and add widget tests for: the busy button, the SpendCard's solid-ink text,
   the ProductCard placeholder (hidden with a picture, shown without), the badge positions, the
   city→area reset, and the step a `422` reopens.

## 13. Done means

- [ ] No trace of `nucleus`, `paper`, the spectrum gradient, Bricolage Grotesque, Inter, JetBrains
      Mono, or the orbit-ring logo remains in the app.
- [ ] Plus Jakarta Sans is bundled and used everywhere.
- [ ] Every amount reads `Rs. 1,234`.
- [ ] The SpendCard uses `apayGradient` with solid `ink` text.
- [ ] Every dropdown is a SearchablePicker; Area follows City and resets with it.
- [ ] The ProductCard badge sits top-left; the placeholder never shows under a real picture.
- [ ] No down-payment, tenure or markup control exists anywhere.
- [ ] Each screen has been compared side by side with its website page.
- [ ] Your summary lists every §10 dependency still open, and every place you chose the website
      over this document.
