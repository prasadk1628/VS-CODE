-- ============================================================
-- Phase E: Recommendation / Consumption Loop Analysis
-- Query 1: Session Consumption Depth
-- ============================================================

SELECT
    s.session_id,
    s.user_id,
    s.persona,
    s.session_duration_minutes,

    COUNT(DISTINCT e.content_id) AS unique_content_consumed,

    SUM(
        CASE
            WHEN e.event_type = 'watch' THEN 1
            ELSE 0
        END
    ) AS watch_events,

    SUM(
        CASE
            WHEN e.event_type = 'swipe_next' THEN 1
            ELSE 0
        END
    ) AS swipe_events,

    ROUND(
        CAST(COUNT(DISTINCT e.content_id) AS REAL)
        / NULLIF(s.session_duration_minutes, 0),
        2
    ) AS content_per_minute

FROM sessions s

JOIN events e
    ON s.session_id = e.session_id

GROUP BY
    s.session_id,
    s.user_id,
    s.persona,
    s.session_duration_minutes

ORDER BY unique_content_consumed DESC
LIMIT 20;
-- ============================================================
-- Query 2: Repeat Content Consumption
-- ============================================================

WITH session_content AS (
    SELECT
        session_id,
        user_id,
        content_id,
        COUNT(*) AS watch_count
    FROM events
    WHERE event_type = 'watch'
    GROUP BY
        session_id,
        user_id,
        content_id
),

session_repeat_metrics AS (
    SELECT
        session_id,
        user_id,

        COUNT(*) AS unique_content_watched,

        SUM(
            CASE
                WHEN watch_count > 1 THEN 1
                ELSE 0
            END
        ) AS repeated_content_items,

        SUM(watch_count) AS total_watch_events

    FROM session_content

    GROUP BY
        session_id,
        user_id
)

SELECT
    COUNT(*) AS total_sessions,

    SUM(
        CASE
            WHEN repeated_content_items > 0 THEN 1
            ELSE 0
        END
    ) AS sessions_with_repeats,

    ROUND(
        100.0 *
        SUM(
            CASE
                WHEN repeated_content_items > 0 THEN 1
                ELSE 0
            END
        )
        / COUNT(*),
        2
    ) AS repeat_session_rate,

    SUM(repeated_content_items) AS repeated_content_items,

    SUM(total_watch_events) AS total_watch_events,

    ROUND(
        1.0 *
        SUM(repeated_content_items)
        / NULLIF(SUM(total_watch_events), 0),
        3
    ) AS repeat_content_rate

FROM session_repeat_metrics;

-- ============================================================
-- Query 3: Repeat Consumption by Behavioral Segment
-- ============================================================

WITH session_content AS (
    SELECT
        e.session_id,
        e.user_id,
        e.content_id,
        COUNT(*) AS watch_count
    FROM events e
    WHERE e.event_type = 'watch'
    GROUP BY
        e.session_id,
        e.user_id,
        e.content_id
),

session_repeat AS (
    SELECT
        session_id,
        user_id,

        SUM(
            CASE
                WHEN watch_count > 1 THEN 1
                ELSE 0
            END
        ) AS repeated_content_items

    FROM session_content

    GROUP BY
        session_id,
        user_id
)

SELECT
    us.behavioral_segment,

    COUNT(*) AS total_sessions,

    SUM(
        CASE
            WHEN sr.repeated_content_items > 0 THEN 1
            ELSE 0
        END
    ) AS sessions_with_repeats,

    ROUND(
        100.0 *
        SUM(
            CASE
                WHEN sr.repeated_content_items > 0 THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS repeat_session_rate,

    ROUND(
        AVG(sr.repeated_content_items),
        2
    ) AS avg_repeated_content_items

FROM session_repeat sr

JOIN analytics_user_segments us
    ON sr.user_id = us.user_id

GROUP BY
    us.behavioral_segment

ORDER BY
    repeat_session_rate DESC;

-- ============================================================
-- Query 4: Repeat vs Non-Repeat Session Behavior
-- ============================================================

WITH session_content AS (
    SELECT
        e.session_id,
        e.content_id,
        COUNT(*) AS watch_count
    FROM events e
    WHERE e.event_type = 'watch'
    GROUP BY
        e.session_id,
        e.content_id
),

repeat_status AS (
    SELECT
        session_id,

        CASE
            WHEN SUM(
                CASE
                    WHEN watch_count > 1 THEN 1
                    ELSE 0
                END
            ) > 0
            THEN 'Repeat Consumption'
            ELSE 'No Repeat'
        END AS consumption_type

    FROM session_content

    GROUP BY session_id
),

session_metrics AS (
    SELECT
        s.session_id,
        s.session_duration_minutes,

        COUNT(DISTINCT e.content_id) AS unique_content_consumed,

        SUM(
            CASE
                WHEN e.event_type = 'watch' THEN 1
                ELSE 0
            END
        ) AS watch_events,

        ROUND(
            CAST(COUNT(DISTINCT e.content_id) AS REAL)
            / NULLIF(s.session_duration_minutes, 0),
            2
        ) AS content_per_minute

    FROM sessions s

    JOIN events e
        ON s.session_id = e.session_id

    GROUP BY
        s.session_id,
        s.session_duration_minutes
)

SELECT
    rs.consumption_type,

    COUNT(*) AS sessions,

    ROUND(
        AVG(sm.session_duration_minutes),
        2
    ) AS avg_session_duration,

    ROUND(
        AVG(sm.unique_content_consumed),
        2
    ) AS avg_unique_content,

    ROUND(
        AVG(sm.watch_events),
        2
    ) AS avg_watch_events,

    ROUND(
        AVG(sm.content_per_minute),
        2
    ) AS avg_content_per_minute

FROM repeat_status rs

JOIN session_metrics sm
    ON rs.session_id = sm.session_id

GROUP BY
    rs.consumption_type

ORDER BY
    rs.consumption_type;
-- ============================================================
-- Query 5: Sequential Consumption Loop
-- ============================================================

WITH watch_sequence AS (
    SELECT
        e.event_id,
        e.session_id,
        e.user_id,
        e.content_id,
        e.timestamp,

        ROW_NUMBER() OVER (
            PARTITION BY e.session_id
            ORDER BY e.timestamp, e.event_id
        ) AS watch_position

    FROM events e

    WHERE e.event_type = 'watch'
),

content_occurrences AS (
    SELECT
        event_id,
        session_id,
        user_id,
        content_id,
        timestamp,
        watch_position,

        LAG(watch_position) OVER (
            PARTITION BY session_id, content_id
            ORDER BY watch_position
        ) AS previous_watch_position

    FROM watch_sequence
),

loop_events AS (
    SELECT
        session_id,
        user_id,
        content_id,
        watch_position,
        previous_watch_position,

        CASE
            WHEN previous_watch_position IS NOT NULL
                 AND watch_position - previous_watch_position > 1
            THEN 1
            ELSE 0
        END AS is_return_loop

    FROM content_occurrences
),

session_loop_metrics AS (
    SELECT
        session_id,
        user_id,

        COUNT(*) AS total_watch_events,

        SUM(is_return_loop) AS return_loop_events,

        MAX(is_return_loop) AS has_return_loop

    FROM loop_events

    GROUP BY
        session_id,
        user_id
)

SELECT
    COUNT(*) AS total_sessions,

    SUM(has_return_loop) AS sessions_with_loops,

    ROUND(
        100.0 * SUM(has_return_loop) / COUNT(*),
        2
    ) AS loop_session_rate,

    SUM(return_loop_events) AS total_return_loop_events,

    ROUND(
        1.0 * SUM(return_loop_events)
        / NULLIF(SUM(total_watch_events), 0),
        4
    ) AS loop_event_rate

FROM session_loop_metrics;
-- ============================================================
-- Query 6: Sequential Loop Behavior by Behavioral Segment
-- ============================================================

WITH watch_sequence AS (
    SELECT
        e.event_id,
        e.session_id,
        e.user_id,
        e.content_id,
        e.timestamp,

        ROW_NUMBER() OVER (
            PARTITION BY e.session_id
            ORDER BY e.timestamp, e.event_id
        ) AS watch_position

    FROM events e

    WHERE e.event_type = 'watch'
),

content_occurrences AS (
    SELECT
        session_id,
        user_id,
        content_id,
        watch_position,

        LAG(watch_position) OVER (
            PARTITION BY session_id, content_id
            ORDER BY watch_position
        ) AS previous_watch_position

    FROM watch_sequence
),

session_loops AS (
    SELECT
        session_id,
        user_id,

        MAX(
            CASE
                WHEN previous_watch_position IS NOT NULL
                     AND watch_position - previous_watch_position > 1
                THEN 1
                ELSE 0
            END
        ) AS has_return_loop,

        SUM(
            CASE
                WHEN previous_watch_position IS NOT NULL
                     AND watch_position - previous_watch_position > 1
                THEN 1
                ELSE 0
            END
        ) AS return_loop_events

    FROM content_occurrences

    GROUP BY
        session_id,
        user_id
)

SELECT
    us.behavioral_segment,

    COUNT(*) AS total_sessions,

    SUM(sl.has_return_loop) AS sessions_with_loops,

    ROUND(
        100.0 * SUM(sl.has_return_loop) / COUNT(*),
        2
    ) AS loop_session_rate,

    ROUND(
        AVG(sl.return_loop_events),
        2
    ) AS avg_loop_events

FROM session_loops sl

JOIN analytics_user_segments us
    ON sl.user_id = us.user_id

GROUP BY
    us.behavioral_segment

ORDER BY
    loop_session_rate DESC;

-- ============================================================
-- Query 7: Time / Depth to Content Return
--
-- Measures how far a user travels through a session before
-- returning to previously consumed content.
--
-- Example:
-- A -> B -> A
-- return_gap = 2 watch positions
--
-- A -> B -> C -> D -> A
-- return_gap = 4 watch positions
-- ============================================================

WITH watch_sequence AS (
    SELECT
        e.event_id,
        e.session_id,
        e.user_id,
        e.content_id,
        e.timestamp,

        ROW_NUMBER() OVER (
            PARTITION BY e.session_id
            ORDER BY e.timestamp, e.event_id
        ) AS watch_position

    FROM events e

    WHERE e.event_type = 'watch'
),

content_returns AS (
    SELECT
        session_id,
        user_id,
        content_id,

        watch_position,
        timestamp,

        LAG(watch_position) OVER (
            PARTITION BY session_id, content_id
            ORDER BY watch_position
        ) AS previous_watch_position,

        LAG(timestamp) OVER (
            PARTITION BY session_id, content_id
            ORDER BY watch_position
        ) AS previous_watch_timestamp

    FROM watch_sequence
),

return_events AS (
    SELECT
        session_id,
        user_id,
        content_id,

        watch_position,
        previous_watch_position,

        watch_position - previous_watch_position
            AS return_watch_gap,

        ROUND(
            (
                julianday(timestamp)
                - julianday(previous_watch_timestamp)
            ) * 86400,
            2
        ) AS return_time_gap_seconds

    FROM content_returns

    WHERE previous_watch_position IS NOT NULL

      AND watch_position - previous_watch_position > 1
)

SELECT
    COUNT(*) AS total_return_events,

    ROUND(
        AVG(return_watch_gap),
        2
    ) AS avg_watch_position_gap,

    ROUND(
        MIN(return_watch_gap),
        2
    ) AS min_watch_position_gap,

    ROUND(
        MAX(return_watch_gap),
        2
    ) AS max_watch_position_gap,

    ROUND(
        AVG(return_time_gap_seconds),
        2
    ) AS avg_return_time_seconds,

    ROUND(
        MIN(return_time_gap_seconds),
        2
    ) AS min_return_time_seconds,

    ROUND(
        MAX(return_time_gap_seconds),
        2
    ) AS max_return_time_seconds

FROM return_events;

-- ============================================================
-- Query 8: Phase E Loop Summary
-- ============================================================

WITH watch_sequence AS (
    SELECT
        e.event_id,
        e.session_id,
        e.user_id,
        e.content_id,
        e.timestamp,

        ROW_NUMBER() OVER (
            PARTITION BY e.session_id
            ORDER BY e.timestamp, e.event_id
        ) AS watch_position

    FROM events e

    WHERE e.event_type = 'watch'
),

content_returns AS (
    SELECT
        session_id,
        user_id,
        content_id,
        watch_position,
        timestamp,

        LAG(watch_position) OVER (
            PARTITION BY session_id, content_id
            ORDER BY watch_position
        ) AS previous_watch_position,

        LAG(timestamp) OVER (
            PARTITION BY session_id, content_id
            ORDER BY watch_position
        ) AS previous_watch_timestamp

    FROM watch_sequence
),

loop_events AS (
    SELECT
        session_id,
        user_id,

        watch_position - previous_watch_position
            AS return_watch_gap,

        (
            julianday(timestamp)
            - julianday(previous_watch_timestamp)
        ) * 86400
            AS return_time_gap_seconds

    FROM content_returns

    WHERE previous_watch_position IS NOT NULL
      AND watch_position - previous_watch_position > 1
),

session_loop_summary AS (
    SELECT
        session_id,
        user_id,

        COUNT(*) AS loop_events,

        AVG(return_watch_gap)
            AS avg_return_watch_gap,

        AVG(return_time_gap_seconds)
            AS avg_return_time_seconds

    FROM loop_events

    GROUP BY
        session_id,
        user_id
),

session_metrics AS (
    SELECT
        s.session_id,
        s.session_duration_minutes,

        COUNT(DISTINCT e.content_id)
            AS unique_content_consumed,

        SUM(
            CASE
                WHEN e.event_type = 'watch'
                THEN 1
                ELSE 0
            END
        ) AS total_watch_events

    FROM sessions s

    JOIN events e
        ON s.session_id = e.session_id

    GROUP BY
        s.session_id,
        s.session_duration_minutes
)

SELECT

    COUNT(*) AS total_sessions,

    SUM(
        CASE
            WHEN sls.session_id IS NOT NULL
            THEN 1
            ELSE 0
        END
    ) AS loop_sessions,

    ROUND(
        100.0 *
        SUM(
            CASE
                WHEN sls.session_id IS NOT NULL
                THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS loop_session_rate,

    SUM(
        COALESCE(sls.loop_events, 0)
    ) AS total_loop_events,

    ROUND(
        1.0 *
        SUM(COALESCE(sls.loop_events, 0))
        / SUM(sm.total_watch_events),
        4
    ) AS loop_event_rate,

    ROUND(
        AVG(
            CASE
                WHEN sls.session_id IS NOT NULL
                THEN sm.session_duration_minutes
            END
        ),
        2
    ) AS avg_loop_session_duration,

    ROUND(
        AVG(
            CASE
                WHEN sls.session_id IS NOT NULL
                THEN sm.unique_content_consumed
            END
        ),
        2
    ) AS avg_loop_session_content,

    ROUND(
        AVG(sls.avg_return_watch_gap),
        2
    ) AS avg_return_watch_gap,

    ROUND(
        AVG(sls.avg_return_time_seconds),
        2
    ) AS avg_return_time_seconds

FROM session_metrics sm

LEFT JOIN session_loop_summary sls
    ON sm.session_id = sls.session_id;