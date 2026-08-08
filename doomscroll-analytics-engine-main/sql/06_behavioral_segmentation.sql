-- ============================================================
-- DoomScroll Analytics Engine
-- 06 - Behavioral Segmentation
-- ============================================================


-- ============================================================
-- 1. USER BEHAVIORAL PROFILE
-- Aggregate session behavior to the user level.
-- Existing persona is retained for comparison only.
-- ============================================================

SELECT
    s.user_id,

    u.persona,

    COUNT(DISTINCT s.session_id)
        AS session_count,

    COUNT(
        DISTINCT DATE(s.session_start)
    ) AS active_days,

    ROUND(
        AVG(s.session_duration_minutes),
        2
    ) AS avg_session_minutes,

    ROUND(
        AVG(asm.watch_count),
        2
    ) AS avg_watches_per_session,

    ROUND(
        AVG(asm.total_watch_seconds),
        2
    ) AS avg_watch_seconds_per_session,

    ROUND(
        AVG(asm.avg_completion_ratio),
        3
    ) AS avg_completion_ratio,

    ROUND(
        AVG(asm.events_per_minute),
        2
    ) AS avg_events_per_minute,

    ROUND(
        AVG(asm.like_rate),
        4
    ) AS avg_like_rate,

    ROUND(
        AVG(asm.preferred_watch_share),
        3
    ) AS avg_preferred_watch_share,

    ROUND(
        SUM(asm.total_watch_seconds),
        2
    ) AS total_watch_seconds

FROM sessions s

JOIN analytics_session_metrics asm
    ON s.session_id = asm.session_id

JOIN users u
    ON s.user_id = u.user_id

GROUP BY
    s.user_id,
    u.persona

ORDER BY
    total_watch_seconds DESC;


-- ============================================================
-- 2. USER BEHAVIORAL VARIATION
-- How much do users differ across key behaviors?
-- ============================================================

WITH user_behavior AS (

    SELECT
        s.user_id,

        COUNT(DISTINCT s.session_id)
            AS session_count,

        COUNT(
            DISTINCT DATE(s.session_start)
        ) AS active_days,

        AVG(s.session_duration_minutes)
            AS avg_session_minutes,

        AVG(asm.watch_count)
            AS avg_watches_per_session,

        AVG(asm.avg_completion_ratio)
            AS avg_completion_ratio,

        AVG(asm.events_per_minute)
            AS avg_events_per_minute,

        AVG(asm.like_rate)
            AS avg_like_rate,

        AVG(asm.preferred_watch_share)
            AS avg_preferred_watch_share,

        SUM(asm.total_watch_seconds)
            AS total_watch_seconds

    FROM sessions s

    JOIN analytics_session_metrics asm
        ON s.session_id = asm.session_id

    GROUP BY s.user_id
)

SELECT
    'avg_session_minutes' AS metric,
    ROUND(MIN(avg_session_minutes), 2) AS min_value,
    ROUND(AVG(avg_session_minutes), 2) AS avg_value,
    ROUND(MAX(avg_session_minutes), 2) AS max_value

FROM user_behavior

UNION ALL

SELECT
    'avg_watches_per_session',
    ROUND(MIN(avg_watches_per_session), 2),
    ROUND(AVG(avg_watches_per_session), 2),
    ROUND(MAX(avg_watches_per_session), 2)

FROM user_behavior

UNION ALL

SELECT
    'avg_completion_ratio',
    ROUND(MIN(avg_completion_ratio), 3),
    ROUND(AVG(avg_completion_ratio), 3),
    ROUND(MAX(avg_completion_ratio), 3)

FROM user_behavior

UNION ALL

SELECT
    'avg_events_per_minute',
    ROUND(MIN(avg_events_per_minute), 2),
    ROUND(AVG(avg_events_per_minute), 2),
    ROUND(MAX(avg_events_per_minute), 2)

FROM user_behavior

UNION ALL

SELECT
    'avg_like_rate',
    ROUND(MIN(avg_like_rate), 4),
    ROUND(AVG(avg_like_rate), 4),
    ROUND(MAX(avg_like_rate), 4)

FROM user_behavior

UNION ALL

SELECT
    'avg_preferred_watch_share',
    ROUND(MIN(avg_preferred_watch_share), 3),
    ROUND(AVG(avg_preferred_watch_share), 3),
    ROUND(MAX(avg_preferred_watch_share), 3)

FROM user_behavior

ORDER BY metric;

-- ============================================================
-- 3. BEHAVIORAL DIMENSION RELATIONSHIPS
-- Inspect candidate dimensions before segmentation.
-- ============================================================

WITH user_behavior AS (

    SELECT
        s.user_id,

        AVG(s.session_duration_minutes)
            AS avg_session_minutes,

        AVG(asm.avg_completion_ratio)
            AS avg_completion_ratio,

        AVG(asm.events_per_minute)
            AS avg_events_per_minute,

        AVG(asm.like_rate)
            AS avg_like_rate

    FROM sessions s

    JOIN analytics_session_metrics asm
        ON s.session_id = asm.session_id

    GROUP BY s.user_id
)

SELECT
    COUNT(*) AS users,

    ROUND(
        MIN(avg_session_minutes),
        2
    ) AS min_duration,

    ROUND(
        MAX(avg_session_minutes),
        2
    ) AS max_duration,

    ROUND(
        MIN(avg_completion_ratio),
        3
    ) AS min_completion,

    ROUND(
        MAX(avg_completion_ratio),
        3
    ) AS max_completion,

    ROUND(
        MIN(avg_events_per_minute),
        2
    ) AS min_intensity,

    ROUND(
        MAX(avg_events_per_minute),
        2
    ) AS max_intensity,

    ROUND(
        MIN(avg_like_rate),
        4
    ) AS min_like_rate,

    ROUND(
        MAX(avg_like_rate),
        4
    ) AS max_like_rate

FROM user_behavior;
-- ============================================================
-- 4. BEHAVIORAL QUARTILES
-- Convert raw behavior into data-driven dimensions.
-- ============================================================

WITH user_behavior AS (

    SELECT
        s.user_id,

        AVG(s.session_duration_minutes)
            AS avg_session_minutes,

        AVG(asm.avg_completion_ratio)
            AS avg_completion_ratio,

        AVG(asm.events_per_minute)
            AS avg_events_per_minute,

        AVG(asm.like_rate)
            AS avg_like_rate

    FROM sessions s

    JOIN analytics_session_metrics asm
        ON s.session_id = asm.session_id

    GROUP BY s.user_id
),

ranked AS (

    SELECT
        *,

        NTILE(4) OVER (
            ORDER BY avg_session_minutes
        ) AS depth_quartile,

        NTILE(4) OVER (
            ORDER BY avg_completion_ratio
        ) AS completion_quartile,

        NTILE(4) OVER (
            ORDER BY avg_events_per_minute
        ) AS intensity_quartile,

        NTILE(4) OVER (
            ORDER BY avg_like_rate
        ) AS engagement_quartile

    FROM user_behavior
)

SELECT
    depth_quartile,

    COUNT(*) AS users,

    ROUND(
        AVG(avg_session_minutes),
        2
    ) AS avg_session_minutes,

    ROUND(
        AVG(avg_completion_ratio),
        3
    ) AS avg_completion,

    ROUND(
        AVG(avg_events_per_minute),
        2
    ) AS avg_events_per_minute,

    ROUND(
        AVG(avg_like_rate),
        4
    ) AS avg_like_rate

FROM ranked

GROUP BY depth_quartile

ORDER BY depth_quartile;
-- ============================================================
-- 5. TWO-DIMENSIONAL BEHAVIORAL SEGMENTS
-- Depth × active engagement.
-- Quartile thresholds are data-driven.
-- ============================================================

WITH user_behavior AS (

    SELECT
        s.user_id,

        AVG(s.session_duration_minutes)
            AS avg_session_minutes,

        AVG(asm.avg_completion_ratio)
            AS avg_completion_ratio,

        AVG(asm.events_per_minute)
            AS avg_events_per_minute,

        AVG(asm.like_rate)
            AS avg_like_rate

    FROM sessions s

    JOIN analytics_session_metrics asm
        ON s.session_id = asm.session_id

    GROUP BY s.user_id
),

ranked AS (

    SELECT
        *,

        NTILE(4) OVER (
            ORDER BY avg_session_minutes
        ) AS depth_quartile,

        NTILE(4) OVER (
            ORDER BY avg_like_rate
        ) AS engagement_quartile

    FROM user_behavior
),

segmented AS (

    SELECT
        *,

        CASE
            WHEN depth_quartile <= 2
             AND engagement_quartile <= 2
                THEN 'Light Passive'

            WHEN depth_quartile <= 2
             AND engagement_quartile >= 3
                THEN 'Quick Engager'

            WHEN depth_quartile >= 3
             AND engagement_quartile <= 2
                THEN 'Deep Consumer'

            WHEN depth_quartile >= 3
             AND engagement_quartile >= 3
                THEN 'Deep Engager'
        END AS behavioral_segment

    FROM ranked
)

SELECT
    behavioral_segment,

    COUNT(*) AS users,

    ROUND(
        100.0 * COUNT(*)
        / (SELECT COUNT(*) FROM segmented),
        2
    ) AS user_share,

    ROUND(
        AVG(avg_session_minutes),
        2
    ) AS avg_session_minutes,

    ROUND(
        AVG(avg_completion_ratio),
        3
    ) AS avg_completion,

    ROUND(
        AVG(avg_events_per_minute),
        2
    ) AS avg_events_per_minute,

    ROUND(
        AVG(avg_like_rate),
        4
    ) AS avg_like_rate

FROM segmented

GROUP BY behavioral_segment

ORDER BY
    CASE behavioral_segment
        WHEN 'Light Passive' THEN 1
        WHEN 'Quick Engager' THEN 2
        WHEN 'Deep Consumer' THEN 3
        WHEN 'Deep Engager' THEN 4
    END;

-- ============================================================
-- 6. BEHAVIORAL SEGMENT VALIDATION
-- Validate segments using additional behavioral metrics.
-- ============================================================

WITH user_behavior AS (

    SELECT
        s.user_id,

        COUNT(DISTINCT s.session_id)
            AS session_count,

        COUNT(
            DISTINCT DATE(s.session_start)
        ) AS active_days,

        AVG(s.session_duration_minutes)
            AS avg_session_minutes,

        AVG(asm.watch_count)
            AS avg_watches_per_session,

        AVG(asm.total_watch_seconds)
            AS avg_watch_seconds_per_session,

        AVG(asm.avg_completion_ratio)
            AS avg_completion_ratio,

        AVG(asm.events_per_minute)
            AS avg_events_per_minute,

        AVG(asm.like_rate)
            AS avg_like_rate

    FROM sessions s

    JOIN analytics_session_metrics asm
        ON s.session_id = asm.session_id

    GROUP BY s.user_id
),

ranked AS (

    SELECT
        *,

        NTILE(4) OVER (
            ORDER BY avg_session_minutes
        ) AS depth_quartile,

        NTILE(4) OVER (
            ORDER BY avg_like_rate
        ) AS engagement_quartile

    FROM user_behavior
),

segmented AS (

    SELECT
        *,

        CASE
            WHEN depth_quartile <= 2
             AND engagement_quartile <= 2
                THEN 'Light Passive'

            WHEN depth_quartile <= 2
             AND engagement_quartile >= 3
                THEN 'Quick Engager'

            WHEN depth_quartile >= 3
             AND engagement_quartile <= 2
                THEN 'Deep Consumer'

            ELSE 'Deep Engager'
        END AS behavioral_segment

    FROM ranked
)

SELECT
    behavioral_segment,

    COUNT(*) AS users,

    ROUND(
        AVG(session_count),
        2
    ) AS avg_sessions,

    ROUND(
        AVG(active_days),
        2
    ) AS avg_active_days,

    ROUND(
        AVG(avg_watches_per_session),
        2
    ) AS avg_watches,

    ROUND(
        AVG(avg_watch_seconds_per_session),
        2
    ) AS avg_watch_seconds,

    ROUND(
        AVG(avg_completion_ratio),
        3
    ) AS avg_completion,

    ROUND(
        AVG(avg_events_per_minute),
        2
    ) AS avg_events_per_minute

FROM segmented

GROUP BY behavioral_segment

ORDER BY
    CASE behavioral_segment
        WHEN 'Light Passive' THEN 1
        WHEN 'Quick Engager' THEN 2
        WHEN 'Deep Consumer' THEN 3
        WHEN 'Deep Engager' THEN 4
    END;

-- ============================================================
-- 7. PERSONA CROSS-VALIDATION
-- Compare behavior-derived segments with the existing
-- synthetic persona labels.
--
-- IMPORTANT:
-- Persona is NOT used to create the segments.
-- It is used only for validation.
-- ============================================================

WITH user_behavior AS (

    SELECT
        s.user_id,

        u.persona,

        AVG(s.session_duration_minutes)
            AS avg_session_minutes,

        AVG(asm.like_rate)
            AS avg_like_rate

    FROM sessions s

    JOIN users u
        ON s.user_id = u.user_id

    JOIN analytics_session_metrics asm
        ON s.session_id = asm.session_id

    GROUP BY
        s.user_id,
        u.persona
),

ranked AS (

    SELECT
        *,

        NTILE(4) OVER (
            ORDER BY avg_session_minutes
        ) AS depth_quartile,

        NTILE(4) OVER (
            ORDER BY avg_like_rate
        ) AS engagement_quartile

    FROM user_behavior
),

segmented AS (

    SELECT
        *,

        CASE
            WHEN depth_quartile <= 2
             AND engagement_quartile <= 2
                THEN 'Light Passive'

            WHEN depth_quartile <= 2
             AND engagement_quartile >= 3
                THEN 'Quick Engager'

            WHEN depth_quartile >= 3
             AND engagement_quartile <= 2
                THEN 'Deep Consumer'

            ELSE 'Deep Engager'
        END AS behavioral_segment

    FROM ranked
)

SELECT
    behavioral_segment,
    persona,

    COUNT(*) AS users,

    ROUND(
        100.0 * COUNT(*)
        /
        SUM(COUNT(*)) OVER (
            PARTITION BY behavioral_segment
        ),
        2
    ) AS segment_persona_share

FROM segmented

GROUP BY
    behavioral_segment,
    persona

ORDER BY
    CASE behavioral_segment
        WHEN 'Light Passive' THEN 1
        WHEN 'Quick Engager' THEN 2
        WHEN 'Deep Consumer' THEN 3
        WHEN 'Deep Engager' THEN 4
    END,

    users DESC;
-- ============================================================
-- 8. ANALYTICS USER SEGMENTS
-- Reusable user-level behavioral segmentation view.
--
-- One row per active user.
-- Persona is retained for validation/context only.
-- Segments are derived from observed behavior.
-- ============================================================

DROP VIEW IF EXISTS analytics_user_segments;

CREATE VIEW analytics_user_segments AS

WITH user_behavior AS (

    SELECT
        s.user_id,

        u.persona,

        COUNT(DISTINCT s.session_id)
            AS session_count,

        COUNT(
            DISTINCT DATE(s.session_start)
        ) AS active_days,

        AVG(s.session_duration_minutes)
            AS avg_session_minutes,

        AVG(asm.watch_count)
            AS avg_watches_per_session,

        AVG(asm.total_watch_seconds)
            AS avg_watch_seconds_per_session,

        AVG(asm.avg_completion_ratio)
            AS avg_completion_ratio,

        AVG(asm.events_per_minute)
            AS avg_events_per_minute,

        AVG(asm.like_rate)
            AS avg_like_rate,

        AVG(asm.preferred_watch_share)
            AS avg_preferred_watch_share,

        SUM(asm.total_watch_seconds)
            AS total_watch_seconds

    FROM sessions s

    JOIN users u
        ON s.user_id = u.user_id

    JOIN analytics_session_metrics asm
        ON s.session_id = asm.session_id

    GROUP BY
        s.user_id,
        u.persona
),

ranked AS (

    SELECT
        *,

        NTILE(4) OVER (
            ORDER BY avg_session_minutes
        ) AS depth_quartile,

        NTILE(4) OVER (
            ORDER BY avg_like_rate
        ) AS engagement_quartile

    FROM user_behavior
)

SELECT
    user_id,
    persona,

    session_count,
    active_days,

    ROUND(
        avg_session_minutes,
        2
    ) AS avg_session_minutes,

    ROUND(
        avg_watches_per_session,
        2
    ) AS avg_watches_per_session,

    ROUND(
        avg_watch_seconds_per_session,
        2
    ) AS avg_watch_seconds_per_session,

    ROUND(
        avg_completion_ratio,
        3
    ) AS avg_completion_ratio,

    ROUND(
        avg_events_per_minute,
        2
    ) AS avg_events_per_minute,

    ROUND(
        avg_like_rate,
        4
    ) AS avg_like_rate,

    ROUND(
        avg_preferred_watch_share,
        3
    ) AS avg_preferred_watch_share,

    ROUND(
        total_watch_seconds,
        2
    ) AS total_watch_seconds,

    depth_quartile,
    engagement_quartile,

    CASE

        WHEN depth_quartile <= 2
         AND engagement_quartile <= 2
            THEN 'Light Passive'

        WHEN depth_quartile <= 2
         AND engagement_quartile >= 3
            THEN 'Quick Engager'

        WHEN depth_quartile >= 3
         AND engagement_quartile <= 2
            THEN 'Deep Consumer'

        ELSE 'Deep Engager'

    END AS behavioral_segment

FROM ranked;

