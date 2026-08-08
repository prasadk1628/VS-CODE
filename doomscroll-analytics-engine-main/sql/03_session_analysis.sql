-- ============================================================
-- DoomScroll Analytics Engine
-- 02 - Session Behavioral Analysis
-- ============================================================


-- ============================================================
-- 1. SESSION DEPTH
-- How many behavioral events occur in each session?
-- ============================================================

SELECT
    s.session_id,
    s.user_id,
    s.persona,
    s.session_duration_minutes,

    COUNT(e.event_id) AS total_events,

    SUM(
        CASE
            WHEN e.event_type = 'watch'
            THEN 1
            ELSE 0
        END
    ) AS watch_events,

    SUM(
        CASE
            WHEN e.event_type = 'like'
            THEN 1
            ELSE 0
        END
    ) AS likes

FROM sessions s
LEFT JOIN events e
    ON s.session_id = e.session_id

GROUP BY
    s.session_id,
    s.user_id,
    s.persona,
    s.session_duration_minutes

ORDER BY total_events DESC
LIMIT 20;


-- ============================================================
-- 2. AVERAGE SESSION DEPTH BY PERSONA
-- ============================================================

SELECT
    s.persona,

    COUNT(DISTINCT s.session_id) AS sessions,

    ROUND(
        AVG(event_counts.total_events),
        2
    ) AS avg_events_per_session,

    ROUND(
        AVG(event_counts.watch_events),
        2
    ) AS avg_watch_events_per_session,

    ROUND(
        AVG(event_counts.likes),
        2
    ) AS avg_likes_per_session

FROM sessions s

JOIN (
    SELECT
        session_id,

        COUNT(*) AS total_events,

        SUM(
            CASE
                WHEN event_type = 'watch'
                THEN 1
                ELSE 0
            END
        ) AS watch_events,

        SUM(
            CASE
                WHEN event_type = 'like'
                THEN 1
                ELSE 0
            END
        ) AS likes

    FROM events

    GROUP BY session_id
) event_counts

    ON s.session_id = event_counts.session_id

GROUP BY s.persona

ORDER BY avg_events_per_session DESC;


-- ============================================================
-- 3. EVENT DENSITY
-- How many events occur per minute?
-- ============================================================

SELECT
    s.persona,

    COUNT(DISTINCT s.session_id) AS sessions,

    ROUND(
        AVG(
            CAST(event_counts.total_events AS REAL)
            / NULLIF(s.session_duration_minutes, 0)
        ),
        2
    ) AS avg_events_per_minute,

    ROUND(
        AVG(
            CAST(event_counts.watch_events AS REAL)
            / NULLIF(s.session_duration_minutes, 0)
        ),
        2
    ) AS avg_watches_per_minute

FROM sessions s

JOIN (
    SELECT
        session_id,

        COUNT(*) AS total_events,

        SUM(
            CASE
                WHEN event_type = 'watch'
                THEN 1
                ELSE 0
            END
        ) AS watch_events

    FROM events

    GROUP BY session_id
) event_counts

    ON s.session_id = event_counts.session_id

GROUP BY s.persona

ORDER BY avg_events_per_minute DESC;
-- ============================================================
-- 4. SESSION DURATION VS EVENT DENSITY
-- Does event density change as sessions become longer?
-- ============================================================

WITH session_metrics AS (

    SELECT
        s.session_id,
        s.persona,
        s.session_duration_minutes,

        COUNT(e.event_id) AS total_events,

        SUM(
            CASE
                WHEN e.event_type = 'watch'
                THEN 1
                ELSE 0
            END
        ) AS watch_events

    FROM sessions s

    JOIN events e
        ON s.session_id = e.session_id

    GROUP BY
        s.session_id,
        s.persona,
        s.session_duration_minutes
)

SELECT
    CASE
        WHEN session_duration_minutes < 10
            THEN '<10 min'

        WHEN session_duration_minutes < 20
            THEN '10-19 min'

        WHEN session_duration_minutes < 40
            THEN '20-39 min'

        WHEN session_duration_minutes < 60
            THEN '40-59 min'

        WHEN session_duration_minutes < 90
            THEN '60-89 min'

        ELSE '90+ min'
    END AS duration_band,

    COUNT(*) AS sessions,

    ROUND(
        AVG(total_events),
        2
    ) AS avg_events_per_session,

    ROUND(
        AVG(watch_events),
        2
    ) AS avg_watches_per_session,

    ROUND(
        AVG(
            CAST(total_events AS REAL)
            / NULLIF(session_duration_minutes, 0)
        ),
        2
    ) AS avg_events_per_minute,

    ROUND(
        AVG(
            CAST(watch_events AS REAL)
            / NULLIF(session_duration_minutes, 0)
        ),
        2
    ) AS avg_watches_per_minute

FROM session_metrics

GROUP BY duration_band

ORDER BY
    CASE duration_band
        WHEN '<10 min' THEN 1
        WHEN '10-19 min' THEN 2
        WHEN '20-39 min' THEN 3
        WHEN '40-59 min' THEN 4
        WHEN '60-89 min' THEN 5
        WHEN '90+ min' THEN 6
    END;
    -- ============================================================
-- 5. SESSION EXIT BEHAVIOR
-- How do sessions differ by exit reason?
-- ============================================================

WITH session_metrics AS (

    SELECT
        s.session_id,
        s.persona,
        s.session_duration_minutes,
        s.exit_reason,

        COUNT(e.event_id) AS total_events,

        SUM(
            CASE
                WHEN e.event_type = 'watch'
                THEN 1
                ELSE 0
            END
        ) AS watch_events,

        SUM(
            CASE
                WHEN e.event_type = 'like'
                THEN 1
                ELSE 0
            END
        ) AS likes

    FROM sessions s

    LEFT JOIN events e
        ON s.session_id = e.session_id

    GROUP BY
        s.session_id,
        s.persona,
        s.session_duration_minutes,
        s.exit_reason
)

SELECT
    exit_reason,

    COUNT(*) AS sessions,

    ROUND(
        AVG(session_duration_minutes),
        2
    ) AS avg_session_minutes,

    ROUND(
        AVG(total_events),
        2
    ) AS avg_events,

    ROUND(
        AVG(watch_events),
        2
    ) AS avg_watches,

    ROUND(
        AVG(likes),
        2
    ) AS avg_likes

FROM session_metrics

GROUP BY exit_reason

ORDER BY avg_session_minutes DESC;
-- ============================================================
-- 6. WEEKEND VS WEEKDAY SESSION BEHAVIOR
-- ============================================================

WITH session_metrics AS (

    SELECT
        s.session_id,
        s.is_weekend,
        s.session_duration_minutes,

        COUNT(e.event_id) AS total_events,

        SUM(
            CASE
                WHEN e.event_type = 'watch'
                THEN 1
                ELSE 0
            END
        ) AS watch_events,

        SUM(
            CASE
                WHEN e.event_type = 'like'
                THEN 1
                ELSE 0
            END
        ) AS likes

    FROM sessions s

    LEFT JOIN events e
        ON s.session_id = e.session_id

    GROUP BY
        s.session_id,
        s.is_weekend,
        s.session_duration_minutes
)

SELECT
    CASE
        WHEN is_weekend = 1
            THEN 'Weekend'
        ELSE 'Weekday'
    END AS day_type,

    COUNT(*) AS sessions,

    ROUND(
        AVG(session_duration_minutes),
        2
    ) AS avg_session_minutes,

    ROUND(
        AVG(total_events),
        2
    ) AS avg_events_per_session,

    ROUND(
        AVG(watch_events),
        2
    ) AS avg_watches_per_session,

    ROUND(
        AVG(likes),
        2
    ) AS avg_likes_per_session,

    ROUND(
        AVG(
            CAST(total_events AS REAL)
            / NULLIF(session_duration_minutes, 0)
        ),
        2
    ) AS avg_events_per_minute

FROM session_metrics

GROUP BY is_weekend

ORDER BY is_weekend;
-- ============================================================
-- 7. TIME-OF-DAY SESSION BEHAVIOR
-- ============================================================

WITH session_metrics AS (

    SELECT
        s.session_id,
        CAST(
            strftime('%H', s.session_start)
            AS INTEGER
        ) AS session_hour,

        s.session_duration_minutes,

        COUNT(e.event_id) AS total_events,

        SUM(
            CASE
                WHEN e.event_type = 'watch'
                THEN 1
                ELSE 0
            END
        ) AS watch_events,

        SUM(
            CASE
                WHEN e.event_type = 'like'
                THEN 1
                ELSE 0
            END
        ) AS likes

    FROM sessions s

    LEFT JOIN events e
        ON s.session_id = e.session_id

    GROUP BY
        s.session_id,
        session_hour,
        s.session_duration_minutes
)

SELECT
    session_hour,

    COUNT(*) AS sessions,

    ROUND(
        AVG(session_duration_minutes),
        2
    ) AS avg_session_minutes,

    ROUND(
        AVG(total_events),
        2
    ) AS avg_events_per_session,

    ROUND(
        AVG(watch_events),
        2
    ) AS avg_watches_per_session,

    ROUND(
        AVG(
            CAST(total_events AS REAL)
            / NULLIF(session_duration_minutes, 0)
        ),
        2
    ) AS avg_events_per_minute

FROM session_metrics

GROUP BY session_hour

ORDER BY session_hour;
