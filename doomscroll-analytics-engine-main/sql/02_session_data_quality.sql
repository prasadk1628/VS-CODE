-- ============================================================
-- DoomScroll Analytics Engine
-- Session Data Quality Diagnostics
-- ============================================================


-- 1. Check whether event user_id matches session user_id
SELECT
    COUNT(*) AS total_events,
    SUM(
        CASE
            WHEN e.user_id = s.user_id THEN 1
            ELSE 0
        END
    ) AS matching_user_events,
    SUM(
        CASE
            WHEN e.user_id != s.user_id THEN 1
            ELSE 0
        END
    ) AS mismatched_user_events
FROM events e
JOIN sessions s
    ON e.session_id = s.session_id;


-- 2. Check whether event timestamps fall inside the session window
SELECT
    COUNT(*) AS total_events,
    SUM(
        CASE
            WHEN datetime(e.timestamp)
                 BETWEEN datetime(s.session_start)
                 AND datetime(s.session_end)
            THEN 1
            ELSE 0
        END
    ) AS events_inside_session,
    SUM(
        CASE
            WHEN datetime(e.timestamp)
                 NOT BETWEEN datetime(s.session_start)
                 AND datetime(s.session_end)
            THEN 1
            ELSE 0
        END
    ) AS events_outside_session
FROM events e
JOIN sessions s
    ON e.session_id = s.session_id;


-- 3. Check sessions that have no events
SELECT
    COUNT(*) AS sessions_without_events
FROM sessions s
LEFT JOIN events e
    ON s.session_id = e.session_id
WHERE e.session_id IS NULL;


-- 4. Check sessions where event user IDs are inconsistent
SELECT
    s.session_id,
    s.user_id AS session_user_id,
    COUNT(DISTINCT e.user_id) AS distinct_event_users
FROM sessions s
JOIN events e
    ON s.session_id = e.session_id
GROUP BY
    s.session_id,
    s.user_id
HAVING COUNT(DISTINCT e.user_id) > 1
ORDER BY distinct_event_users DESC
LIMIT 20;


-- 5. Check how many sessions have events outside their
--    declared session time window
SELECT
    COUNT(DISTINCT s.session_id) AS affected_sessions
FROM sessions s
JOIN events e
    ON s.session_id = e.session_id
WHERE datetime(e.timestamp)
      NOT BETWEEN datetime(s.session_start)
      AND datetime(s.session_end);


-- 6. Inspect a few problematic sessions
SELECT
    s.session_id,
    s.user_id AS session_user_id,
    s.session_start,
    s.session_end,
    e.user_id AS event_user_id,
    e.timestamp AS event_timestamp,
    e.event_type
FROM sessions s
JOIN events e
    ON s.session_id = e.session_id
WHERE e.user_id != s.user_id
   OR datetime(e.timestamp)
      NOT BETWEEN datetime(s.session_start)
      AND datetime(s.session_end)
LIMIT 20;
