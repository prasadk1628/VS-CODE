-- ============================================================
-- DoomScroll Analytics Engine
-- Phase F: User Journey Analysis
-- ============================================================

-- ============================================================
-- QUERY 1
-- Journey Integrity
--
-- Question:
-- Are content journeys structurally complete?
--
-- Expected path:
-- impression -> video_start -> watch -> swipe_next
--
-- This is a validation query, not a business insight.
-- ============================================================

WITH content_journeys AS (

    SELECT
        session_id,
        user_id,
        content_id,
        event_id,
        event_type,
        LEAD(event_type, 1) OVER (
            PARTITION BY session_id
            ORDER BY event_id
        ) AS next_event_1,
        LEAD(event_type, 2) OVER (
            PARTITION BY session_id
            ORDER BY event_id
        ) AS next_event_2,
        LEAD(event_type, 3) OVER (
            PARTITION BY session_id
            ORDER BY event_id
        ) AS next_event_3

    FROM events

)

SELECT
    COUNT(*) AS impressions,

    SUM(
        CASE
            WHEN next_event_1 = 'video_start'
            THEN 1 ELSE 0
        END
    ) AS followed_by_start,

    SUM(
        CASE
            WHEN next_event_1 = 'video_start'
             AND next_event_2 = 'watch'
            THEN 1 ELSE 0
        END
    ) AS followed_by_watch,

    SUM(
        CASE
            WHEN next_event_1 = 'video_start'
             AND next_event_2 = 'watch'
             AND (
                 next_event_3 = 'swipe_next'
                 OR next_event_3 = 'like'
             )
            THEN 1 ELSE 0
        END
    ) AS followed_by_engagement_action

FROM content_journeys
WHERE event_type = 'content_impression';


-- ============================================================
-- QUERY 2
-- Watch -> Like Conversion
--
-- Question:
-- How frequently does watching turn into active engagement?
-- ============================================================

WITH watch_events AS (

    SELECT
        session_id,
        user_id,
        content_id,
        event_id,
        watch_seconds,

        LEAD(event_type) OVER (
            PARTITION BY session_id
            ORDER BY event_id
        ) AS next_event

    FROM events

    WHERE event_type = 'watch'

)

SELECT

    COUNT(*) AS watch_events,

    SUM(
        CASE
            WHEN next_event = 'like'
            THEN 1 ELSE 0
        END
    ) AS liked_after_watch,

    ROUND(
        100.0 *
        SUM(
            CASE
                WHEN next_event = 'like'
                THEN 1 ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS watch_to_like_rate_pct,

    ROUND(
        AVG(watch_seconds),
        2
    ) AS avg_watch_seconds

FROM watch_events;


-- ============================================================
-- QUERY 3
-- Position of First Like
-- Correct event-level implementation
-- ============================================================

WITH ordered_events AS (

    SELECT
        session_id,
        user_id,
        event_id,
        event_type,

        SUM(
            CASE
                WHEN event_type = 'content_impression'
                THEN 1
                ELSE 0
            END
        ) OVER (
            PARTITION BY session_id
            ORDER BY event_id
            ROWS BETWEEN UNBOUNDED PRECEDING
            AND CURRENT ROW
        ) AS content_position

    FROM events

),

first_like AS (

    SELECT
        session_id,
        MIN(content_position) AS first_like_position

    FROM ordered_events

    WHERE event_type = 'like'

    GROUP BY session_id

)

SELECT

    COUNT(*) AS sessions_with_like,

    ROUND(
        AVG(first_like_position),
        2
    ) AS avg_first_like_position,

    MIN(first_like_position) AS earliest_like,

    MAX(first_like_position) AS latest_first_like

FROM first_like;

-- ============================================================
-- QUERY 4
-- Engagement by Session Depth
--
-- Question:
-- Does active engagement become more or less common
-- as users progress through a session?
--
-- We divide content journeys into quartiles.
-- ============================================================

WITH content_journeys AS (

    SELECT
        session_id,
        user_id,
        content_id,
        event_id,

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
        content_id

    FROM events

    WHERE event_type = 'like'

)

SELECT

    cj.journey_quartile,

    COUNT(*) AS content_items,

    COUNT(l.content_id) AS liked_items,

    ROUND(
        100.0 *
        COUNT(l.content_id) / COUNT(*),
        2
    ) AS like_rate_pct

FROM content_journeys cj

LEFT JOIN likes l
    ON cj.session_id = l.session_id
   AND cj.content_id = l.content_id

GROUP BY cj.journey_quartile

ORDER BY cj.journey_quartile;


-- ============================================================
-- QUERY 5
-- Preferred vs Non-Preferred Content Journey
--
-- Question:
-- Do users continue deeper into content that matches
-- their stated category preferences?
-- ============================================================

WITH content_journey AS (

    SELECT
        e.session_id,
        e.user_id,
        e.content_id,
        e.event_id,

        CASE
            WHEN INSTR(
                ',' || REPLACE(u.favorite_categories, ' ', '') || ',',
                ',' || c.category || ','
            ) > 0
            THEN 1
            ELSE 0
        END AS is_preferred

    FROM events e

    JOIN users u
        ON e.user_id = u.user_id

    JOIN content c
        ON e.content_id = c.content_id

    WHERE e.event_type = 'content_impression'

),

session_summary AS (

    SELECT
        session_id,
        user_id,

        COUNT(*) AS content_items,

        SUM(is_preferred) AS preferred_items,

        ROUND(
            100.0 * SUM(is_preferred) / COUNT(*),
            2
        ) AS preferred_content_pct

    FROM content_journey

    GROUP BY session_id, user_id

)

SELECT

    CASE
        WHEN preferred_content_pct >= 70
            THEN 'Preference-heavy'
        WHEN preferred_content_pct >= 50
            THEN 'Mixed'
        ELSE 'Preference-light'
    END AS journey_type,

    COUNT(*) AS sessions,

    ROUND(
        AVG(content_items),
        2
    ) AS avg_content_items,

    ROUND(
        AVG(preferred_content_pct),
        2
    ) AS avg_preferred_content_pct

FROM session_summary

GROUP BY journey_type

ORDER BY avg_content_items DESC;


-- ============================================================
-- QUERY 6
-- Journey Archetypes by Behavioral Segment
--
-- Question:
-- Do behavior-derived user segments exhibit different
-- journey patterns?
--
-- Uses existing analytics_user_segments view.
-- ============================================================

WITH session_journey AS (

    SELECT
        e.session_id,
        e.user_id,

        COUNT(
            DISTINCT CASE
                WHEN e.event_type = 'content_impression'
                THEN e.content_id
            END
        ) AS content_items,

        COUNT(
            CASE
                WHEN e.event_type = 'like'
                THEN 1
            END
        ) AS likes,

        COUNT(
            CASE
                WHEN e.event_type = 'swipe_next'
                THEN 1
            END
        ) AS swipes

    FROM events e

    GROUP BY
        e.session_id,
        e.user_id

)

SELECT

    s.behavioral_segment,

    COUNT(*) AS sessions,

    ROUND(
        AVG(j.content_items),
        2
    ) AS avg_content_items,

    ROUND(
        AVG(j.likes),
        2
    ) AS avg_likes,

    ROUND(
        AVG(j.swipes),
        2
    ) AS avg_swipes,

    ROUND(
        100.0 *
        SUM(
            CASE
                WHEN j.likes > 0
                THEN 1 ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS pct_sessions_with_like

FROM session_journey j

JOIN analytics_user_segments s
    ON j.user_id = s.user_id

GROUP BY
    s.behavioral_segment

ORDER BY
    avg_content_items DESC;
