# idc-scripts

Scripts, queries, and notebooks that produce Umuzi's monthly/quarterly IDC
(Industrial Development Corporation of South Africa Ltd) impact report. The pipeline covers two
reporting arms — **Support Services** (Indicators 5, 6, 7) and **Earning
Opportunities** — and assembles both into a single partner-facing workbook,
`IDC Report Consolidated Y2.xlsx`.

The notebooks are built to be run by anyone on the data team. Every drop is
printed, every assumption is validated, and when something is wrong the run
halts with a table that says what broke and which CONFIG entry or source file
to fix. If a notebook completes silently, the numbers can be trusted; if it
halts, read the last table — it was written for you.

---

## What this repository is (and is not)

This repo is the **home of the code only**: three notebooks, three SQL
queries, and the database helper modules. **No data lives here and none
should ever be committed** — no source submissions, no exports, no `.env`,
no output workbooks.

All data lives in a **data root on your own machine** (referred to as `BASE`
throughout the notebooks). You set it up once, add a folder per reporting
month, and point each notebook's CONFIG cell at it. Setup is described below.

## Repository layout

```
idc-scripts/
├── queries/       SQL run against the production database each cycle
│   ├── populate_fields.sql     -> db_fields.csv (the enrichment table)
│   ├── idc_indicator_5.sql     -> indicator_5.csv
│   └── idc_indicator_7.sql     -> indicator_7.csv (database-logged services)
├── support/       support_services_consolidated.ipynb
│                  (all support service sources -> indicator_7_data.csv)
├── consolidate/   indicators_consolidated.ipynb
│                  (Indicators 5, 6, 7 + Participants -> creates the workbook)
└── earning/       eos_refactored.ipynb + database helper modules
                   (earning opportunities -> appends 5 sheets to the workbook)
```

---

## One-time setup (per person / per machine)

**1. Clone the repo and install dependencies**

```
pip install pandas numpy openpyxl psycopg2-binary python-dotenv
```

**2. Create `earning/.env`** (never commit it) with the database credentials
used by the programme-name lookup:

```
dbname=...
user=...
password=...
host=...
port=...
```

**3. Create your data root (`BASE`).** Any folder works — e.g.
`~/Documents/Umuzi/Reporting`. It must contain:

```
<BASE>/
├── Improved IDC/
│   ├── Categories/Support/
│   │   └── db_fields.csv          <- export of queries/populate_fields.sql
│   └── Email Matching/
│       └── emails.csv             <- secondary enrichment export
└── Monthly IDC/
    ├── June (2026)/               <- one folder per reporting month
    │   ├── Database/              <- exports of indicator_5.sql, indicator_7.sql
    │   ├── Source Datasets/       <- the data owners' submissions for the month
    │   └── Sink Datasets/         <- everything the notebooks write (auto-created)
    └── ...
```

Older month folders may also contain `Earning/`, `Support/`, `Consolidate/`
subfolders — those are legacy homes of per-month notebook copies from before
this repo was the canonical code location. They are harmless and not needed
for new months.

> **Folder naming warning:** historical month folders are inconsistent —
> some have a space before the parenthesis (`June (2026)`), some do not
> (`May(2026)`). The notebooks do not guess: `MONTH_DIR` in each CONFIG must
> match what is actually on disk. Pick one convention for new months and
> stick to it.

**4. Set `BASE` in each notebook's CONFIG cell** to your data root. This is
a one-time edit per machine; after that, the only monthly edits are the
lines marked `<-- MONTHLY EDIT`.

---

## The monthly run

**Step 0 — collect.** Data owners' submissions go into
`<MONTH_DIR>/Source Datasets/`. Owners and their files: Natalie (XPL
continuous-updates workbook — same file all year), Mitchell/Finance
(Milestone), Kholofelo (Partnerships), Anchen (Launch Lab), the SAP,
BeGreen, Heart, and LX teams, and Kennedy's Coursera export (a **folder**
of per-pathway CSVs).

**Step 1 — queries.** Run the three files in `queries/` against the
production database and export the results:

| Query | Export to |
|---|---|
| `populate_fields.sql` | `<BASE>/Improved IDC/Categories/Support/db_fields.csv` |
| `idc_indicator_5.sql` | `<MONTH_DIR>/Database/indicator_5.csv` |
| `idc_indicator_7.sql` | `<MONTH_DIR>/Database/indicator_7.csv` |

**Step 2 — notebooks, in this order.** The order is enforced, not optional:
the consolidation notebook **creates** the workbook (`mode='w'`) and the
earning notebook **appends** to it (`mode='a'`) — the earning notebook's
pre-flight check refuses to run if the workbook does not exist yet.

| # | Notebook | Edits before running | Produces |
|---|---|---|---|
| 1 | `support/support_services_consolidated.ipynb` | reporting period, `MONTH_DIR`, source filenames | `indicator_7_data.csv` |
| 2 | `consolidate/indicators_consolidated.ipynb` | `MONTH_DIR` | creates the workbook: Indicator 5, 6, 7 + Support Participants List |
| 3 | `earning/eos_refactored.ipynb` | `CURRENT_MONTH`, `MONTH_DIR`, `PREV_MONTH_DIR`, source filenames | appends: Learner Demographics, One Per Learner, Monthly Entries Breakdown, Summarized Opportunities, Earning Opportunities Secured |

> **Note for long-time runners:** this order **inverts** the old workflow,
> which ran earning before consolidation. Running the old order now wipes
> the earning sheets when the workbook is recreated.

Run each notebook with *Restart & Run All*. Source filenames drift month to
month ("Copy of" prefixes, owner names in brackets); when a path in CONFIG
does not match, the notebooks fail before doing any work and print what is
actually in `Source Datasets` so you can correct the name.

**Step 3 — validate and distribute.** A complete workbook has nine sheets
(four from step 2, five from step 3). Review any WARN-level items in the
final validation summaries — nameless learners, out-of-window dates,
cross-source duplicates — before the report is shared.

---

## When a run halts

All three notebooks share a fail-loud validation framework. A halt always
ends with a table of failed checks; each row names the problem and the fix.
The common ones:

| Halt | Fix |
|---|---|
| Missing input file(s) + a directory listing | Correct the filename in CONFIG using the listing |
| Unmatched emails (support) | Follow the printed 3-option instructions: `EMAIL_CORRECTIONS`, `KNOWN_UNREPORTABLE_EMAILS`, or fix the database and re-export `db_fields.csv` |
| Unmapped Coursera programmes | Add the printed Program Names to `COURSERA_COHORT_MAP` (or `COURSERA_DROP_SERVICES` if the cohort is employed) |
| Unmapped cohorts (earning) | Add the printed labels to `remapCohort` |
| Workbook does not exist (earning) | Run `consolidate/indicators_consolidated.ipynb` first — see run order |
| result/breakdown reconciliation failure (earning) | Read the per-learner diff printed above the assert; do not distribute until it reconciles |

Warnings (WARN) print their offending rows but allow the run to finish —
they are the "verify with a human" tier, not the "the data is broken" tier.

---

## Outputs and the rolling files

`<MONTH_DIR>/Sink Datasets/` after a full run contains:

- `IDC Report Consolidated Y2.xlsx` — the partner deliverable (9 sheets)
- `indicator_7_data.csv` — consolidated support services (feeds step 2 and
  next month's `prev_indicator_7` if a source goes non-cumulative)
- `indicator_6_data.csv` — one row per supported learner
- `combined_eos.csv` — the cleaned earning-opportunities frame. **Next
  month's run reads this as `prev_combined`** — it is how single-month
  submissions are stitched into the cumulative Y2 picture, with
  already-covered re-reads dropped and genuine back-fills kept (and
  reported).

The Y1 final export (`Monthly IDC/March(2026)/Sink Datasets/combined_eos.csv`)
is the fixed baseline for the `Counted Y1` flag all year — learners present
in it are `Counted` from their first Y2 row rather than consuming a new `1`
in `Youth Count (1 vs Counted)`.

## Known quirks (deliberate — do not "fix")

- `apss.staus` in the SQL is the **actual production column name** (schema
  misspelling). Correcting it breaks the queries.
- The XA-Sept-25 cohort is exempt from duplicate removal in the earning
  pipeline: identical-looking rows there are genuine repeat payments.
- Natalie's XPL workbook grows **horizontally** — new months arrive as new
  column blocks, not rows. The loader sizes itself to the sheet width;
  never reintroduce hardcoded `usecols` there.
- Umuzi's financial year runs April → March. All month ordering uses
  `FY_MONTH_ORDER`, never calendar or alphabetical order.