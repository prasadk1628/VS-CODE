-- ============================================================
-- DoomScroll Analytics Engine
-- 04 - Engagement Analysis
-- ============================================================


-- ============================================================
-- 1. WATCH COMPLETION
-- How much of each piece of content do users watch?
-- ============================================================

SELECT
    COUNT(*) AS total_watches,

    ROUND(
        AVG(
            watch_seconds
            / NULLIF(c.duration_seconds, 0)
        ),
        3
    ) AS avg_completion_ratio,

    ROUND(
        AVG(watch_seconds),
        2
    ) AS avg_watch_seconds,

    ROUND(
        AVG(c.duration_seconds),
        2
    ) AS avg_content_duration

FROM events e

JOIN content c
    ON e.content_id = c.content_id

WHERE e.event_type = 'watch';
-- ============================================================
-- 2. WATCH COMPLETION BY PERSONA
-- ============================================================

SELECT
    s.persona,

    COUNT(*) AS total_watches,

    ROUND(
        AVG(
            e.watch_seconds
            / NULLIF(c.duration_seconds, 0)
        ),
        3
    ) AS avg_completion_ratio,

    ROUND(
        AVG(e.watch_seconds),
        2
    ) AS avg_watch_seconds,

    ROUND(
        AVG(c.duration_seconds),
        2
    ) AS avg_content_duration

FROM events e

JOIN sessions s
    ON e.session_id = s.session_id

JOIN content c
    ON e.content_id = c.content_id

WHERE e.event_type = 'watch'

GROUP BY s.persona

ORDER BY avg_completion_ratio DESC;
-- ============================================================
-- 3. WATCH COMPLETION VS LIKE BEHAVIOR
-- Are deeper watches associated with more active engagement?
-- ============================================================

WITH watch_events AS (

    SELECT
        e.session_id,
        e.content_id,
        e.watch_seconds,

        e.watch_seconds
        / NULLIF(c.duration_seconds, 0)
        AS completion_ratio

    FROM events e

    JOIN content c
        ON e.content_id = c.content_id

    WHERE e.event_type = 'watch'
),

like_events AS (

    SELECT
        session_id,
        content_id

    FROM events

    WHERE event_type = 'like'
),

completion_bands AS (

    SELECT
        w.session_id,
        w.content_id,
        w.completion_ratio,

        CASE
            WHEN w.completion_ratio < 0.25
                THEN '<25%'

            WHEN w.completion_ratio < 0.50
                THEN '25-49%'

            WHEN w.completion_ratio < 0.75
                THEN '50-74%'

            WHEN w.completion_ratio < 0.90
                THEN '75-89%'

            ELSE '90%+'
        END AS completion_band,

        CASE
            WHEN l.session_id IS NOT NULL
                THEN 1
            ELSE 0
        END AS was_liked

    FROM watch_events w

    LEFT JOIN like_events l
        ON w.session_id = l.session_id
        AND w.content_id = l.content_id
)

SELECT
    completion_band,

    COUNT(*) AS watches,

    SUM(was_liked) AS likes,

    ROUND(
        AVG(was_liked),
        4
    ) AS like_rate

FROM completion_bands

GROUP BY completion_band

ORDER BY
    CASE completion_band
        WHEN '<25%' THEN 1
        WHEN '25-49%' THEN 2
        WHEN '50-74%' THEN 3
        WHEN '75-89%' THEN 4
        WHEN '90%+' THEN 5
    END;

-- ============================================================
-- 4. WATCH COMPLETION VS LIKE RATE WITHIN PERSONA
-- Controls for persona-level differences.
-- ============================================================

WITH watch_events AS (

    SELECT
        e.session_id,
        e.content_id,
        s.persona,
        e.watch_seconds,

        e.watch_seconds
        / NULLIF(c.duration_seconds, 0)
        AS completion_ratio

    FROM events e

    JOIN sessions s
        ON e.session_id = s.session_id

    JOIN content c
        ON e.content_id = c.content_id

    WHERE e.event_type = 'watch'
),

like_events AS (

    SELECT DISTINCT
        session_id,
        content_id

    FROM events

    WHERE event_type = 'like'
),

completion_bands AS (

    SELECT
        w.persona,
        w.session_id,
        w.content_id,

        CASE
            WHEN w.completion_ratio < 0.25
                THEN '<25%'

            WHEN w.completion_ratio < 0.50
                THEN '25-49%'

            WHEN w.completion_ratio < 0.75
                THEN '50-74%'

            WHEN w.completion_ratio < 0.90
                THEN '75-89%'

            ELSE '90%+'
        END AS completion_band,

        CASE
            WHEN l.session_id IS NOT NULL
                THEN 1
            ELSE 0
        END AS was_liked

    FROM watch_events w

    LEFT JOIN like_events l
        ON w.session_id = l.session_id
        AND w.content_id = l.content_id
)

SELECT
    persona,
    completion_band,

    COUNT(*) AS watches,

    SUM(was_liked) AS likes,

    ROUND(
        AVG(was_liked),
        4
    ) AS like_rate

FROM completion_bands

GROUP BY
    persona,
    completion_band

ORDER BY
    CASE persona
        WHEN 'passive_scroller' THEN 1
        WHEN 'trend_hopper' THEN 2
        WHEN 'active_engager' THEN 3
        WHEN 'binge_user' THEN 4
    END,

    CASE completion_band
        WHEN '<25%' THEN 1
        WHEN '25-49%' THEN 2
        WHEN '50-74%' THEN 3
        WHEN '75-89%' THEN 4
        WHEN '90%+' THEN 5
    END;
-- ============================================================
-- 5. PREFERRED VS NON-PREFERRED CONTENT
-- ============================================================

WITH watch_events AS (

    SELECT
        e.session_id,
        e.content_id,
        e.watch_seconds,
        s.user_id,
        u.persona,
        u.favorite_categories,
        c.duration_seconds,

        CASE
            WHEN ',' || u.favorite_categories || ','
                 LIKE '%,' || c.category || ',%'
            THEN 1
            ELSE 0
        END AS is_preferred

    FROM events e

    JOIN sessions s
        ON e.session_id = s.session_id

    JOIN users u
        ON s.user_id = u.user_id

    JOIN content c
        ON e.content_id = c.content_id

    WHERE e.event_type = 'watch'
),

like_events AS (

    SELECT DISTINCT
        session_id,
        content_id

    FROM events

    WHERE event_type = 'like'
),

metrics AS (

    SELECT
        w.is_preferred,

        w.watch_seconds
            / NULLIF(w.duration_seconds, 0)
            AS completion_ratio,

        CASE
            WHEN l.session_id IS NOT NULL
                THEN 1
            ELSE 0
        END AS was_liked

    FROM watch_events w

    LEFT JOIN like_events l
        ON w.session_id = l.session_id
        AND w.content_id = l.content_id
)

SELECT
    CASE
        WHEN is_preferred = 1
            THEN 'Preferred'
        ELSE 'Non-preferred'
    END AS content_preference,

    COUNT(*) AS watches,

    ROUND(
        AVG(completion_ratio),
        3
    ) AS avg_completion_ratio,

    ROUND(
        AVG(was_liked),
        4
    ) AS like_rate

FROM metrics

GROUP BY is_preferred;
-- ============================================================
-- 6. PREFERRED CONTENT WITHIN PERSONA
-- Controls for persona-level behavioral differences.
-- ============================================================

WITH watch_events AS (

    SELECT
        e.session_id,
        e.content_id,
        s.user_id,
        s.persona,
        e.watch_seconds,
        c.duration_seconds,

        CASE
            WHEN ',' || u.favorite_categories || ','
                 LIKE '%,' || c.category || ',%'
            THEN 1
            ELSE 0
        END AS is_preferred

    FROM events e

    JOIN sessions s
        ON e.session_id = s.session_id

    JOIN users u
        ON s.user_id = u.user_id

    JOIN content c
        ON e.content_id = c.content_id

    WHERE e.event_type = 'watch'
),

like_events AS (

    SELECT DISTINCT
        session_id,
        content_id

    FROM events

    WHERE event_type = 'like'
)

SELECT
    w.persona,

    CASE
        WHEN w.is_preferred = 1
            THEN 'Preferred'
        ELSE 'Non-preferred'
    END AS content_preference,

    COUNT(*) AS watches,

    ROUND(
        AVG(
            w.watch_seconds
            / NULLIF(w.duration_seconds, 0)
        ),
        3
    ) AS avg_completion_ratio,

    ROUND(
        AVG(
            CASE
                WHEN l.session_id IS NOT NULL
                    THEN 1.0
                ELSE 0.0
            END
        ),
        4
    ) AS like_rate

FROM watch_events w

LEFT JOIN like_events l
    ON w.session_id = l.session_id
    AND w.content_id = l.content_id

GROUP BY
    w.persona,
    w.is_preferred

ORDER BY
    CASE w.persona
        WHEN 'passive_scroller' THEN 1
        WHEN 'trend_hopper' THEN 2
        WHEN 'active_engager' THEN 3
        WHEN 'binge_user' THEN 4
    END,
    w.is_preferred;
-- ============================================================
-- 7. EVENT SEQUENCE COMPLETENESS
-- Does each watch generally lead to a swipe?
-- ============================================================

WITH session_events AS (

    SELECT
        session_id,

        SUM(
            CASE
                WHEN event_type = 'watch'
                THEN 1
                ELSE 0
            END
        ) AS watches,

        SUM(
            CASE
                WHEN event_type = 'swipe_next'
                THEN 1
                ELSE 0
            END
        ) AS swipes,

        SUM(
            CASE
                WHEN event_type = 'like'
                THEN 1
                ELSE 0
            END
        ) AS likes

    FROM events

    GROUP BY session_id
)

SELECT
    COUNT(*) AS sessions,

    SUM(
        CASE
            WHEN watches = swipes
            THEN 1
            ELSE 0
        END
    ) AS sessions_matching_watch_swipe,

    SUM(
        CASE
            WHEN watches != swipes
            THEN 1
            ELSE 0
        END
    ) AS sessions_with_mismatch,

    ROUND(
        AVG(
            CAST(likes AS REAL)
            / NULLIF(watches, 0)
        ),
        4
    ) AS avg_like_to_watch_ratio

FROM session_events;
-- ============================================================
-- 8. PASSIVE VS ACTIVE CONSUMPTION
-- ============================================================

WITH session_metrics AS (

    SELECT
        s.session_id,
        s.persona,
        s.session_duration_minutes,

        COUNT(
            CASE
                WHEN e.event_type = 'watch'
                THEN 1
            END
        ) AS watches,

        COUNT(
            CASE
                WHEN e.event_type = 'like'
                THEN 1
            END
        ) AS likes,

        SUM(
            CASE
                WHEN e.event_type = 'watch'
                THEN e.watch_seconds
                ELSE 0
            END
        ) AS total_watch_seconds

    FROM sessions s

    LEFT JOIN events e
        ON s.session_id = e.session_id

    GROUP BY
        s.session_id,
        s.persona,
        s.session_duration_minutes
),

classified_sessions AS (

    SELECT
        *,

        CAST(likes AS REAL)
            / NULLIF(watches, 0)
            AS like_rate,

        CASE
            WHEN CAST(likes AS REAL)
                 / NULLIF(watches, 0) < 0.05
                THEN 'Passive'

            WHEN CAST(likes AS REAL)
                 / NULLIF(watches, 0) <= 0.15
                THEN 'Moderate'

            ELSE 'Active'
        END AS engagement_segment

    FROM session_metrics
)

SELECT
    engagement_segment,

    COUNT(*) AS sessions,

    ROUND(
        AVG(session_duration_minutes),
        2
    ) AS avg_session_minutes,

    ROUND(
        AVG(watches),
        2
    ) AS avg_watches,

    ROUND(
        AVG(total_watch_seconds),
        2
    ) AS avg_watch_seconds,

    ROUND(
        AVG(like_rate),
        4
    ) AS avg_like_rate

FROM classified_sessions

GROUP BY engagement_segment

ORDER BY
    CASE engagement_segment
        WHEN 'Passive' THEN 1
        WHEN 'Moderate' THEN 2
        WHEN 'Active' THEN 3
    END;
-- ============================================================
-- 9. ENGAGEMENT INTENSITY QUINTILES
-- Data-driven segmentation without arbitrary thresholds.
-- ============================================================

WITH session_metrics AS (

    SELECT
        s.session_id,
        s.persona,
        s.session_duration_minutes,

        COUNT(
            CASE
                WHEN e.event_type = 'watch'
                THEN 1
            END
        ) AS watches,

        COUNT(
            CASE
                WHEN e.event_type = 'like'
                THEN 1
            END
        ) AS likes,

        SUM(
            CASE
                WHEN e.event_type = 'watch'
                THEN e.watch_seconds
                ELSE 0
            END
        ) AS total_watch_seconds

    FROM sessions s

    LEFT JOIN events e
        ON s.session_id = e.session_id

    GROUP BY
        s.session_id,
        s.persona,
        s.session_duration_minutes
),

ranked_sessions AS (

    SELECT
        *,

        CAST(likes AS REAL)
            / NULLIF(watches, 0)
            AS like_rate,

        NTILE(5) OVER (
            ORDER BY
                CAST(likes AS REAL)
                / NULLIF(watches, 0)
        ) AS engagement_quintile

    FROM session_metrics
)

SELECT
    engagement_quintile,

    COUNT(*) AS sessions,

    ROUND(
        AVG(like_rate),
        4
    ) AS avg_like_rate,

    ROUND(
        AVG(session_duration_minutes),
        2
    ) AS avg_session_minutes,

    ROUND(
        AVG(watches),
        2
    ) AS avg_watches,

    ROUND(
        AVG(total_watch_seconds),
        2
    ) AS avg_watch_seconds

FROM ranked_sessions

GROUP BY engagement_quintile

ORDER BY engagement_quintile;
-- ============================================================
-- 10. PERSONA-CONTROLLED ENGAGEMENT QUINTILES
-- Does the relationship between active engagement and
-- consumption depth remain within each persona?
-- ============================================================

WITH session_metrics AS (

    SELECT
        s.session_id,
        s.persona,
        s.session_duration_minutes,

        COUNT(
            CASE
                WHEN e.event_type = 'watch'
                THEN 1
            END
        ) AS watches,

        COUNT(
            CASE
                WHEN e.event_type = 'like'
                THEN 1
            END
        ) AS likes,

        SUM(
            CASE
                WHEN e.event_type = 'watch'
                THEN e.watch_seconds
                ELSE 0
            END
        ) AS total_watch_seconds

    FROM sessions s

    LEFT JOIN events e
        ON s.session_id = e.session_id

    GROUP BY
        s.session_id,
        s.persona,
        s.session_duration_minutes
),

ranked_sessions AS (

    SELECT
        *,

        CAST(likes AS REAL)
            / NULLIF(watches, 0)
            AS like_rate,

        NTILE(5) OVER (
            PARTITION BY persona
            ORDER BY
                CAST(likes AS REAL)
                / NULLIF(watches, 0)
        ) AS engagement_quintile

    FROM session_metrics
)

SELECT
    persona,
    engagement_quintile,

    COUNT(*) AS sessions,

    ROUND(
        AVG(like_rate),
        4
    ) AS avg_like_rate,

    ROUND(
        AVG(session_duration_minutes),
        2
    ) AS avg_session_minutes,

    ROUND(
        AVG(watches),
        2
    ) AS avg_watches,

    ROUND(
        AVG(total_watch_seconds),
        2
    ) AS avg_watch_seconds

FROM ranked_sessions

GROUP BY
    persona,
    engagement_quintile

ORDER BY
    CASE persona
        WHEN 'passive_scroller' THEN 1
        WHEN 'trend_hopper' THEN 2
        WHEN 'active_engager' THEN 3
        WHEN 'binge_user' THEN 4
    END,
    engagement_quintile;

-- ============================================================
-- 11. PREFERRED CONTENT BY ENGAGEMENT QUINTILE
-- Does content preference differ across engagement intensity?
-- Controlled for persona.
-- ============================================================

WITH session_metrics AS (

    SELECT
        s.session_id,
        s.persona,
        s.session_duration_minutes,

        COUNT(
            CASE
                WHEN e.event_type = 'watch'
                THEN 1
            END
        ) AS watches,

        COUNT(
            CASE
                WHEN e.event_type = 'like'
                THEN 1
            END
        ) AS likes

    FROM sessions s

    LEFT JOIN events e
        ON s.session_id = e.session_id

    GROUP BY
        s.session_id,
        s.persona,
        s.session_duration_minutes
),

ranked_sessions AS (

    SELECT
        *,

        CAST(likes AS REAL)
            / NULLIF(watches, 0)
            AS like_rate,

        NTILE(5) OVER (
            PARTITION BY persona
            ORDER BY
                CAST(likes AS REAL)
                / NULLIF(watches, 0)
        ) AS engagement_quintile

    FROM session_metrics
),

content_exposure AS (

    SELECT
        e.session_id,

        COUNT(
            CASE
                WHEN e.event_type = 'watch'
                THEN 1
            END
        ) AS total_watches,

        SUM(
            CASE
                WHEN e.event_type = 'watch'
                 AND ',' || u.favorite_categories || ','
                     LIKE '%,' || c.category || ','
                THEN 1
                ELSE 0
            END
        ) AS preferred_watches

    FROM events e

    JOIN sessions s
        ON e.session_id = s.session_id

    JOIN users u
        ON s.user_id = u.user_id

    JOIN content c
        ON e.content_id = c.content_id

    WHERE e.event_type = 'watch'

    GROUP BY e.session_id
)

SELECT
    r.persona,
    r.engagement_quintile,

    COUNT(*) AS sessions,

    ROUND(
        AVG(
            CAST(
                COALESCE(
                    ce.preferred_watches,
                    0
                ) AS REAL
            )
            / NULLIF(
                ce.total_watches,
                0
            )
        ),
        4
    ) AS avg_preferred_watch_share,

    ROUND(
        AVG(r.session_duration_minutes),
        2
    ) AS avg_session_minutes,

    ROUND(
        AVG(r.watches),
        2
    ) AS avg_watches

FROM ranked_sessions r

LEFT JOIN content_exposure ce
    ON r.session_id = ce.session_id

GROUP BY
    r.persona,
    r.engagement_quintile

ORDER BY
    CASE r.persona
        WHEN 'passive_scroller' THEN 1
        WHEN 'trend_hopper' THEN 2
        WHEN 'active_engager' THEN 3
        WHEN 'binge_user' THEN 4
    END,
    r.engagement_quintile;

-- ============================================================
-- 12. SESSION-LEVEL ANALYTICAL VIEW
-- Reusable session-level metrics for downstream analysis.
-- ============================================================

DROP VIEW IF EXISTS analytics_session_metrics;

CREATE VIEW analytics_session_metrics AS

WITH session_events AS (

    SELECT
        e.session_id,

        COUNT(*) AS total_events,

        SUM(
            CASE
                WHEN e.event_type = 'watch'
                THEN 1
                ELSE 0
            END
        ) AS watch_count,

        SUM(
            CASE
                WHEN e.event_type = 'like'
                THEN 1
                ELSE 0
            END
        ) AS like_count,

        SUM(
            CASE
                WHEN e.event_type = 'swipe_next'
                THEN 1
                ELSE 0
            END
        ) AS swipe_count,

        SUM(
            CASE
                WHEN e.event_type = 'watch'
                THEN e.watch_seconds
                ELSE 0
            END
        ) AS total_watch_seconds,

        AVG(
            CASE
                WHEN e.event_type = 'watch'
                THEN e.watch_seconds
            END
        ) AS avg_watch_seconds

    FROM events e

    GROUP BY e.session_id
),

watch_metrics AS (

    SELECT
        e.session_id,

        AVG(
            e.watch_seconds
            / NULLIF(c.duration_seconds, 0)
        ) AS avg_completion_ratio,

        SUM(
            CASE
                WHEN ',' || u.favorite_categories || ','
                     LIKE '%,' || c.category || ','
                THEN 1
                ELSE 0
            END
        ) AS preferred_watch_count

    FROM events e

    JOIN sessions s
        ON e.session_id = s.session_id

    JOIN users u
        ON s.user_id = u.user_id

    JOIN content c
        ON e.content_id = c.content_id

    WHERE e.event_type = 'watch'

    GROUP BY e.session_id
)

SELECT
    s.session_id,
    s.user_id,
    s.persona,
    s.session_start,
    s.session_end,
    s.session_duration_minutes,
    s.exit_reason,
    s.is_weekend,

    COALESCE(se.total_events, 0)
        AS total_events,

    COALESCE(se.watch_count, 0)
        AS watch_count,

    COALESCE(se.like_count, 0)
        AS like_count,

    COALESCE(se.swipe_count, 0)
        AS swipe_count,

    ROUND(
        COALESCE(se.total_watch_seconds, 0),
        2
    ) AS total_watch_seconds,

    ROUND(
        COALESCE(se.avg_watch_seconds, 0),
        2
    ) AS avg_watch_seconds,

    ROUND(
        COALESCE(wm.avg_completion_ratio, 0),
        3
    ) AS avg_completion_ratio,

    COALESCE(
        wm.preferred_watch_count,
        0
    ) AS preferred_watch_count,

    ROUND(
        CAST(
            COALESCE(wm.preferred_watch_count, 0)
            AS REAL
        )
        / NULLIF(
            COALESCE(se.watch_count, 0),
            0
        ),
        3
    ) AS preferred_watch_share,

    ROUND(
        CAST(
            COALESCE(se.total_events, 0)
            AS REAL
        )
        / NULLIF(
            s.session_duration_minutes,
            0
        ),
        2
    ) AS events_per_minute,

    ROUND(
        CAST(
            COALESCE(se.watch_count, 0)
            AS REAL
        )
        / NULLIF(
            s.session_duration_minutes,
            0
        ),
        2
    ) AS watches_per_minute,

    ROUND(
        CAST(
            COALESCE(se.like_count, 0)
            AS REAL
        )
        / NULLIF(
            COALESCE(se.watch_count, 0),
            0
        ),
        4
    ) AS like_rate

FROM sessions s

LEFT JOIN session_events se
    ON s.session_id = se.session_id

LEFT JOIN watch_metrics wm
    ON s.session_id = wm.session_id;