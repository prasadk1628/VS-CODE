import pandas as pd
import numpy as np
import random
from datetime import datetime, timedelta

users_df = pd.read_csv("data/users.csv")
users_df.columns = users_df.columns.str.strip()

NUM_SESSIONS = 5000

EXIT_REASONS = [
    "fatigue",
    "boredom",
    "interruption",
    "goal_completed"
]


def generate_session_time():

    start_date = datetime(2025, 1, 1)
    end_date = datetime(2026, 5, 1)

    random_days = random.randint(
        0,
        (end_date - start_date).days
    )

    base_date = start_date + timedelta(days=random_days)

    # Realistic usage hours
    hour_weights = {
        8: 2,
        9: 3,
        12: 5,
        13: 6,
        18: 8,
        19: 10,
        20: 12,
        21: 15,
        22: 14,
        23: 12,
        0: 8,
        1: 6
    }

    hours = list(hour_weights.keys())
    weights = list(hour_weights.values())

    selected_hour = random.choices(hours, weights=weights, k=1)[0]

    minute = random.randint(0, 59)
    second = random.randint(0, 59)

    return base_date.replace(
        hour=selected_hour,
        minute=minute,
        second=second
    )


def calculate_session_duration(persona):

    if persona == "passive_scroller":
        return random.randint(2, 15)

    elif persona == "binge_user":
        return random.randint(30, 120)

    elif persona == "active_engager":
        return random.randint(10, 45)

    elif persona == "trend_hopper":
        return random.randint(5, 25)

    return random.randint(5, 20)


def generate_session(session_id):

    user = users_df.sample(1).iloc[0]

    session_start = generate_session_time()

    duration_minutes = calculate_session_duration(
        user["persona"]
    )

    is_weekend = session_start.weekday() >= 5

    if is_weekend:
        duration_minutes = int(duration_minutes * 1.2)

    session_end = (
        session_start +
        timedelta(minutes=duration_minutes)
    )

    return {
        "session_id": f"S{session_id:07}",
        "user_id": user["user_id"],
        "persona": user["persona"],

        "session_start": session_start,

        "session_end": session_end,

        "session_duration_minutes": duration_minutes,

        "exit_reason": random.choice(EXIT_REASONS),

        "is_weekend": is_weekend
    }


sessions = [
    generate_session(i)
    for i in range(1, NUM_SESSIONS + 1)
]

sessions_df = pd.DataFrame(sessions)

sessions_df.to_csv("data/sessions.csv", index=False)

print("sessions.csv generated successfully")
print(sessions_df.head())