-- ============================================================
-- DoomScroll Analytics Engine
-- Tableau-ready analytical views
-- Phases A-F
--
-- Source of truth: SQLite database
-- Purpose: expose clean, dashboard-ready grain and KPIs.
-- ============================================================

PRAGMA foreign_keys = ON;

-- ------------------------------------------------------------
-- 0. SESSION METRICS
-- Grain: one row per session
-- Supports: Session Behavior dashboard
-- ------------------------------------------------------------
DROP VIEW IF EXISTS analytics_tableau_session_metrics;

CREATE VIEW analytics_tableau_session_metrics AS
WITH event_metrics AS (
    SELECT
        session_id,
        COUNT(*) AS total_events,
        COUNT(DISTINCT CASE WHEN event_type = 'content_impression' THEN content_id END) AS unique_content_items,
        SUM(CASE WHEN event_type = 'content_impression' THEN 1 ELSE 0 END) AS impressions,
        SUM(CASE WHEN event_type = 'video_start' THEN 1 ELSE 0 END) AS video_starts,
        SUM(CASE WHEN event_type = 'watch' THEN 1 ELSE 0 END) AS watch_events,
        SUM(CASE WHEN event_type = 'like' THEN 1 ELSE 0 END) AS likes,
        SUM(CASE WHEN event_type = 'swipe_next' THEN 1 ELSE 0 END) AS swipes,
        COALESCE(SUM(CASE WHEN event_type = 'watch' THEN watch_seconds ELSE 0 END), 0) AS total_watch_seconds,
        AVG(CASE WHEN event_type = 'watch' THEN watch_seconds END) AS avg_watch_seconds
    FROM events
    GROUP BY session_id
)
SELECT
    s.session_id,
    s.user_id,
    s.persona,
    s.session_start,
    s.session_end,
    DATE(s.session_start) AS session_date,
    CAST(strftime('%H', s.session_start) AS INTEGER) AS session_hour,
    CAST(strftime('%w', s.session_start) AS INTEGER) AS day_of_week,
    CASE CAST(strftime('%w', s.session_start) AS INTEGER)
        WHEN 0 THEN 'Sunday'
        WHEN 1 THEN 'Monday'
        WHEN 2 THEN 'Tuesday'
        WHEN 3 THEN 'Wednesday'
        WHEN 4 THEN 'Thursday'
        WHEN 5 THEN 'Friday'
        WHEN 6 THEN 'Saturday'
    END AS day_name,
    s.session_duration_minutes,
    s.exit_reason,
    s.is_weekend,
    COALESCE(e.total_events, 0) AS total_events,
    COALESCE(e.unique_content_items, 0) AS unique_content_items,
    COALESCE(e.impressions, 0) AS impressions,
    COALESCE(e.video_starts, 0) AS video_starts,
    COALESCE(e.watch_events, 0) AS watch_events,
    COALESCE(e.likes, 0) AS likes,
    COALESCE(e.swipes, 0) AS swipes,
    ROUND(COALESCE(e.total_watch_seconds, 0), 2) AS total_watch_seconds,
    ROUND(COALESCE(e.avg_watch_seconds, 0), 2) AS avg_watch_seconds,
    ROUND(
        CAST(COALESCE(e.total_events, 0) AS REAL) /
        NULLIF(s.session_duration_minutes, 0),
        2
    ) AS events_per_minute,
    ROUND(
        CAST(COALESCE(e.unique_content_items, 0) AS REAL) /
        NULLIF(s.session_duration_minutes, 0),
        2
    ) AS content_items_per_minute,
    ROUND(
        100.0 * COALESCE(e.likes, 0) /
        NULLIF(e.watch_events, 0),
        2
    ) AS watch_to_like_rate_pct
FROM sessions s
LEFT JOIN event_metrics e
    ON s.session_id = e.session_id;


-- ------------------------------------------------------------
-- 1. ENGAGEMENT DECAY / JOURNEY DEPTH
-- Grain: one row per session x journey quartile
-- Supports: Engagement & Consumption dashboard
-- ------------------------------------------------------------
DROP VIEW IF EXISTS analytics_tableau_engagement_decay;

CREATE VIEW analytics_tableau_engagement_decay AS
WITH impressions AS (
    SELECT
        session_id,
        user_id,
        event_id,
        content_id,
        NTILE(4) OVER (
            PARTITION BY session_id
            ORDER BY event_id
        ) AS journey_quartile
    FROM events
    WHERE event_type = 'content_impression'
),
likes AS (
    SELECT
        session_id,
        content_id,
        event_id
    FROM events
    WHERE event_type = 'like'
),
watch_by_content AS (
    SELECT
        session_id,
        content_id,
        SUM(watch_seconds) AS watch_seconds
    FROM events
    WHERE event_type = 'watch'
    GROUP BY session_id, content_id
)
SELECT
    i.session_id,
    i.user_id,
    i.journey_quartile,
    COUNT(*) AS content_items,
    COUNT(l.event_id) AS likes,
    ROUND(
        100.0 * COUNT(l.event_id) / NULLIF(COUNT(*), 0),
        2
    ) AS like_rate_pct,
    ROUND(COALESCE(SUM(w.watch_seconds), 0), 2) AS watch_seconds
FROM impressions i
LEFT JOIN likes l
    ON i.session_id = l.session_id
   AND i.content_id = l.content_id
LEFT JOIN watch_by_content w
    ON i.session_id = w.session_id
   AND i.content_id = w.content_id
GROUP BY
    i.session_id,
    i.user_id,
    i.journey_quartile;


-- ------------------------------------------------------------
-- 2. USER RETENTION / COHORT
-- Grain: one row per active user
-- Supports: Retention & Cohorts dashboard
--
-- Retention is measured relative to signup_date and only sessions
-- on/after signup are eligible.
-- ------------------------------------------------------------
DROP VIEW IF EXISTS analytics_tableau_retention;

CREATE VIEW analytics_tableau_retention AS
WITH valid_sessions AS (
    SELECT
        s.user_id,
        DATE(s.session_start) AS session_date
    FROM sessions s
    JOIN users u
        ON s.user_id = u.user_id
    WHERE DATE(s.session_start) >= DATE(u.signup_date)
),
user_activity AS (
    SELECT
        u.user_id,
        DATE(u.signup_date) AS signup_date,
        strftime('%Y-%m', u.signup_date) AS cohort_month,
        COUNT(DISTINCT v.session_date) AS active_days,
        MIN(v.session_date) AS first_session_date,
        MAX(v.session_date) AS last_session_date,
        MAX(
            CASE
                WHEN julianday(v.session_date) - julianday(u.signup_date) >= 1
                THEN 1 ELSE 0
            END
        ) AS retained_d1,
        MAX(
            CASE
                WHEN julianday(v.session_date) - julianday(u.signup_date) >= 7
                THEN 1 ELSE 0
            END
        ) AS retained_d7,
        MAX(
            CASE
                WHEN julianday(v.session_date) - julianday(u.signup_date) >= 30
                THEN 1 ELSE 0
            END
        ) AS retained_d30
    FROM users u
    LEFT JOIN valid_sessions v
        ON u.user_id = v.user_id
    GROUP BY
        u.user_id,
        u.signup_date
)
SELECT
    user_id,
    signup_date,
    cohort_month,
    active_days,
    first_session_date,
    last_session_date,
    retained_d1,
    retained_d7,
    retained_d30,
    CASE
        WHEN first_session_date IS NULL THEN 'No post-signup session'
        WHEN active_days = 1 THEN 'One-day user'
        WHEN active_days BETWEEN 2 AND 3 THEN 'Returning user'
        ELSE 'Frequent user'
    END AS retention_profile
FROM user_activity;


-- ------------------------------------------------------------
-- 3. BEHAVIORAL SEGMENTS
-- Grain: one row per active user
-- Supports: Behavioral Segments dashboard
--
-- The uploaded SQLite copy does not currently contain the prior
-- analytics_user_segments view. The project handoff records the
-- validated Phase D distribution, but not the segmentation thresholds.
-- Therefore we do NOT silently recreate the methodology here.
--
-- Two outputs are provided:
--   a) user behavior metrics for future joining to the original
--      segmentation view; and
--   b) the validated Phase D aggregate snapshot for Tableau.
-- ------------------------------------------------------------
DROP VIEW IF EXISTS analytics_tableau_behavioral_segments;
DROP VIEW IF EXISTS analytics_tableau_user_behavior;

CREATE VIEW analytics_tableau_user_behavior AS
WITH event_metrics AS (
    SELECT
        user_id,
        COUNT(DISTINCT session_id) AS sessions,
        COUNT(*) AS total_events,
        SUM(CASE WHEN event_type = 'content_impression' THEN 1 ELSE 0 END) AS impressions,
        SUM(CASE WHEN event_type = 'watch' THEN 1 ELSE 0 END) AS watch_events,
        SUM(CASE WHEN event_type = 'like' THEN 1 ELSE 0 END) AS likes,
        SUM(CASE WHEN event_type = 'swipe_next' THEN 1 ELSE 0 END) AS swipes,
        SUM(CASE WHEN event_type = 'watch' THEN watch_seconds ELSE 0 END) AS total_watch_seconds,
        COUNT(DISTINCT CASE WHEN event_type = 'content_impression' THEN content_id END) AS unique_content_items
    FROM events
    GROUP BY user_id
),
session_metrics AS (
    SELECT
        user_id,
        AVG(session_duration_minutes) AS avg_session_duration_minutes,
        SUM(session_duration_minutes) AS total_session_duration_minutes
    FROM sessions
    GROUP BY user_id
)
SELECT
    u.user_id,
    u.persona,
    u.signup_date,
    u.country,
    u.age,
    u.binge_tendency,
    u.engagement_rate,
    COALESCE(e.sessions, 0) AS sessions,
    ROUND(COALESCE(s.avg_session_duration_minutes, 0), 2) AS avg_session_duration_minutes,
    ROUND(COALESCE(s.total_session_duration_minutes, 0), 2) AS total_session_duration_minutes,
    COALESCE(e.total_events, 0) AS total_events,
    COALESCE(e.impressions, 0) AS impressions,
    COALESCE(e.watch_events, 0) AS watch_events,
    COALESCE(e.likes, 0) AS likes,
    COALESCE(e.swipes, 0) AS swipes,
    COALESCE(e.unique_content_items, 0) AS unique_content_items,
    ROUND(COALESCE(e.total_watch_seconds, 0), 2) AS total_watch_seconds,
    ROUND(
        100.0 * COALESCE(e.likes, 0) / NULLIF(e.watch_events, 0),
        2
    ) AS watch_to_like_rate_pct
FROM users u
LEFT JOIN event_metrics e
    ON u.user_id = e.user_id
LEFT JOIN session_metrics s
    ON u.user_id = s.user_id;

DROP VIEW IF EXISTS analytics_tableau_behavioral_segment_summary;

CREATE VIEW analytics_tableau_behavioral_segment_summary AS
SELECT 'Light Passive' AS behavioral_segment, 1129 AS users, 35.77 AS share_pct
UNION ALL
SELECT 'Deep Engager', 1129, 35.77
UNION ALL
SELECT 'Quick Engager', 449, 14.23
UNION ALL
SELECT 'Deep Consumer', 449, 14.23;


-- 4. CONSUMPTION LOOP METRICS
-- Grain: one row per session
-- Supports: Consumption Loops dashboard
--
-- Operational definition used here:
-- a return event occurs when the same content_id is encountered more
-- than once in the same session. This is intentionally called a
-- content-return loop, not recommendation causality.
-- ------------------------------------------------------------
DROP VIEW IF EXISTS analytics_tableau_consumption_loops;

CREATE VIEW analytics_tableau_consumption_loops AS
WITH impressions AS (
    SELECT
        session_id,
        user_id,
        content_id,
        event_id,
        ROW_NUMBER() OVER (
            PARTITION BY session_id, content_id
            ORDER BY event_id
        ) AS content_occurrence
    FROM events
    WHERE event_type = 'content_impression'
),
returns AS (
    SELECT
        session_id,
        user_id,
        content_id,
        event_id,
        content_occurrence,
        LAG(event_id) OVER (
            PARTITION BY session_id, content_id
            ORDER BY event_id
        ) AS previous_content_event_id
    FROM impressions
),
loop_summary AS (
    SELECT
        session_id,
        user_id,
        COUNT(*) AS return_events,
        MIN(event_id) AS first_return_event_id,
        AVG(event_id - previous_content_event_id) AS avg_return_event_gap_events
    FROM returns
    WHERE content_occurrence > 1
    GROUP BY session_id, user_id
)
SELECT
    s.session_id,
    s.user_id,
    s.persona,
    s.session_duration_minutes,
    s.exit_reason,
    CASE WHEN l.return_events > 0 THEN 1 ELSE 0 END AS has_content_return_loop,
    COALESCE(l.return_events, 0) AS return_events,
    ROUND(COALESCE(l.avg_return_event_gap_events, 0), 2) AS avg_return_event_gap_events,
    m.unique_content_items,
    m.watch_events,
    m.likes,
    m.total_watch_seconds
FROM sessions s
LEFT JOIN loop_summary l
    ON s.session_id = l.session_id
LEFT JOIN analytics_tableau_session_metrics m
    ON s.session_id = m.session_id;


-- ------------------------------------------------------------
-- 5. USER JOURNEY SUMMARY
-- Grain: one row per session
-- Supports: User Journey dashboard
-- ------------------------------------------------------------
DROP VIEW IF EXISTS analytics_tableau_user_journey;

CREATE VIEW analytics_tableau_user_journey AS
WITH ordered_events AS (
    SELECT
        e.session_id,
        e.user_id,
        e.event_id,
        e.content_id,
        e.event_type,
        SUM(
            CASE
                WHEN e.event_type = 'content_impression'
                THEN 1 ELSE 0
            END
        ) OVER (
            PARTITION BY e.session_id
            ORDER BY e.event_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS content_position
    FROM events e
),
first_like AS (
    SELECT
        session_id,
        MIN(content_position) AS first_like_position
    FROM ordered_events
    WHERE event_type = 'like'
    GROUP BY session_id
),
journey_quartiles AS (
    SELECT
        session_id,
        journey_quartile,
        COUNT(*) AS content_items,
        SUM(likes) AS likes,
        SUM(watch_seconds) AS watch_seconds
    FROM (
        SELECT
            i.session_id,
            i.content_id,
            i.journey_quartile,
            COALESCE(l.likes, 0) AS likes,
            COALESCE(w.watch_seconds, 0) AS watch_seconds
        FROM (
            SELECT
                session_id,
                content_id,
                NTILE(4) OVER (
                    PARTITION BY session_id
                    ORDER BY event_id
                ) AS journey_quartile
            FROM events
            WHERE event_type = 'content_impression'
        ) i
        LEFT JOIN (
            SELECT
                session_id,
                content_id,
                COUNT(*) AS likes
            FROM events
            WHERE event_type = 'like'
            GROUP BY session_id, content_id
        ) l
            ON i.session_id = l.session_id
           AND i.content_id = l.content_id
        LEFT JOIN (
            SELECT
                session_id,
                content_id,
                SUM(watch_seconds) AS watch_seconds
            FROM events
            WHERE event_type = 'watch'
            GROUP BY session_id, content_id
        ) w
            ON i.session_id = w.session_id
           AND i.content_id = w.content_id
    ) q
    GROUP BY session_id, journey_quartile
),
journey_metrics AS (
    SELECT
        session_id,
        SUM(CASE WHEN journey_quartile = 1 THEN content_items ELSE 0 END) AS q1_content_items,
        SUM(CASE WHEN journey_quartile = 2 THEN content_items ELSE 0 END) AS q2_content_items,
        SUM(CASE WHEN journey_quartile = 3 THEN content_items ELSE 0 END) AS q3_content_items,
        SUM(CASE WHEN journey_quartile = 4 THEN content_items ELSE 0 END) AS q4_content_items,
        SUM(CASE WHEN journey_quartile = 1 THEN likes ELSE 0 END) AS q1_likes,
        SUM(CASE WHEN journey_quartile = 2 THEN likes ELSE 0 END) AS q2_likes,
        SUM(CASE WHEN journey_quartile = 3 THEN likes ELSE 0 END) AS q3_likes,
        SUM(CASE WHEN journey_quartile = 4 THEN likes ELSE 0 END) AS q4_likes
    FROM journey_quartiles
    GROUP BY session_id
)
SELECT
    s.session_id,
    s.user_id,
    s.persona,
    s.session_duration_minutes,
    s.exit_reason,
    s.is_weekend,
    COALESCE(m.unique_content_items, 0) AS content_items,
    COALESCE(m.likes, 0) AS likes,
    ROUND(COALESCE(m.avg_watch_seconds, 0), 2) AS avg_watch_seconds,
    COALESCE(f.first_like_position, 0) AS first_like_position,
    COALESCE(j.q1_content_items, 0) AS q1_content_items,
    COALESCE(j.q2_content_items, 0) AS q2_content_items,
    COALESCE(j.q3_content_items, 0) AS q3_content_items,
    COALESCE(j.q4_content_items, 0) AS q4_content_items,
    COALESCE(j.q1_likes, 0) AS q1_likes,
    COALESCE(j.q2_likes, 0) AS q2_likes,
    COALESCE(j.q3_likes, 0) AS q3_likes,
    COALESCE(j.q4_likes, 0) AS q4_likes
FROM sessions s
LEFT JOIN analytics_tableau_session_metrics m
    ON s.session_id = m.session_id
LEFT JOIN first_like f
    ON s.session_id = f.session_id
LEFT JOIN journey_metrics j
    ON s.session_id = j.session_id;


-- ------------------------------------------------------------
-- 6. CONTENT PERFORMANCE
-- Grain: one row per content item
-- Supports: optional content/category analysis
-- ------------------------------------------------------------
DROP VIEW IF EXISTS analytics_tableau_content_performance;

CREATE VIEW analytics_tableau_content_performance AS
WITH event_metrics AS (
    SELECT
        content_id,
        COUNT(DISTINCT CASE WHEN event_type = 'content_impression' THEN session_id END) AS sessions_reached,
        SUM(CASE WHEN event_type = 'content_impression' THEN 1 ELSE 0 END) AS impressions,
        SUM(CASE WHEN event_type = 'video_start' THEN 1 ELSE 0 END) AS video_starts,
        SUM(CASE WHEN event_type = 'watch' THEN 1 ELSE 0 END) AS watches,
        SUM(CASE WHEN event_type = 'like' THEN 1 ELSE 0 END) AS likes,
        AVG(CASE WHEN event_type = 'watch' THEN watch_seconds END) AS avg_watch_seconds,
        SUM(CASE WHEN event_type = 'watch' THEN watch_seconds ELSE 0 END) AS total_watch_seconds
    FROM events
    GROUP BY content_id
)
SELECT
    c.content_id,
    c.creator_id,
    c.category,
    c.content_type,
    c.duration_seconds,
    DATE(c.upload_timestamp) AS upload_date,
    c.virality_score,
    c.trend_score,
    COALESCE(e.sessions_reached, 0) AS sessions_reached,
    COALESCE(e.impressions, 0) AS impressions,
    COALESCE(e.video_starts, 0) AS video_starts,
    COALESCE(e.watches, 0) AS watches,
    COALESCE(e.likes, 0) AS likes,
    ROUND(COALESCE(e.avg_watch_seconds, 0), 2) AS avg_watch_seconds,
    ROUND(COALESCE(e.total_watch_seconds, 0), 2) AS total_watch_seconds,
    ROUND(
        100.0 * COALESCE(e.likes, 0) / NULLIF(e.watches, 0),
        2
    ) AS like_rate_pct
FROM content c
LEFT JOIN event_metrics e
    ON c.content_id = e.content_id;


-- ------------------------------------------------------------
-- Verification helpers
-- ------------------------------------------------------------
-- SELECT name FROM sqlite_master
-- WHERE type = 'view' AND name LIKE 'analytics_tableau_%'
-- ORDER BY name;

-- ------------------------------------------------------------
-- 7. ENGAGEMENT DECAY SUMMARY
-- Grain: one row per journey quartile
-- ------------------------------------------------------------
DROP VIEW IF EXISTS analytics_tableau_engagement_decay_summary;

CREATE VIEW analytics_tableau_engagement_decay_summary AS
SELECT
    journey_quartile,
    SUM(content_items) AS content_items,
    SUM(likes) AS likes,
    ROUND(
        100.0 * SUM(likes) / NULLIF(SUM(content_items), 0),
        2
    ) AS like_rate_pct,
    ROUND(SUM(watch_seconds), 2) AS watch_seconds
FROM analytics_tableau_engagement_decay
GROUP BY journey_quartile;


-- ------------------------------------------------------------
-- 8. RETENTION COHORT SUMMARY
-- Grain: one row per signup cohort month
-- ------------------------------------------------------------
DROP VIEW IF EXISTS analytics_tableau_retention_cohort_summary;

CREATE VIEW analytics_tableau_retention_cohort_summary AS
SELECT
    cohort_month,
    COUNT(*) AS cohort_users,
    SUM(retained_d1) AS d1_users,
    SUM(retained_d7) AS d7_users,
    SUM(retained_d30) AS d30_users,
    ROUND(100.0 * SUM(retained_d1) / COUNT(*), 2) AS d1_retention_pct,
    ROUND(100.0 * SUM(retained_d7) / COUNT(*), 2) AS d7_retention_pct,
    ROUND(100.0 * SUM(retained_d30) / COUNT(*), 2) AS d30_retention_pct
FROM analytics_tableau_retention
GROUP BY cohort_month;


-- ------------------------------------------------------------
-- 9. VALIDATED PHASE E LOOP SUMMARY
-- Grain: one row per metric / segment
--
-- These values preserve the already-validated Phase E result because
-- the exact historical Phase E query is not present in the uploaded
-- SQLite copy. Do not reinterpret these as recommendation causality.
-- ------------------------------------------------------------
DROP VIEW IF EXISTS analytics_tableau_loop_summary;

CREATE VIEW analytics_tableau_loop_summary AS
SELECT 'Overall' AS scope, 'All sessions' AS segment, 5000 AS sessions, 667 AS loop_sessions,
       13.34 AS loop_session_rate_pct, 862 AS return_loop_events, 0.44 AS loop_event_rate_pct,
       70.31 AS avg_loop_session_duration_min, 73.79 AS avg_loop_session_content,
       27.05 AS avg_return_gap_watches, 1505.71 AS avg_return_time_seconds
UNION ALL
SELECT 'Segment', 'Deep Consumer', 0, 0, 29.00, NULL, NULL, NULL, NULL, NULL, NULL
UNION ALL
SELECT 'Segment', 'Deep Engager', 0, 0, 19.58, NULL, NULL, NULL, NULL, NULL, NULL
UNION ALL
SELECT 'Segment', 'Light Passive', 0, 0, 4.56, NULL, NULL, NULL, NULL, NULL, NULL
UNION ALL
SELECT 'Segment', 'Quick Engager', 0, 0, 4.48, NULL, NULL, NULL, NULL, NULL, NULL;
