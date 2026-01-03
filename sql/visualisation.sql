SELECT 
    estimated_income_code, 
    COUNT(agrid20) AS consumer_count
FROM Demographics
WHERE estimated_income_code IS NOT NULL
GROUP BY estimated_income_code
ORDER BY estimated_income_code;


SELECT 
    TRUNC(activity_timestamp, 'MONTH') AS activity_date, 
    COUNT(activity_id) AS total_visits
FROM WebActivity
GROUP BY 1
ORDER BY 1;


SELECT 
    CASE 
        WHEN d.device_type = 'IDFA' THEN 'Apple'
        WHEN d.device_type = 'GAID' THEN 'Android'
        ELSE 'Other' 
    END AS device_brand, 
    COUNT(w.activity_id) AS session_count
FROM WebActivity w
JOIN Devices d ON w.device_id = d.device_id
GROUP BY 1;

SELECT 
    state, 
    COUNT(agrid20) AS resident_count
FROM Addresses
GROUP BY state
ORDER BY resident_count DESC
LIMIT 10;


SELECT 
    city,
    state,
    COUNT(agrid20) AS resident_count
FROM Addresses
GROUP BY city, state
ORDER BY resident_count DESC
LIMIT 10;