import pandas as pd
import random
from datetime import timedelta

users_df = pd.read_csv("data/users.csv")
users_df.columns = users_df.columns.str.strip()

content_df = pd.read_csv("data/content.csv")
content_df.columns = content_df.columns.str.strip()

sessions_df = pd.read_csv("data/sessions.csv")
sessions_df.columns = sessions_df.columns.str.strip()

EVENTS = []

EVENT_ID = 1


def select_content(user):

    favorite_categories = user[
        "favorite_categories"
    ].split(",")

    preferred = content_df[
        content_df["category"].isin(
            favorite_categories
        )
    ]

    other = content_df[
        ~content_df["category"].isin(
            favorite_categories
        )
    ]

    # 70% preferred content
    if random.random() < 0.7:
        return preferred.sample(1).iloc[0]

    return other.sample(1).iloc[0]


def calculate_watch_time(
    persona,
    content_duration,
    preferred_category
):

    if persona == "binge_user":
        watch_ratio = random.uniform(0.5, 1.0)

    elif persona == "passive_scroller":
        watch_ratio = random.uniform(0.05, 0.4)

    elif persona == "active_engager":
        watch_ratio = random.uniform(0.4, 0.9)

    else:
        watch_ratio = random.uniform(0.2, 0.7)

    if preferred_category:
        watch_ratio *= 1.2

    watch_ratio = min(watch_ratio, 1)

    return float(round(
        content_duration * watch_ratio,
        2
    ))


for index, session in sessions_df.iterrows():

    if index % 500 == 0:
        print(f"Processing session {index}")

    user = users_df[
        users_df["user_id"] == session["user_id"]
    ].iloc[0]

    favorite_categories = user[
        "favorite_categories"
    ].split(",")

    session_start = pd.to_datetime(
        session["session_start"]
    )

    session_duration_seconds = (
        session["session_duration_minutes"] * 60
    )

    current_time = session_start

    elapsed = 0

    while elapsed < session_duration_seconds:

        content = select_content(user)

        preferred_category = (
            content["category"]
            in favorite_categories
        )

        watch_time = calculate_watch_time(
            user["persona"],
            content["duration_seconds"],
            preferred_category
        )

        # Decide whether this interaction will contain a like
        # before calculating the total interaction duration.
        will_like = (
            random.random()
            < user["engagement_rate"]
        )

        # Complete interaction:
        # impression -> video_start -> watch -> [like] -> swipe_next
        interaction_seconds = (
            1
            + watch_time
            + (1 if will_like else 0)
            + 1
        )

        remaining_seconds = (
            session_duration_seconds - elapsed
        )

        # Do not generate a partial interaction that would
        # extend beyond the session boundary.
        if interaction_seconds > remaining_seconds:
            break

        # ----------------------------------------------------
        # CONTENT IMPRESSION
        # ----------------------------------------------------

        EVENTS.append({
            "event_id": EVENT_ID,
            "session_id": session["session_id"],
            "user_id": user["user_id"],
            "content_id": content["content_id"],
            "event_type": "content_impression",
            "timestamp": current_time,
            "watch_seconds": None
        })

        EVENT_ID += 1

        # ----------------------------------------------------
        # VIDEO START
        # ----------------------------------------------------

        current_time += timedelta(seconds=1)

        EVENTS.append({
            "event_id": EVENT_ID,
            "session_id": session["session_id"],
            "user_id": user["user_id"],
            "content_id": content["content_id"],
            "event_type": "video_start",
            "timestamp": current_time,
            "watch_seconds": None
        })

        EVENT_ID += 1

        # ----------------------------------------------------
        # WATCH EVENT
        # ----------------------------------------------------

        current_time += timedelta(
            seconds=float(watch_time)
        )

        EVENTS.append({
            "event_id": EVENT_ID,
            "session_id": session["session_id"],
            "user_id": user["user_id"],
            "content_id": content["content_id"],
            "event_type": "watch",
            "timestamp": current_time,
            "watch_seconds": watch_time
        })

        EVENT_ID += 1

        # ----------------------------------------------------
        # LIKE EVENT
        # ----------------------------------------------------

        if will_like:

            current_time += timedelta(seconds=1)

            EVENTS.append({
                "event_id": EVENT_ID,
                "session_id": session["session_id"],
                "user_id": user["user_id"],
                "content_id": content["content_id"],
                "event_type": "like",
                "timestamp": current_time,
                "watch_seconds": None
            })

            EVENT_ID += 1

        # ----------------------------------------------------
        # SWIPE NEXT
        # ----------------------------------------------------

        current_time += timedelta(seconds=1)

        EVENTS.append({
            "event_id": EVENT_ID,
            "session_id": session["session_id"],
            "user_id": user["user_id"],
            "content_id": content["content_id"],
            "event_type": "swipe_next",
            "timestamp": current_time,
            "watch_seconds": None
        })

        EVENT_ID += 1

        elapsed = (
            current_time - session_start
        ).total_seconds()


events_df = pd.DataFrame(EVENTS)

events_df.to_csv(
    "data/events.csv",
    index=False
)

print("events.csv generated successfully")
print(events_df.head())