-- ============================================================
-- DoomScroll Analytics Engine
-- 05 - Retention Analysis
-- ============================================================


-- ============================================================
-- 1. USER ACTIVITY FREQUENCY
-- How many distinct active days does each user have?
-- ============================================================

WITH user_activity AS (

    SELECT
        s.user_id,

        DATE(s.session_start) AS activity_date

    FROM sessions s

    GROUP BY
        s.user_id,
        DATE(s.session_start)
)

SELECT
    user_id,

    COUNT(*) AS active_days

FROM user_activity

GROUP BY user_id

ORDER BY active_days DESC;
-- ============================================================
-- 2. NEW VS RETURNING USERS
-- Did users return after their first active day?
-- ============================================================

WITH user_activity AS (

    SELECT
        user_id,
        DATE(session_start) AS activity_date

    FROM sessions

    GROUP BY
        user_id,
        DATE(session_start)
),

user_summary AS (

    SELECT
        user_id,

        MIN(activity_date) AS first_active_date,

        COUNT(*) AS active_days

    FROM user_activity

    GROUP BY user_id
)

SELECT
    CASE
        WHEN active_days = 1
            THEN 'One-day user'

        ELSE 'Returning user'
    END AS user_type,

    COUNT(*) AS users,

    ROUND(
        100.0 * COUNT(*)
        / (SELECT COUNT(*) FROM user_summary),
        2
    ) AS user_share

FROM user_summary

GROUP BY
    CASE
        WHEN active_days = 1
            THEN 'One-day user'

        ELSE 'Returning user'
    END

ORDER BY
    CASE
        WHEN user_type = 'One-day user'
            THEN 1
        ELSE 2
    END;
SELECT
    (SELECT COUNT(*)
     FROM users) AS total_users,

    (SELECT COUNT(DISTINCT user_id)
     FROM sessions) AS users_with_sessions,

    (SELECT COUNT(*)
     FROM users u
     WHERE NOT EXISTS (
         SELECT 1
         FROM sessions s
         WHERE s.user_id = u.user_id
     )) AS users_without_sessions;

-- ============================================================
-- 3. DAY-1 RETENTION
-- Did users return on the calendar day after first activity?
-- ============================================================

WITH user_activity AS (

    SELECT DISTINCT
        user_id,
        DATE(session_start) AS activity_date

    FROM sessions
),

first_activity AS (

    SELECT
        user_id,
        MIN(activity_date) AS first_active_date

    FROM user_activity

    GROUP BY user_id
),

retention_flag AS (

    SELECT
        f.user_id,
        f.first_active_date,

        CASE
            WHEN EXISTS (
                SELECT 1
                FROM user_activity ua
                WHERE ua.user_id = f.user_id
                  AND ua.activity_date =
                      DATE(
                          f.first_active_date,
                          '+1 day'
                      )
            )
            THEN 1
            ELSE 0
        END AS retained_day_1

    FROM first_activity f
)

SELECT
    COUNT(*) AS users_with_activity,

    SUM(retained_day_1) AS day_1_retained_users,

    COUNT(*) - SUM(retained_day_1)
        AS not_day_1_retained_users,

    ROUND(
        100.0 * SUM(retained_day_1)
        / COUNT(*),
        2
    ) AS day_1_retention_rate

FROM retention_flag;
-- ============================================================
-- 4. TIME TO FIRST RETURN
-- How long does it take returning users to come back?
-- ============================================================

WITH user_activity AS (

    SELECT DISTINCT
        user_id,
        DATE(session_start) AS activity_date

    FROM sessions
),

first_activity AS (

    SELECT
        user_id,
        MIN(activity_date) AS first_active_date

    FROM user_activity

    GROUP BY user_id
),

first_return AS (

    SELECT
        f.user_id,
        f.first_active_date,

        MIN(
            ua.activity_date
        ) AS first_return_date

    FROM first_activity f

    JOIN user_activity ua
        ON f.user_id = ua.user_id
        AND ua.activity_date > f.first_active_date

    GROUP BY
        f.user_id,
        f.first_active_date
),

return_gaps AS (

    SELECT
        user_id,

        CAST(
            julianday(first_return_date)
            - julianday(first_active_date)
            AS INTEGER
        ) AS days_to_return

    FROM first_return
)

SELECT
    CASE
        WHEN days_to_return = 1
            THEN '1 day'

        WHEN days_to_return BETWEEN 2 AND 7
            THEN '2-7 days'

        WHEN days_to_return BETWEEN 8 AND 30
            THEN '8-30 days'

        ELSE '31+ days'
    END AS return_window,

    COUNT(*) AS users,

    ROUND(
        100.0 * COUNT(*)
        / (SELECT COUNT(*) FROM return_gaps),
        2
    ) AS share_of_returning_users

FROM return_gaps

GROUP BY
    CASE
        WHEN days_to_return = 1
            THEN '1 day'

        WHEN days_to_return BETWEEN 2 AND 7
            THEN '2-7 days'

        WHEN days_to_return BETWEEN 8 AND 30
            THEN '8-30 days'

        ELSE '31+ days'
    END

ORDER BY
    CASE return_window
        WHEN '1 day' THEN 1
        WHEN '2-7 days' THEN 2
        WHEN '8-30 days' THEN 3
        WHEN '31+ days' THEN 4
    END;

-- ============================================================
-- 5. FIRST-SESSION BEHAVIOR VS EVENTUAL RETURN
-- Do users who eventually return behave differently
-- during their first recorded session?
-- ============================================================

WITH user_activity AS (

    SELECT DISTINCT
        user_id,
        DATE(session_start) AS activity_date

    FROM sessions
),

first_activity AS (

    SELECT
        user_id,
        MIN(activity_date) AS first_active_date

    FROM user_activity

    GROUP BY user_id
),

return_status AS (

    SELECT
        f.user_id,
        f.first_active_date,

        CASE
            WHEN EXISTS (
                SELECT 1
                FROM user_activity ua
                WHERE ua.user_id = f.user_id
                  AND ua.activity_date > f.first_active_date
            )
            THEN 'Returned'
            ELSE 'Did not return'
        END AS return_status

    FROM first_activity f
),

first_sessions AS (

    SELECT
        s.*,

        ROW_NUMBER() OVER (
            PARTITION BY s.user_id
            ORDER BY
                s.session_start,
                s.session_id
        ) AS session_number

    FROM sessions s
)

SELECT
    r.return_status,

    COUNT(*) AS users,

    ROUND(
        AVG(fs.session_duration_minutes),
        2
    ) AS avg_first_session_minutes,

    ROUND(
        AVG(asm.watch_count),
        2
    ) AS avg_first_session_watches,

    ROUND(
        AVG(asm.total_watch_seconds),
        2
    ) AS avg_first_session_watch_seconds,

    ROUND(
        AVG(asm.avg_completion_ratio),
        3
    ) AS avg_completion_ratio,

    ROUND(
        AVG(asm.like_rate),
        4
    ) AS avg_like_rate

FROM return_status r

JOIN first_sessions fs
    ON r.user_id = fs.user_id
    AND fs.session_number = 1

JOIN analytics_session_metrics asm
    ON fs.session_id = asm.session_id

GROUP BY r.return_status

ORDER BY
    CASE r.return_status
        WHEN 'Did not return' THEN 1
        WHEN 'Returned' THEN 2
    END;