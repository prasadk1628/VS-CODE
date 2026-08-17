# DoomScroll Analytics Engine

> **An end-to-end product analytics system for understanding short-form content consumption, engagement, retention, behavioral segments, and continuous-scrolling patterns.**

DoomScroll Analytics Engine simulates a short-form content platform and analyzes user behavior from event-level data.

The project demonstrates a complete product analytics workflow — from behavioral event generation and data validation to SQL analysis, behavioral segmentation, Tableau dashboards, and product recommendations.

---

## 📌 Project Overview

Short-form content platforms generate millions of behavioral events, but raw event volume does not explain **why users behave differently or what those behaviors mean for the product**.

This project investigates user consumption patterns across sessions and translates those patterns into product-level insights.

### Core questions

1. **How do users consume content during a session?**
2. **Does engagement change as users consume more content?**
3. **Which behavioral user segments emerge from observed activity?**
4. **Which users exhibit continuous-consumption patterns?**
5. **Does content preference relate to consumption depth?**
6. **Do users return to the platform over time?**
7. **What product opportunities can be derived from these behaviors?**

---

# 🎯 Business Problem

A short-form content platform needs to understand more than simple metrics such as views or likes.

High consumption does not necessarily mean high engagement.

A user who watches 60 pieces of content and interacts with four of them behaves very differently from a user who watches 50 pieces and actively likes nine.

The project therefore focuses on **behavioral quality and user journeys**, rather than relying only on surface-level engagement metrics.

The objective is to identify:

- consumption patterns
- engagement patterns
- retention behavior
- behavioral segments
- continuous-consumption loops
- relationships between content preference and consumption
- potential product opportunities

---

# 🔬 Analytical Framework

The project follows an analytics-first workflow:

```text
Business Problem
       ↓
Analytical Questions
       ↓
KPI & Metric Design
       ↓
Event Schema Design
       ↓
Synthetic Data Generation
       ↓
Data Validation
       ↓
SQL Behavioral Analysis
       ↓
Behavioral Segmentation
       ↓
Journey & Loop Analysis
       ↓
Tableau Dashboards
       ↓
Product Insights
       ↓
Recommendations
````

The dashboard layer is therefore the **communication layer**, not the analytical starting point.

---

# 🗃️ Dataset

The project uses a synthetic dataset representing a short-form content platform.

### Dataset scale

|Table|Rows|Purpose|
|---|--:|---|
|`users`|5,000|User profiles and behavioral attributes|
|`content`|10,000|Content metadata|
|`sessions`|5,000|Session-level behavior|
|`events`|855,196|Event-level user activity|

### Data model

```text
                            users
                              │
                              ├──────────────┐
                              │              │
                              ↓              ↓
                            sessions       events
                                              │
                                              ↓
                                           content
```

### Core event journey

```text
                     Content Impression
                             ↓
                        Video Start
                             ↓
                           Watch
                             ↓
                            Like
                             ↓
                         Swipe Next
                             ↓
                        Next Content
```

This event structure enables analysis at multiple levels:

- user
    
- session
    
- content
    
- event
    
- behavioral segment
    
- journey stage
    

---

# ⚙️ Data Engineering

The data pipeline was designed to simulate a lightweight production analytics workflow.

```text
              Python Generators
                     ↓
                 CSV Files
                     ↓
               SQLite Database
                     ↓
              Validation Queries
                     ↓
                Analytical SQL
                     ↓
              Tableau-ready Data
```

### Generation components

- `users_generator.py`
    
- `content_generator.py`
    
- `session_generator.py`
    
- `event_generator.py`
    
- `load_to_sqlite.py`
    

SQLite is used as the analytical database to keep the project lightweight and reproducible.

---

# ✅ Data Validation

Before analysis, the generated data was validated for structural and behavioral consistency.

Validation covered:

- table row counts
    
- event distributions
    
- session structure
    
- timestamps
    
- user/session relationships
    
- event sequencing
    
- session duration
    
- behavioral attributes
    

Several pipeline issues were identified and corrected during development, including malformed CSV structure, column-name whitespace, database path issues, and session-duration inconsistencies.

This validation stage was important because downstream behavioral analysis is only meaningful when the underlying event data is reliable.

---

# 📊 Analytical Areas

## 01 — Session Analytics

**Question:**

> How are users consuming content during individual sessions?

Metrics include:

- session duration
    
- session depth
    
- events per session
    
- event density
    
- exit behavior
    
- time-of-day behavior
    
- weekday vs weekend behavior
    

---

## 02 — Engagement Analysis

**Question:**

> Does engagement change as users consume more content?

The analysis examines:

- likes
    
- watch behavior
    
- engagement rate
    
- engagement across journey depth
    
- engagement by behavioral segment
    

---

## 03 — Retention & Cohorts

**Question:**

> Do users return to the platform?

The retention layer examines:

- returning users
    
- cohort behavior
    
- D1 retention
    
- D7 retention
    
- D30 retention
    

---

## 04 — Behavioral Segmentation

**Question:**

> What distinct consumption behaviors exist among users?

The project derives four behavioral segments:

- **Light Passive**
    
- **Quick Engager**
    
- **Deep Consumer**
    
- **Deep Engager**
    

The segmentation is based on observed behavioral characteristics rather than simply reproducing the original synthetic persona labels.

---

## 05 — Consumption Loops

**Question:**

> Which users exhibit repeated or continuous-consumption patterns?

The analysis identifies sessions where users demonstrate repeated consumption behavior and compares loop behavior across segments.

---

## 06 — User Journey Analysis

**Question:**

> How do users progress through the content-consumption journey?

The journey is modeled as:

```text
Impression
    ↓
Video Start
    ↓
Watch
    ↓
Like
    ↓
Swipe
    ↓
Next Content
```

This allows engagement and consumption behavior to be examined across different stages of a session.

---

# 📈 Key Findings

## 01 — Engagement remains relatively stable across session depth

Observed like rates across journey quartiles:

|Journey Quartile|Like Rate|
| -------------- | --------|
|**Q1**|12.18%|
|**Q2**|12.15%|
|**Q3**|11.78%|
|**Q4**|12.01%|

### Interpretation

The data does **not** show a meaningful engagement-decay pattern as sessions become deeper.

This is important because the analysis does not force the expected "engagement decreases over time" narrative onto the data.

---

## 02 — Consumption depth and active engagement are different behaviors

|Behavioral Segment|Content / Session|Likes / Session|
|---|--:|--:|
|Deep Consumer|65.28|4.09|
|Deep Engager|50.79|9.18|
|Quick Engager|19.63|3.34|
|Light Passive|24.70|0.88|

### Interpretation

Deep Consumers consume the most content, but Deep Engagers demonstrate substantially stronger active interaction.

This suggests that **consumption volume should not be treated as a direct proxy for meaningful engagement**.

---

## 03 — Continuous-consumption behavior is concentrated among deeper consumers

The analysis identified:

- **667 loop sessions**
    
- **13.34% of all sessions**
    

Loop-session rate by segment:

|Segment|Loop Session Rate|
|---|--:|
|Deep Consumer|29.00%|
|Deep Engager|19.58%|
|Light Passive|4.56%|
|Quick Engager|4.48%|

### Interpretation

Deep Consumers are substantially more likely to exhibit repeated-consumption behavior than the other segments.

This is an important behavioral pattern, but it should not be interpreted as proof that a recommendation algorithm caused the behavior.

---

## 04 — Content preference is associated with deeper consumption

|Preference Alignment|Items / Session|
|---|--:|
|Preference-heavy|38.94|
|Mixed|40.71|
|Preference-light|15.40|

### Interpretation

Preference-aligned consumption is associated with greater session depth.

This creates a potential product hypothesis around preference-aware content delivery.

---

# 👥 Behavioral Segments

The behavioral segmentation layer provides a more useful view of users than simple demographic or persona categories.

|Segment|Users|Share|
|---|--:|--:|
|Light Passive|1,129|35.77%|
|Deep Engager|1,129|35.77%|
|Quick Engager|449|14.23%|
|Deep Consumer|449|14.23%|

### Segment interpretation

|Segment|Behavioral Profile|
|---|---|
|**Light Passive**|Lower consumption and low active interaction|
|**Quick Engager**|Shorter consumption with relatively active interaction|
|**Deep Consumer**|High consumption depth with comparatively lower interaction|
|**Deep Engager**|High consumption combined with strong active engagement|

The value of the segmentation is not the labels themselves, but the behavioral differences they expose.

---

# 📊 Tableau Dashboard

The final Tableau report translates the analytical findings into four product-facing views.

## Dashboard 01 — Session Behavior

**Business question:**

> How are users consuming content during sessions?

Focus areas:

- total sessions
    
- average session duration
    
- session duration by persona
    
- exit behavior
    
- time-of-day activity
    
- session depth
    

---

## Dashboard 02 — Engagement & Consumption

**Business question:**

> How does engagement behave as consumption increases?

Focus areas:

- engagement across journey depth
    
- consumption depth
    
- engagement by segment
    
- loop behavior
    

---

## Dashboard 03 — Retention & Cohorts

**Business question:**

> Do users return to the platform?

Focus areas:

- D1 retention
    
- D7 retention
    
- D30 retention
    
- cohort retention
    
- returning-user behavior
    

---

## Dashboard 04 — Behavioral Segments

**Business question:**

> How do different types of users behave?

Focus areas:

- consumption depth
    
- engagement
    
- session behavior
    
- loop behavior
    
- segment comparison
    

---

# 💡 Product Insights & Recommendations

The analysis translates into several potential product hypotheses.

### 01 — Optimize for meaningful engagement

Deep consumption does not necessarily correspond to strong active engagement.

**Recommendation:**  
Evaluate product success using a combination of consumption depth and meaningful interaction rather than watch volume alone.

---

### 02 — Investigate high-loop users

Deep Consumers demonstrate a substantially higher loop-session rate.

**Recommendation:**  
Investigate whether repeated consumption represents:

- strong content relevance
    
- successful discovery
    
- passive binge consumption
    
- potentially undesirable over-consumption
    

Further product experiments would be required before changing recommendation behavior.

---

### 03 — Test preference-aware content ranking

Preference-aligned consumption is associated with deeper sessions.

**Recommendation:**  
Run a controlled experiment testing whether stronger preference-aware ranking improves:

- engagement
    
- session depth
    
- retention
    
- content satisfaction
    

---

### 04 — Avoid assuming engagement decay

Engagement remained relatively stable across journey depth.

**Recommendation:**  
Do not introduce interventions based solely on an assumed engagement-decay pattern.

Additional behavioral evidence should be collected first.

---

# 🧠 Analytical Discipline

A key principle of this project is distinguishing **observation from causation**.

```text
Observed Pattern
       ↓
Association
       ↓
Product Hypothesis
       ↓
Experiment
       ↓
Causal Evidence
```

The project does not claim that:

```text
Correlation = Causation
```

This is particularly important because the dataset is synthetic and some behavioral relationships are intentionally encoded during data generation.

---

# 🛠️ Technology Stack

|Layer|Technology|
|---|---|
|Programming|Python|
|Data Processing|pandas|
|Database|SQLite|
|Analytics|SQL|
|Visualization|Tableau|
|Development|Jupyter Notebook · VS Code|
|Version Control|Git · GitHub|

The system is intentionally lightweight and designed to remain usable on modest hardware.

---

# 📁 Project Structure

```text
doomscroll-analytics-engine/
│
├── data/
│   ├── users.csv
│   ├── content.csv
│   ├── sessions.csv
│   └── events.csv
│
├── database/
│   └── doomscroll.db
│
├── src/
│   ├── users_generator.py
│   ├── content_generator.py
│   ├── session_generator.py
│   ├── event_generator.py
│   └── load_to_sqlite.py
│
├── sql/
│   ├── 01_validation_queries.sql
│   ├── 02_session_data_quality.sql
│   └── ...
│
├── notebooks/
│   └── ...
│
├── tableau/
│   └── ...
│
├── requirements.txt
├── README.md
└── LICENSE
```

---

# ▶️ Run Locally

### Clone

```bash
git clone <repository-url>
cd doomscroll-analytics-engine
```

### Create environment

```bash
python3 -m venv .venv
source .venv/bin/activate
```

### Install dependencies

```bash
pip install -r requirements.txt
```

### Generate data

```bash
python src/users_generator.py
python src/content_generator.py
python src/session_generator.py
python src/event_generator.py
```

### Load into SQLite

```bash
python src/load_to_sqlite.py
```

### Run validation

```bash
sqlite3 database/doomscroll.db < sql/01_validation_queries.sql
```

---

# ⚠️ Limitations

### Synthetic data

The project uses generated behavioral data rather than real platform data.

Therefore, the findings demonstrate an analytical methodology rather than real-world platform performance.

### Generator-defined behavior

Some relationships are intentionally encoded into the synthetic data-generation process.

These relationships should therefore not be presented as unexpected discoveries.

### No recommendation-system telemetry

The dataset does not contain:

- recommendation scores
    
- ranking positions
    
- candidate recommendations
    
- recommendation exposure logic
    

Therefore, the project cannot establish that recommendation algorithms caused observed consumption loops.

### No causal inference

The analysis identifies behavioral patterns and associations.

Controlled experiments or stronger observational designs would be required to establish causal effects.

---

# 🔮 Future Improvements

-  Add recommendation-exposure and ranking data
    
-  Simulate A/B experiments
    
-  Analyze recommendation effectiveness
    
-  Add retention prediction
    
-  Add behavioral anomaly detection
    
-  Automate Tableau data refresh
    
-  Expand behavioral segmentation
    
-  Add experiment analysis
    
-  Introduce real-world or public behavioral datasets
    

---

# 📄 License

This project is licensed under the MIT License.

---

# 👤 Author

**Vara Prasad K**

B.Tech Computer Science & Engineering  
Hyderabad, India

**Aspiring Data Analyst**

**Python · SQL · Tableau · Product Analytics**

[GitHub](https://github.com/prasadk1628)

[LinkedIn](https://www.linkedin.com/in/vara-prasad-kavali)

---