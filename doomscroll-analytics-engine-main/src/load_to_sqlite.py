import sqlite3
import pandas as pd

DB_PATH = "database/doomscroll.db"

# Load CSV files
users_df = pd.read_csv("data/users.csv")
content_df = pd.read_csv("data/content.csv")
sessions_df = pd.read_csv("data/sessions.csv")
events_df = pd.read_csv("data/events.csv")

# Clean column names
for df in [users_df, content_df, sessions_df, events_df]:
    df.columns = df.columns.str.strip()

# Connect to SQLite
conn = sqlite3.connect(DB_PATH)

# Write tables
users_df.to_sql("users", conn, if_exists="replace", index=False)
content_df.to_sql("content", conn, if_exists="replace", index=False)
sessions_df.to_sql("sessions", conn, if_exists="replace", index=False)
events_df.to_sql("events", conn, if_exists="replace", index=False)

print("All tables loaded successfully.")

# Verify tables
tables = pd.read_sql(
    """
    SELECT name
    FROM sqlite_master
    WHERE type = 'table'
    """,
    conn
)

print("\nTables in database:")
print(tables)

conn.close()