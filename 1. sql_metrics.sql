--Расчет MAU авторов
SELECT main_author_name,    
COUNT(DISTINCT puid) AS mau 
FROM bookmate.author    
JOIN bookmate.content USING (main_author_id) 
JOIN bookmate.audition USING (main_content_id)
  WHERE msk_business_dt_str::date >= '2024-11-01' AND
msk_business_dt_str::date < '2024-12-01'
GROUP BY main_author_name
ORDER BY mau DESC LIMIT 3;

--Расчёт MAU произведений
SELECT main_content_name,
  published_topic_title_list,
  main_author_name,
COUNT(DISTINCT puid) AS mau 
FROM bookmate.author    
JOIN bookmate.content USING (main_author_id) 
JOIN bookmate.audition USING (main_content_id)
WHERE msk_business_dt_str::date >= '2024-11-01' AND
msk_business_dt_str::date < '2024-12-01'
GROUP BY main_content_name,
  published_topic_title_list,
  main_author_name
ORDER BY mau DESC 
LIMIT 3;

--Расчёт Retention Rate
WITH cohort AS (
    SELECT DISTINCT puid
    FROM bookmate.audition
    WHERE msk_business_dt_str::date = DATE '2024-12-02'
),
user_activity AS (
    SELECT
        a.puid,
        a.msk_business_dt_str::date AS event_date
    FROM bookmate.audition a
    JOIN cohort c
        ON a.puid = c.puid
    WHERE a.msk_business_dt_str::date >= DATE '2024-12-02'
),
daily_retention AS (
    SELECT
        event_date - DATE '2024-12-02' AS day_since_install,
        COUNT(DISTINCT puid) AS retained_users
    FROM user_activity
    GROUP BY 1
)
SELECT
    day_since_install,
    retained_users,
    ROUND(
        retained_users * 1.0
        / MAX(retained_users) OVER (),
        2
    ) AS retention_rate
FROM daily_retention
ORDER BY day_since_install;

--Расчёт LTV
WITH user_months AS (
    SELECT
        g.usage_geo_id_name AS city,
        a.puid,
        DATE_TRUNC('month', a.msk_business_dt_str::date) AS month
    FROM bookmate.audition a
    JOIN bookmate.geo g
        ON a.usage_geo_id = g.usage_geo_id
    WHERE g.usage_geo_id_name IN ('Москва', 'Санкт-Петербург')
    GROUP BY 1, 2, 3
),
user_ltv AS (
    SELECT
        city,
        puid,
        COUNT(month) * 399 AS user_revenue
    FROM user_months
    GROUP BY 1, 2
)
SELECT
    city,
    COUNT(DISTINCT puid) AS total_users,
    ROUND(
        SUM(user_revenue) * 1.0 / COUNT(DISTINCT puid),
        2
    ) AS ltv
FROM user_ltv
GROUP BY city;

--Расчёт средней выручки прослушанного часа (средний чек)
WITH sub AS (
  SELECT 
    DATE_TRUNC('month', msk_business_dt_str::date)::date AS month,
    COUNT(DISTINCT puid) AS mau,
    ROUND(SUM(hours), 2) AS hours
  FROM bookmate.audition
  WHERE msk_business_dt_str::date >= '2024-09-01'
    AND msk_business_dt_str::date < '2024-12-01'
  GROUP BY 1
)
SELECT 
  month,
  mau,
  hours,
  ROUND(mau * 399.0 / hours, 2) AS avg_hour_rev
FROM sub
ORDER BY month;
