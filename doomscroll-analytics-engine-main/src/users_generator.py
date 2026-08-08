import pandas as pd
import numpy as np
import random
from faker import Faker
from datetime import datetime, timedelta

fake = Faker()

NUM_USERS = 5000

PERSONAS = {
    "passive_scroller": {
        "binge_tendency": (0.1, 0.4),
        "engagement_rate": (0.01, 0.05)
    },
    "binge_user": {
        "binge_tendency": (0.7, 1.0),
        "engagement_rate": (0.05, 0.15)
    },
    "active_engager": {
        "binge_tendency": (0.4, 0.7),
        "engagement_rate": (0.15, 0.35)
    },
    "trend_hopper": {
        "binge_tendency": (0.3, 0.6),
        "engagement_rate": (0.05, 0.12)
    }
}

CATEGORIES = [
    "sports",
    "gaming",
    "anime",
    "music",
    "finance",
    "fitness",
    "memes",
    "tech",
    "food"
]


def random_signup_date():
    start_date = datetime(2025, 1, 1)
    end_date = datetime(2026, 5, 1)

    random_days = random.randint(0, (end_date - start_date).days)

    return (start_date + timedelta(days=random_days)).date()


def generate_user(user_id):

    persona = random.choice(list(PERSONAS.keys()))

    binge_min, binge_max = PERSONAS[persona]["binge_tendency"]
    engage_min, engage_max = PERSONAS[persona]["engagement_rate"]

    favorite_categories = random.sample(CATEGORIES, k=3)

    return {
        "user_id": f"U{user_id:05}",
        "username": fake.user_name(),
        "country": fake.country(),
        "age": random.randint(18, 45),
        "persona": persona,
        "signup_date": random_signup_date(),
        "binge_tendency": round(random.uniform(binge_min, binge_max), 2),
        "engagement_rate": round(random.uniform(engage_min, engage_max), 2),
        "favorite_categories": ",".join(favorite_categories)
    }


users = [generate_user(i) for i in range(1, NUM_USERS + 1)]

users_df = pd.DataFrame(users)

users_df.to_csv("data/users.csv", index=False)

print("users.csv generated successfully")
print(users_df.head())