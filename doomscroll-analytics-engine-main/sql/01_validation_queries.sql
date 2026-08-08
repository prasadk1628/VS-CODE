SELECT 'users' AS table_name, COUNT(*) AS row_count
FROM users

UNION ALL

SELECT 'content', COUNT(*)
FROM content

UNION ALL

SELECT 'sessions', COUNT(*)
FROM sessions

UNION ALL

SELECT 'events', COUNT(*)
FROM events;

SELECT
    event_type,
    COUNT(*) AS total_events
FROM events
GROUP BY event_type
ORDER BY total_events DESC;

SELECT
    persona,
    COUNT(*) AS total_users
FROM users
GROUP BY persona;

SELECT
    u.persona,
    ROUND(AVG(s.session_duration_minutes), 2)
        AS avg_session_duration
FROM sessions s
JOIN users u
    ON s.user_id = u.user_id
GROUP BY u.persona
ORDER BY avg_session_duration DESC;

SELECT
    c.category,
    COUNT(*) AS total_views
FROM events e
JOIN content c
    ON e.content_id = c.content_id
WHERE e.event_type = 'watch'
GROUP BY c.category
ORDER BY total_views DESC;

SELECT
    u.persona,

    ROUND(
        SUM(
            CASE
                WHEN e.event_type = 'like'
                THEN 1
                ELSE 0
            END
        ) * 1.0
        / COUNT(*),
        4
    ) AS engagement_rate

FROM events e

JOIN users u
ON e.user_id = u.user_id

GROUP BY u.persona

ORDER BY engagement_rate DESC;

SELECT
    session_id,
    COUNT(*) AS events_in_session
FROM events
GROUP BY session_id
ORDER BY events_in_session DESC
LIMIT 10;

SELECT
    STRFTIME('%H', timestamp) AS hour,
    COUNT(*) AS total_events
FROM events
GROUP BY hour
ORDER BY total_events DESC;