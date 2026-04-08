CREATE OR REPLACE VIEW applications_to_use AS
WITH LatestAcceptedApplication AS (
  SELECT DISTINCT ON (aps.learner_id)
    aps.*
  FROM applications aps
  JOIN application_status apss 
    ON apss.id = aps.application_status_id
  WHERE apss.staus = 'Accepted'
  ORDER BY aps.learner_id, aps.date_created DESC
),

LatestApplication AS (
  SELECT DISTINCT ON (aps.learner_id)
    aps.*
  FROM applications aps
  WHERE aps.application_status_id IS NOT NULL
  ORDER BY aps.learner_id, aps.date_created DESC
)

SELECT * 
FROM LatestAcceptedApplication

UNION ALL

SELECT la.* 
FROM LatestApplication la
WHERE NOT EXISTS (
  SELECT 1 
  FROM LatestAcceptedApplication acc
  WHERE acc.learner_id = la.learner_id
);

SELECT 
    ll.id AS learner_id,
    la.id AS application_id,
    la.date_updated AS application_date,
    TO_CHAR(la.date_updated, 'Month YYYY') AS month_of_registration,
    ll.email,
    ll.first_name,
    ll.last_name,
    ll.cellphone_number,
    
    
    ll.id_number,
    ll.gender,
    ll.date_of_birth,
    EXTRACT(YEAR FROM AGE(la.date_updated, ll.date_of_birth)) AS age_at_application,
    ll.has_disability_or_differently_abled,
    CASE
        WHEN AGE(la.date_updated, ll.date_of_birth) < INTERVAL '18 years' THEN '17 and below'
        WHEN AGE(la.date_updated, ll.date_of_birth) < INTERVAL '26 years' THEN '18-25'
        WHEN AGE(la.date_updated, ll.date_of_birth) < INTERVAL '36 years' THEN '26-35'
        WHEN AGE(la.date_updated, ll.date_of_birth) < INTERVAL '51 years' THEN '36-50'
        ELSE 'Over 50'
    END AS age_range,
    cities.name AS nearest_metro,
    provinces.name AS province,
    lrat.name AS residential_area_type,
    ll.race
    

FROM applications_to_use la
LEFT JOIN learners ll ON la.learner_id = ll.id
LEFT JOIN cities ON cities.id = ll.nearest_city::int
LEFT JOIN learner_miscellaneous_information lmi ON lmi.learner_id = ll.id
LEFT JOIN lookup_residential_area_type lrat ON lmi.residential_area_type_id = lrat.id
LEFT JOIN provinces ON provinces.id = ll.province::int
    WHERE ll.is_south_african_citizen = TRUE
    AND SUBSTRING(ll.id_number FROM 11 FOR 1) = '0'
    AND ll.is_currently_employed = FALSE
    AND la.date_updated >= '2025-04-01'::date
    AND ll.test_account = FALSE

ORDER BY application_date ASC