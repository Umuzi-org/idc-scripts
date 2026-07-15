-- ============================================================
-- applications_to_use view (simplified)
-- Single DISTINCT ON with a priority sort:
--   1. Accepted applications win
--   2. Ties broken by most recent date_created
-- NOTE: apss.staus is the actual production column name
-- (schema-level misspelling) -- kept as-is deliberately.
-- ============================================================
CREATE OR REPLACE VIEW applications_to_use AS
SELECT DISTINCT ON (aps.learner_id)
  aps.*
FROM applications aps
JOIN application_status apss ON apss.id = aps.application_status_id
ORDER BY
  aps.learner_id,
  (apss.staus = 'Accepted') DESC,  -- accepted first
  aps.date_created DESC;           -- then most recent


-- ============================================================
-- IDC Indicator 5: applications/registrations
-- Date anchor: COALESCE(registration_date, date_created).
-- Both are stable; date_updated is excluded from the chain
-- because it drifts on every row edit and would move learners
-- between reporting months across report runs.
-- ============================================================
WITH params AS (
  SELECT DATE '2026-04-01' AS cutoff
),

applications_dated AS (
  SELECT
    la.*,
    COALESCE(la.registration_date, la.date_created) AS application_date
  FROM applications_to_use la
)

SELECT
  ll.id AS learner_id,
  la.id AS application_id,
  la.application_date,
  TO_CHAR(la.application_date, 'Month YYYY') AS month_of_registration,
  ll.email,
  ll.first_name,
  ll.last_name,
  ll.cellphone_number,
  ll.id_number,
  ll.gender,
  ll.date_of_birth,
  EXTRACT(YEAR FROM AGE(la.application_date, ll.date_of_birth)) AS age_at_application,
  ll.has_disability_or_differently_abled,
  CASE
    WHEN la.application_date IS NULL
      OR ll.date_of_birth IS NULL THEN 'Unknown'
    WHEN AGE(la.application_date, ll.date_of_birth) < INTERVAL '18 years' THEN '17 and below'
    WHEN AGE(la.application_date, ll.date_of_birth) < INTERVAL '26 years' THEN '18-25'
    WHEN AGE(la.application_date, ll.date_of_birth) < INTERVAL '36 years' THEN '26-35'
    WHEN AGE(la.application_date, ll.date_of_birth) < INTERVAL '51 years' THEN '36-50'
    ELSE 'Over 50'
  END AS age_range,
  cities.name AS nearest_metro,
  provinces.name AS province,
  lrat.name AS residential_area_type,
  ll.race

FROM applications_dated la
JOIN learners ll ON ll.id = la.learner_id
LEFT JOIN learner_miscellaneous_information lmi ON lmi.learner_id = ll.id
LEFT JOIN lookup_residential_area_type lrat ON lrat.id = lmi.residential_area_type_id
-- Align casts with confirmed column types (post-btrim-error check):
-- drop ::int if the column is already integer.
LEFT JOIN cities    ON cities.id    = ll.nearest_city::int
LEFT JOIN provinces ON provinces.id = ll.province::int

WHERE
  -- Canonical SA citizenship test (share this with indicator 7):
  -- a valid 13-digit ID is authoritative; self-reported signals
  -- only apply when no usable ID exists. Learners with a valid
  -- ID showing digit '1' (permanent resident) are EXCLUDED --
  -- confirm with funder whether PRs count before finalizing.
  (
    (TRIM(ll.id_number) ~ '^\d{13}$'
     AND SUBSTRING(TRIM(ll.id_number) FROM 11 FOR 1) = '0')
    OR
    ((ll.id_number IS NULL OR TRIM(ll.id_number) !~ '^\d{13}$')
     AND (ll.is_south_african_citizen = TRUE OR ll.nationality = 'South African'))
  )
  AND ll.is_currently_employed = FALSE
  AND ll.test_account = FALSE
  AND la.application_date >= (SELECT cutoff FROM params)

ORDER BY la.application_date ASC;