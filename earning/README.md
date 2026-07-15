# Earning Opportunities Consolidation (`eos_refactored.ipynb`)

Consolidates earning opportunity (EO) data from the operational teams into
the five EO sheets of `IDC Report Consolidated Y2.xlsx`. An earning
opportunity is any instance in which Umuzi connected a learner to a paid
engagement — a gig, placement, stipend, or freelance contract.

**Run order:** this notebook runs **last**, after
`consolidate/indicators_consolidated.ipynb` has created the workbook — it
appends (`mode='a'`, `if_sheet_exists='replace'`). Its pre-flight cell
refuses to run if the workbook is missing and prints the correct order.

## Inputs

Live sources (paths anchored on `SRC = {MONTH_DIR}/Source Datasets`):

| Source | Owner | Shape |
|---|---|---|
| XPL continuous-updates workbook | Natalie | Wide: repeating 5-column opportunity blocks per learner; grows horizontally each month. The loader sizes itself to the actual sheet width and halts if a non-empty column breaks the `2 + 5k` block layout. |
| Milestone / Finance | Mitchell | Learners identified by SA ID number; resolved to email via the enrichment table |
| Partnerships (multi-sheet) | Kholofelo | Payments arrive as "R ..." strings; cleaned to float with a printed report of anything unparseable |
| Launch Lab | Anchen | CSV export of the template |
| SAP | SAP team | CSV export of the template |
| BeGreen | BeGreen team | Identified by ID number, resolved like Milestone |
| Umuzi Interns | — | **Currently disabled** (loader commented out) |

Prior outputs feeding the run:

- `prev_combined` — last month's `combined_eos.csv`. Sources now submit
  single-month files; this is how earlier Y2 months ride along. Live rows
  dated within `PREV_COVERS_THROUGH` that prev already contains are dropped
  as re-reads (multiset-aware, so the XA-Sept-25 repeat-payment exemption
  is preserved); rows prev lacks are kept as back-fills and **printed for
  verification**.
- `y1_combined` — the fixed Y1 final export, the baseline for `Counted Y1`.
- `db_fields.csv` + `emails.csv` — enrichment (three-tier demographic merge).

## Pipeline in one paragraph

Each source loads with its own quirks handled locally, then everything
shares one path: canonical emails (strip/lower/NFKC + `EMAIL_FIXES` +
personal-to-umuzi remap), one date parse, the Y2 window filter, the type
backfill (Internship → Placement, else Experience gig), four deduplication
passes (exact, the XH-PMA-Apr-25 surgical drop, resubmissions with the
XA-Sept-25 exemption, and the prev-coverage pass), zero/NaN payment removal
— every drop printed — then the cohort remap (`remapCohort`, unmapped labels
warned before mapping), programme names from the database with a manual
fallback map, demographic enrichment, and the five output formats.

## The counting columns

- `Counted Y1` — True if the learner appears in the Y1 baseline.
- `Youth Count (1 vs Counted)` — the funder's cumulative unique-youth count:
  a learner's first row is `'1'` **unless they were counted in Y1**, in
  which case every row is `'Counted'`. The sum of `1`s is therefore the
  net-new youth counted in Y2, asserted against the unique non-Y1 learner
  count every run.

## Output sheets

Learner Demographics · One Per Learner (stipends excluded) · Monthly Entries
Breakdown · Summarized Opportunities · Earning Opportunities Secured (the
partner-facing sheet: internal names are renamed to partner headings **at
export only** — reconciliation runs on internal names, so never rename
earlier).

## Validation

Reconciliation compares Summarized Opportunities against Earning
Opportunities Secured for **every month**, payments and counts, and halts
with a per-learner diff on any mismatch. Row-count asserts guard every
merge; unmapped cohorts, unmatched emails, unparseable payments and dates
are all printed with their offending rows.

## Monthly edits

The three lines marked `<-- MONTHLY EDIT` in CONFIG (`CURRENT_MONTH`,
`MONTH_DIR`, `PREV_MONTH_DIR`), plus whatever source filenames the owners
renamed — the pre-flight check lists the actual directory contents when a
name does not match. `PREV_COVERS_THROUGH` derives from `CURRENT_MONTH`
automatically.

## Dependencies

pandas, numpy, openpyxl, psycopg2 (via `connect.py`), python-dotenv.
Requires `earning/.env` with `dbname`, `user`, `password`, `host`, `port`
for the programme-name lookup. Never commit `.env`.