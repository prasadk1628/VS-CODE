import pandas as pd
import numpy as np
import random
from faker import Faker
from datetime import datetime, timedelta

fake = Faker()

NUM_CONTENT = 10000
NUM_CREATORS = 1000

CATEGORIES = {
    "sports": (20, 90),
    "gaming": (30, 180),
    "anime": (20, 120),
    "music": (15, 60),
    "finance": (30, 180),
    "fitness": (20, 120),
    "memes": (5, 30),
    "tech": (30, 240),
    "food": (15, 90)
}


def random_upload_date():
    start_date = datetime(2025, 1, 1)
    end_date = datetime(2026, 5, 1)

    random_days = random.randint(0, (end_date - start_date).days)

    return (start_date + timedelta(days=random_days))


def generate_content(content_id):

    category = random.choice(list(CATEGORIES.keys()))

    min_duration, max_duration = CATEGORIES[category]

    duration = random.randint(min_duration, max_duration)

    virality_score = np.clip(np.random.lognormal(mean=0.5, sigma=1), 0, 10)

    trend_score = round(random.uniform(0, 1), 2)

    return {
        "content_id": f"C{content_id:06}",
        "creator_id": f"CR{random.randint(1, NUM_CREATORS):04}",
        "category": category,
        "duration_seconds": duration,
        "upload_timestamp": random_upload_date(),

        "virality_score": round(float(virality_score), 2),

        "trend_score": trend_score,

        "content_type": random.choice(
            ["short_video", "edit", "clip", "meme_video"]
        )
    }


content = [
    generate_content(i)
    for i in range(1, NUM_CONTENT + 1)
]

content_df = pd.DataFrame(content)

content_df.to_csv("data/content.csv", index=False)

print("content.csv generated successfully")
print(content_df.head())