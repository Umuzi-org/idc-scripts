================================================================================
README: IDC Reporting Repository
Umuzi Data Team
================================================================================

This repository contains all scripts, queries, and notebooks used to produce
Umuzi's quarterly IDC (Industrial Development Corporation) impact report. It is
the single source of truth for the technical reporting pipeline and is designed
to be runnable, understandable, and maintainable by anyone on the data team —
without needing to track down the original author.

The repository is organised into three folders, each corresponding to a distinct
phase of the reporting pipeline. They should be run in the order listed below.


--------------------------------------------------------------------------------
REPOSITORY STRUCTURE
--------------------------------------------------------------------------------

idc-scripts/
├── earning/          Notebook for consolidating Earning Opportunities (EO) data
├── support/          Notebooks for consolidating Support Services data
└── consolidate/      Final assembly: combines all outputs into the IDC report


--------------------------------------------------------------------------------
FOLDER: earning/
--------------------------------------------------------------------------------

PURPOSE
  Consolidates earning opportunity data from six internal Umuzi teams into a
  single enriched output for the IDC report. An earning opportunity is any
  instance in which Umuzi has connected a learner to a paid engagement — a gig,
  placement, stipend, or freelance contract.

NOTEBOOK
  eos.ipynb

INPUTS

- Excel/CSV trackers from: XPL/Natalie, Milestone/Finance, Partnerships,
    Launch Lab, Community Team, SAP Team, and Umuzi Interns
- Previous cycle's rolling CSV (exported at the end of the prior run)
- Enrichment CSV generated from support/populate_fields.sql

OUTPUTS (written to IDC Report Consolidated.xlsx)

- Learner Demographics
- One Per Learner
- Monthly Entries Breakdown
- Summarized Opportunities
- Earning Opportunities Secured

README
  See earning/README.txt for full documentation of inputs, pipeline steps,
  output schemas, and the per-cycle run checklist.

RUN ORDER
  Run this folder's notebook before consolidate/. It can be run independently
  of the support/ folder — both write to the same output Excel file in
  append/replace mode, so order between the two does not matter. If you can, hold off on writing the output till you're done with the consolidate folder.

--------------------------------------------------------------------------------
FOLDER: support/
--------------------------------------------------------------------------------

PURPOSE
  Consolidates support services data from multiple sources into a single
  indicator_7_data.csv file, which is then used by the consolidation step.
  A support service is any intervention Umuzi provides beyond direct earning
  opportunities — coaching sessions, learning platform access, exam prep,
  onboarding, CV assistance, and more.

NOTEBOOKS & SCRIPTS
  Each source has its own notebook or query:

  Source                    File                        Data owner / origin
  ------------------------  --------------------------  ----------------------
  Coursera completions      coursera_extraction.ipynb   Kennedy Kinyua (export)
  LX Coach check-ins        lxcheckins.ipynb            LX team (Excel tracker)
  Launch Lab sessions       placements.ipynb            Launch Lab team (Excel)
  SAP support services      sap.ipynb                   SAP team (Excel tracker)
  Database services         idc_indicator_7.sql         Data team (DB query)
  Enrichment table          populate_fields.sql         Data team (DB query)

INPUTS

- Source-specific Excel files or compressed exports (see individual READMEs)
- Enrichment CSV from populate_fields.sql (shared across all notebooks)

OUTPUTS

- indicator_7_data.csv (Sink Datasets) — each notebook appends to this file
- indicator_7_sap_support_services.csv — standalone SAP export (optional)
- indicator_7_coursera.csv — standalone Coursera export (optional)
- indicator_7_lxcheckins.csv — standalone LX check-ins export (optional)
- indicator_7_placements.csv — standalone Launch Lab export (optional)

IMPORTANT NOTES

- All notebooks must be run before the consolidation step.
- Each notebook appends to indicator_7_data.csv in Sink Datasets. Confirm
    the file exists and is from the correct cycle before running.
- SAP learners are identified by personal email, not Umuzi email. The
    enrichment table must be up to date before running sap.ipynb.
- The Coursera and LX check-ins notebooks have a hardcoded year in the
    month_of_service_accessed field — update before running for a new
    calendar year.
- See each notebook's section in the SLAB documentation for full details,
    quirks, and per-source run checklists.

RUN ORDER

  1. Run populate_fields.sql and export the enrichment CSV first.
  2. Run idc_indicator_7.sql and export the database services CSV.
  3. Run all four Python notebooks in any order, confirming each appends
     successfully to indicator_7_data.csv.
  4. Proceed to consolidate/.

--------------------------------------------------------------------------------
FOLDER: consolidate/
--------------------------------------------------------------------------------

PURPOSE
  The final step. Reads all upstream outputs — Indicator 5 from the database,
  the rolling Indicator 7 support services CSV, and the enrichment table —
  and produces the complete IDC Report Consolidated.xlsx file. Also derives
  Indicator 6 (unique learner headcount across all support services).

NOTEBOOK
  indicators.ipynb

INPUTS

- Enrichment CSV (from support/populate_fields.sql)
- Indicator 5 CSV (from idc_indicator_5.sql)
- indicator_7_data.csv — current cycle (from support/)
- indicator_7_data.csv — previous cycle (from prior reporting period)
- Database Indicator 7 CSV (from support/idc_indicator_7.sql)

OUTPUTS (written to IDC Report Consolidated.xlsx)

- Indicator 5   — Registered unemployed SA youth (one row per applicant)
- Indicator 6   — Unique individuals who accessed a support service
- Indicator 7   — All support service interactions (full granular detail)
- Support Participants List — Demographic summary for IDC submission

NOTE
  The previous cycle file path is currently hardcoded in the notebook.
  Update it to point to the correct prior cycle folder before running.
  This path should not reference a local machine — store the previous
  cycle's file in a shared location accessible to the full data team.

RUN ORDER
  Run last, after both earning/ and support/ are complete. Both pipelines
  write to the same IDC Report Consolidated.xlsx — confirm all expected
  sheets are present before distributing the final file.

--------------------------------------------------------------------------------
END-TO-END RUN ORDER (each reporting cycle)
--------------------------------------------------------------------------------

  STEP 1 — DATABASE QUERIES (queries/)
    a. Run populate_fields.sql → export enrichment CSV
    b. Run idc_indicator_5.sql → export Indicator 5 CSV
    c. Run idc_indicator_7.sql → export database Indicator 7 CSV
    d. Distribute the enrichment CSV to anyone running Python notebooks

  STEP 2 — SUPPORT SERVICES NOTEBOOKS (support/)
    Run all four notebooks. Each appends to indicator_7_data.csv.
    a. coursera_extraction.ipynb
    b. lxcheckins.ipynb
    c. placements.ipynb
    d. sap.ipynb

  STEP 3 — EARNING OPPORTUNITIES (earning/)
    Run eos.ipynb. Writes its sheets to IDC Report Consolidated.xlsx.

  STEP 4 — FINAL CONSOLIDATION (consolidate/)
    Run indicators.ipynb. Writes Indicator 5, 6, 7, and Participants List
    to IDC Report Consolidated.xlsx.

  STEP 5 — VALIDATE & DISTRIBUTE
    Confirm all expected sheets are present in IDC Report Consolidated.xlsx.
    Review any null name fields flagged by indicators.ipynb.
    Run the EOS reconciliation checks before sharing.

--------------------------------------------------------------------------------
SHARED DEPENDENCIES
--------------------------------------------------------------------------------

  Python packages:  pandas, numpy, openpyxl, pathlib
  SQL database:     Umuzi production database (PostgreSQL)
  Enrichment CSV:   Generated fresh each cycle from populate_fields.sql
  Sink Datasets:    A folder (not committed to the repo) where all intermediate
                    CSVs are written. Its location should be consistent across
                    the team — agree on a shared path or drive location.

  All file paths in the notebooks are left blank by default and must be set
  before running. Do not commit populated paths to the repository, especially
  paths that reference local machines or sensitive locations.

--------------------------------------------------------------------------------
FURTHER READING
--------------------------------------------------------------------------------

  earning/README.md        — Full EOS pipeline documentation
  SLAB (internal)           — Complete technical SOP with pipeline diagrams,
                              per-source documentation, SQL query explanations,
                              and maintenance guidance for all scripts

================================================================================