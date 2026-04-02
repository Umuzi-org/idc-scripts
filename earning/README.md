# Create the README content as a markdown file

## Overview

This notebook constructs two core reporting views from raw earning opportunity data:

1. **Result Dataset (Summary Layer)**  
   Aggregated payments and counts per learner per month.

2. **Breakdown Dataset (Analytical Layer)**  
   A structured decomposition of payments by:
   - Earning Opportunity Type  
   - Individual Earning Opportunities (ranked per learner/type)  
   - Month  

The purpose of this pipeline is to ensure **traceability between granular earning events and summarized reporting outputs**, while maintaining **auditability at each transformation step**.

---

## Data Flow Architecture

The pipeline follows a deterministic sequence of transformations:

```
Raw Combined Data  
↓  
Data Cleaning & Normalization  
↓  
Earning Opportunity Ranking (op_num assignment)  
↓  
Pivot Preparation (grouped aggregates)  
↓  
Breakdown Pivot (wide format)  
↓  
Demographic Enrichment  
↓  
Final Breakdown Output  

Parallel to this:

Raw Combined Data  
↓  
GroupBy Aggregation (per learner, per month)  
↓  
Pivot (wide monthly summary)  
↓  
Final Result Output  
```

---

## Key Concepts

### 1. Grain Definitions

| Dataset     | Grain |
|------------|------|
| combined   | One row per earning event |
| result     | One row per learner aggregated by months |
| breakdown  | One row per learner × earning_opportunity_type |

Understanding grain differences is critical when reconciling discrepancies.

---

### 2. op_num (Earning Opportunity Indexing)

Each unique combination of:

- umuzi_email
- earning_opportunity_type
- earning_opportunity_name

is assigned an ordinal:

```op_num = cumcount() + 1```

This represents:
The chronological order in which a learner accessed opportunities within a type.

Important Properties:

- Deterministic ordering is enforced via:
  ```sort_values(['first_eon_date', 'earning_opportunity_name'])```
- op_num is required for pivoting into wide format
- Missing op_num results in data loss during pivot(this will show up when monthly totals in *result* are different than those in *breakdown*)

---

### 3. Pivot Mechanics (Critical Behavior)

The breakdown uses a pivot_table with:

- index: learner + type + cohort
- columns: month and op_num
- values: amount and gigs

Important:

- Rows with NULL in pivot keys (e.g. op_num) are excluded
- This is a primary source of discrepancies if upstream data is incomplete

---

## Known Failure Modes

### 1. Missing earning_opportunity_type

If null:

- Fails to join with ranking table
- op_num becomes NULL
- Row is dropped during pivot

Mitigation:

- Impute missing types prior to ranking
- Track imputed records explicitly

---

### 2. Inconsistent Text Fields

Fields such as:

- umuzi_email
- earning_opportunity_name
- earning_opportunity_type

must be normalized:

```.strip().str.lower().str.normalize('NFKC')```

Failure to do so leads to:

- Broken joins
- Duplicate logical entities
- Missing op_num assignments

---

### 3. Grain Mismatch Between Outputs

- result aggregates at (umuzi_email, month)
- breakdown expands into (umuzi_email, type, op_num, month)

Discrepancies are expected unless reconciled at the same grain.

---

## Reconciliation Framework

Step 1: Compute counts from raw data  
```combined.groupby(['umuzi_email', 'month']).size()```

Step 2: Compute counts from breakdown (pre-pivot)  
```pivotData[pivotData['op_num'].notna()].groupby(['umuzi_email', 'month']).size()```

Step 3: Compare  
```diff = result_count - breakdown_count```

Expected Condition:  
```diff == 0``` for all months

Any deviation indicates:

- Dropped rows
- Incorrect grouping
- Missing metadata

---

## Demographic Enrichment Strategy

Demographics are sourced from:

- rich
- richFields (email-based)
- richFields (umuzi_email-based)

Priority is applied via sequential merging.

### Deduplication Logic

drop_duplicates on:

- umuzi_email
- earning_opportunity_extra_info
- earning_opportunity_type
- earning_opportunity_name
- date_service_accessed
- payment

This ensures:

- No duplicate earning events
- Preservation of unique transactional records

---

## Audit Strategy

The notebook is designed for interactive validation.

Recommended checks:

- Row counts
- Unique learner counts
- Null checks
- Sample inspection

Mandatory checks:

1. No missing earning_opportunity_type
2. No missing op_num
3. Reconciliation diff == 0
4. Total payment consistency:
   combined['payment'].sum() == pivotData['payment'].sum()

---

## Output Structure

### Result Dataset

Columns:

- umuzi_email
- Month (Payment)
- Month (Count)

---

### Breakdown Dataset

Includes:

- Learner metadata
- Earning opportunity type
- Monthly columns:
  - Earning Opportunity X ZAR Value (Month)
  - No. of Gig X (Month)

---

## Design Trade-offs

- Wide format output for reporting
- op_num indexing for structured pivoting
- Notebook-based workflow for auditability
- Sequential enrichment for maximum data recovery

---

## Future Improvements

- Automated reconciliation reporting
- Tracking imputed records
- Pre-pivot validation gates
- Stabilized ranking under backfills

---

## Final Notes

This pipeline assumes:

- Source data is append-only or minimally mutable
- Earning opportunity definitions remain stable

If reconciliation fails, do not trust the outputs. Investigate upstream.