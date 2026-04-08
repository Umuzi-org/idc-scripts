-- CREATE OR REPLACE VIEW applications_to_use AS
-- WITH LatestAcceptedApplication AS (
--   SELECT DISTINCT ON (aps.learner_id)
--     aps.*
--   FROM applications aps
--   JOIN application_status apss 
--     ON apss.id = aps.application_status_id
--   WHERE apss.staus = 'Accepted'
--   ORDER BY aps.learner_id, aps.date_created DESC
-- ),

-- LatestApplication AS (
--   SELECT DISTINCT ON (aps.learner_id)
--     aps.*
--   FROM applications aps
--   WHERE aps.application_status_id IS NOT NULL
--   ORDER BY aps.learner_id, aps.date_created DESC
-- )

-- SELECT * 
-- FROM LatestAcceptedApplication

-- UNION ALL

-- SELECT la.* 
-- FROM LatestApplication la
-- WHERE NOT EXISTS (
--   SELECT 1 
--   FROM LatestAcceptedApplication acc
--   WHERE acc.learner_id = la.learner_id
-- );


-- Bootcamp service pipeline
WITH bootcamp_services AS (
  SELECT
    ll.id AS learner_id,
    la.id AS application_id,
    bs.start_date AS date_service_accessed,
    COALESCE(ll.umuzi_email, ll.email) AS umuzi_email,
    ll.first_name,
    ll.last_name,
    ll.cellphone_number,
    ll.id_number,
    ll.gender,
    ll.date_of_birth,
    EXTRACT(YEAR FROM AGE(bs.start_date, ll.date_of_birth)) AS age_service_accessed,
    ll.race,
    lrat.name AS residential_area_type,
    ll.has_disability_or_differently_abled,
    COALESCE(la.registration_date, la.date_updated) AS application_date,
    TO_CHAR(bs.start_date, 'Month YYYY') AS month_of_service_accessed,
    CASE
      WHEN AGE(lbs.rsvp_date, ll.date_of_birth) < INTERVAL '18 years' THEN '17 and below'
      WHEN AGE(lbs.rsvp_date, ll.date_of_birth) < INTERVAL '26 years' THEN '18-25'
      WHEN AGE(lbs.rsvp_date, ll.date_of_birth) < INTERVAL '36 years' THEN '26-35'
      WHEN AGE(lbs.rsvp_date, ll.date_of_birth) < INTERVAL '51 years' THEN '36-50'
      ELSE 'Over 50'
    END AS age_range, -- age at time of service
    cities.name AS nearest_metro,
    provinces.name AS province,
    'bootcamp' AS service_used,
    b.bootcamp_name || '-bootcamp' AS service_name
    
  FROM (
      SELECT * FROM learners_bootcamps_slots
      WHERE bootcamp_result_id = 2
        UNION ALL
      SELECT * FROM learners_bootcamps_slots
      WHERE bootcamp_result_id = 1 AND rejection_reason_id IS NOT NULL
  ) lbs
  JOIN learners ll ON ll.id = lbs.learner_id
  JOIN bootcamps_slots bs ON bs.id = lbs.bootcamp_slot_id
  JOIN bootcamp b ON b.id = bs.bootcamp_id
  LEFT JOIN applications_to_use la ON la.learner_id = ll.id
  LEFT JOIN learner_miscellaneous_information lmi ON lmi.learner_id = ll.id
  LEFT JOIN lookup_residential_area_type lrat ON lmi.residential_area_type_id = lrat.id
  LEFT JOIN cities ON cities.id = ll.nearest_city::integer
  LEFT JOIN provinces ON provinces.id = ll.province::integer
  WHERE lbs.rsvp_date >= '2025-04-01'
  AND (ll.is_south_african_citizen = TRUE OR ll.nationality='South African')
  AND ll.is_currently_employed = FALSE
  AND ll.test_account = FALSE
)
-- Programme enrolment pipeline
,programme_services AS (
  SELECT
    ll.id AS learner_id,
    la.id AS application_id,
    p.start_date AS date_service_accessed,
    COALESCE(ll.umuzi_email, ll.email) AS umuzi_email,
    ll.first_name,
    ll.last_name,
    ll.cellphone_number,
    ll.id_number,
    ll.gender,
    ll.date_of_birth,
    EXTRACT(YEAR FROM AGE(p.start_date, ll.date_of_birth)) AS age_service_accessed,
    ll.race,
    lrat.name AS residential_area_type,
    ll.has_disability_or_differently_abled,
    COALESCE(la.registration_date, la.date_updated) AS application_date,
    TO_CHAR(p.start_date, 'Month YYYY') AS month_of_service_accessed,
    CASE
      WHEN AGE(p.start_date, ll.date_of_birth) < INTERVAL '18 years' THEN '17 and below'
      WHEN AGE(p.start_date, ll.date_of_birth) < INTERVAL '26 years' THEN '18-25'
      WHEN AGE(p.start_date, ll.date_of_birth) < INTERVAL '36 years' THEN '26-35'
      WHEN AGE(p.start_date, ll.date_of_birth) < INTERVAL '51 years' THEN '36-50'
      ELSE 'Over 50'
    END AS age_range, -- age at time of service
    cities.name AS nearest_metro,
    provinces.name AS province,
    'programme enrollment' AS service_used,
    p.name AS service_name
  FROM learners_programmes_pathways lpp
  JOIN programmes p ON p.id = lpp.programmes_id
  JOIN learners ll ON ll.id = lpp.learner_id
  LEFT JOIN applications_to_use la ON la.learner_id = ll.id
  LEFT JOIN learner_miscellaneous_information lmi ON lmi.learner_id = ll.id
  LEFT JOIN lookup_residential_area_type lrat ON lmi.residential_area_type_id = lrat.id
  LEFT JOIN cities ON cities.id = ll.nearest_city::integer
  LEFT JOIN provinces ON provinces.id = ll.province::integer
  WHERE (p.start_date >= '2025-04-01' OR p.start_date IS NULL)
  AND p.name NOT ILIKE '%Accenture%' -- already counted in it's own CTE
  AND (ll.is_south_african_citizen = TRUE OR ll.nationality='South African')
  AND ll.is_currently_employed = FALSE
  AND ll.test_account = FALSE
)
-- Accenture mini-course pipeline
,accenture_services AS (
  SELECT
    ll.id AS learner_id,
    la.id AS application_id,
    MAX(lcc.certificate_uploaded_at) AS date_service_accessed, -- earliest verified upload per learner/course
    COALESCE(ll.umuzi_email, ll.email) AS umuzi_email,
    ll.first_name,
    ll.last_name,
    ll.cellphone_number,
    ll.id_number,
    ll.gender,
    ll.date_of_birth,
    EXTRACT(YEAR FROM AGE(lcc.certificate_uploaded_at, ll.date_of_birth)) AS age_service_accessed,
    ll.race,
    lrat.name AS residential_area_type,
    ll.has_disability_or_differently_abled,
    COALESCE(la.registration_date, la.date_updated) AS application_date,
    TO_CHAR(MIN(lcc.certificate_uploaded_at), 'Month YYYY') AS month_of_service_accessed,
    CASE
      WHEN AGE(MIN(lcc.certificate_uploaded_at), ll.date_of_birth) < INTERVAL '18 years' THEN '17 and below'
      WHEN AGE(MIN(lcc.certificate_uploaded_at), ll.date_of_birth) < INTERVAL '26 years' THEN '18-25'
      WHEN AGE(MIN(lcc.certificate_uploaded_at), ll.date_of_birth) < INTERVAL '36 years' THEN '26-35'
      WHEN AGE(MIN(lcc.certificate_uploaded_at), ll.date_of_birth) < INTERVAL '51 years' THEN '36-50'
      ELSE 'Over 50'
    END AS age_range,
    cities.name AS nearest_metro,
    provinces.name AS province,
    c.name::TEXT AS service_used,
    STRING_AGG(DISTINCT pw.name, ', ') AS service_name
  FROM learners_courses_certificates lcc
  JOIN courses c ON c.id = lcc.course_id
  JOIN learners ll ON ll.id = lcc.learner_id
  JOIN pathways_courses pc ON pc.course_id = lcc.course_id
  JOIN pathways pw ON pw.id = pc.pathway_id
  LEFT JOIN applications_to_use la ON la.learner_id = ll.id
  LEFT JOIN learner_miscellaneous_information lmi ON lmi.learner_id = ll.id
  LEFT JOIN lookup_residential_area_type lrat ON lmi.residential_area_type_id = lrat.id
  LEFT JOIN cities ON cities.id = ll.nearest_city::integer
  LEFT JOIN provinces ON provinces.id = ll.province::integer
  WHERE lcc.certificate_uploaded_at >= '2025-04-01'
    AND (ll.nationality = 'South African' OR ll.is_south_african_citizen=TRUE)
    AND ll.is_currently_employed = FALSE
    AND ll.test_account = FALSE
  GROUP BY 
    ll.id, la.id, COALESCE(ll.umuzi_email, ll.email), ll.first_name, ll.last_name, ll.cellphone_number, 
    ll.id_number, ll.gender, ll.date_of_birth, ll.race, lrat.name,
    ll.has_disability_or_differently_abled, la.registration_date, la.date_updated,
    cities.name, provinces.name, c.name, EXTRACT(YEAR FROM AGE(lcc.certificate_uploaded_at, ll.date_of_birth))
)
-- Final result set
, all_services AS(
SELECT * FROM bootcamp_services
UNION ALL
SELECT * FROM programme_services
UNION ALL
SELECT * FROM accenture_services
ORDER BY learner_id, service_name NULLS FIRST)

SELECT *
FROM  all_services
ORDER BY learner_id NULLS FIRST;  -- OR by service_used, date, etc.