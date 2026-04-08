-- CREATE TEMP TABLE applications_to_use AS
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

SELECT 
    ll.id AS learner_id,
    la.id AS application_id,
    COALESCE(la.registration_date, la.date_updated) AS application_date,
    TO_CHAR(COALESCE(la.registration_date, la.date_updated), 'Month YYYY') AS month_of_registration,
    ll.email,
    COALESCE(ll.umuzi_email, ll.email) as umuzi_email,
    ll.first_name,
    ll.last_name,
    ll.cellphone_number,
    ll.id_number,
    ll.race,
    ll.gender,
    ll.date_of_birth,
    ll.has_disability_or_differently_abled,
    cities.name AS nearest_metro,
    provinces.name AS province,
    lrat.name AS residential_area_type
FROM learners ll
LEFT JOIN applications_to_use la ON la.learner_id = ll.id
LEFT JOIN learner_miscellaneous_information lmi ON lmi.learner_id = ll.id
LEFT JOIN lookup_residential_area_type lrat ON lmi.residential_area_type_id = lrat.id
LEFT JOIN cities ON cities.id = ll.nearest_city::integer
LEFT JOIN provinces ON provinces.id = ll.province::integer
WHERE 1=1
    AND TRIM(LOWER(ll.umuzi_email)) IN ()
    AND ll.test_account = FALSE
    AND (ll.is_south_african_citizen = true OR ll.nationality='South African')
    ;