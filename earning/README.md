================================================================================
README: eos.ipynb — Earning Opportunities Consolidation
Umuzi x IDC Impact Report Pipeline
================================================================================

OVERVIEW
--------
This notebook consolidates earning opportunity (EO) data from multiple internal
Umuzi teams into a single cleaned, enriched, and multi-format output for the IDC
impact report. The report focuses on earning opportunities accessed by unemployed,
non-white South African youth under the age of 35.

This notebook covers the Earning Opportunities arm of the report only.
Support Services data is handled separately.


--------------------------------------------------------------------------------
INPUT DATA SOURCES
--------------------------------------------------------------------------------

The notebook ingests data from six operational teams/channels, each stored in
separate Excel or CSV files (paths are left blank in the notebook and must be
filled before running):

1. XPL / Natalie EOs
   - Excel file with up to 5 sheets
   - Wide format: each row is a learner; each earning opportunity is a set of
     repeated column groups (payment, date, type, name, extra_info)
   - Columns are renamed and the data is melted into long format

2. Milestone / Finance Data (Mitchell)
   - Excel file; learners identified by ID number rather than email
   - Joined to enrichment data to resolve Umuzi email addresses
   - One freelancer record was manually excluded

3. Partnerships
   - Excel file with up to 10 sheets combined into one dataframe
   - Payment values come in as strings with "R" prefix; these are cleaned to float
   - One known email typo (feroza.chisty -> feroza.chishty) is corrected ad hoc

4. Launch Lab
   - Single Excel sheet; column names are assigned directly on read

5. Community Team
   - Single Excel sheet

6. SAP Team
   - Learners identified by ID number; joined to enrichment data to resolve emails
   - Payment values cleaned from string format

7. Umuzi Interns
   - CSV file

8. Previous Month's Consolidated Data
   - CSV export from a prior run of this notebook
   - Appended to the current period's data to maintain a rolling dataset


--------------------------------------------------------------------------------
ENRICHMENT / REFERENCE DATA
--------------------------------------------------------------------------------

Two enrichment files provide demographic and identity information used to:
- Resolve ID numbers to Umuzi email addresses
- Enrich records with gender, race, province, metro, disability status, DOB,
  phone number, and name fields

These are deduplicated on email before merging to avoid row explosion.


--------------------------------------------------------------------------------
DATA PROCESSING STEPS
--------------------------------------------------------------------------------

Step 1 — Ingest & Standardise per Source
  - Each source is read with source-specific column mappings
  - Dates are parsed using a multi-format parser (handles DD/MM/YYYY, YYYY-MM-DD, etc.)
  - Payment strings are cleaned (strip "R", commas, whitespace) and cast to float
  - Emails are normalised (strip, lowercase)

Step 2 — Melt XPL Data to Long Format
  - XPL sheets are in wide format (one row per learner, multiple EO groups)
  - pd.wide_to_long() is used to melt into one row per earning opportunity
  - Rows with no payment date are dropped

Step 3 — Concatenate All Sources
  Combined = XPL + Milestone + Partnerships + Launch Lab + Interns + SAP +
             Previous Month Data + Community Team

Step 4 — Deduplication & Cleaning
  - Full-row duplicates are dropped
  - A specific set of known bad row indices is manually dropped
  - Rows with zero payment or missing date are removed
  - Missing earning_opportunity_type values are imputed:
      * "Internship" name → type = "Placement"
      * All others → type = "Experience gig"

Step 5 — Cohort Remapping
  - Raw cohort labels from source sheets are mapped to standardised slug names
    (e.g. "XPL2" → "XA-Jun-25", "C44 - BBD Learnership" → "c44_wd")
  - Slugs are then resolved to full programme names via a database lookup

Step 6 — Demographic Enrichment
  - combined is merged (left join, three passes) against enrichment tables to
    attach: cellphone number, ID number, race, gender, DOB, metro, province,
    disability status, first/last name, learner_id
  - Age at time of service is calculated; learners are bucketed into age ranges:
    17 and below / 18–25 / 26–35 / 36+

Step 7 — Duplicate Check on Demographics
  - Shape of merged frames is asserted to not exceed shape of combined
  - Any umuzi.org emails without a phone number are flagged for review


--------------------------------------------------------------------------------
OUTPUT SHEETS (written to a single Excel file via ExcelWriter)
--------------------------------------------------------------------------------

Sheet: "Learner Demographics"
  One row per learner. Demographic fields only: email, phone, ID number, gender,
  race, residential area type, province, metro, disability status, DOB.

Sheet: "One Per Learner" (singles)
  One row per earning opportunity event, filtered to a specific quarter
  (currently configured for Q4 2025: 2025-10-01 to 2025-12-31).
  Includes learner_id and all EO fields.

Sheet: "Monthly Entries Breakdown" (wide)
  Wide-format pivot. One row per learner+cohort. Columns are grouped by month,
  each month containing: payment, EO type, EO name, EO extra info.

Sheet: "Summarized Opportunities" (result)
  Pivot summary. One row per learner. For each month: total ZAR paid and count
  of gig payments. Months run in financial-year order (April → March, with
  Jan/Feb/Mar trailing).

Sheet: "Earning Opportunities Secured" (breakdown)
  The primary IDC-facing sheet. One row per learner per EO type. Columns include:
  Full Name, ID number, date of first EO, current status, phone, metro, province,
  cohort, programme name, race, gender, EO type, and per-month ZAR value and
  gig count for up to N earning opportunities.
  Current Status is derived from EO type:
    - "Placement" / "SA Local Placements" → "Placement"
    - "Development pathway" / "Impact gig" / "Experience gig" → "Active"

--------------------------------------------------------------------------------
VALIDATION CHECKS
--------------------------------------------------------------------------------

- Shape assertions confirm no row explosion during merges
- Email set differences flag learners in EO data not found in enrichment tables
- A reconciliation check at the end compares total ZAR and gig counts between
  the "Summarized Opportunities" sheet and the "Earning Opportunities Secured"
  sheet for a spot-check month (currently November):
    * Positive difference → someone is missing from the breakdown
    * Negative difference → an extra record snuck into the breakdown

The combined DataFrame is also exported to CSV (line commented out) to serve as
the "previous month" input for the next reporting cycle.


--------------------------------------------------------------------------------
DEPENDENCIES
--------------------------------------------------------------------------------

  - pandas
  - numpy
  - openpyxl          (Excel read/write)
  - connect           (internal module — database connection)
  - retrieve_ids      (internal module — database query helper)


--------------------------------------------------------------------------------
HOW TO RUN
--------------------------------------------------------------------------------

1. Fill in all empty path strings (pathToEnrichmentData, pathToXPLEos, etc.)
   with the correct file paths for the current reporting period.

2. Update the date filter in the "singles" block to match the target quarter.

3. Confirm the cohort remap dictionary (remapCohort) includes any new cohort
   labels introduced in the current period's source data.

4. Set the output path in the ExcelWriter block at the bottom.

5. Run all cells top to bottom.

6. After validating the reconciliation checks, uncomment the combined.to_csv()
   line and re-run that cell to export the rolling dataset for next month.


--------------------------------------------------------------------------------
NOTES
--------------------------------------------------------------------------------

- The month ordering in all pivot outputs follows Umuzi's financial year:
  April (4) through December (12), then January (13), February (14), March (15).

- The SAP team identifies learners by ID number, not email. The merge logic
  joins on id_number from enrichment data to resolve the email.

- The Milestone/Finance sheet also uses ID numbers. A join on rich['id_number']
  resolves these, and the id_number column is dropped from the final frame.

================================================================================