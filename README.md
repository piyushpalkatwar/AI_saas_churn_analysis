#  AI SaaS Churn Analysis

## Overview
This project analyzes user churn for a fictional AI-powered SaaS platform. It identifies which behavioral signals — AI feature adoption, support ticket volume, login recency, and usage volume — most strongly predict whether a customer cancels their subscription. The goal is to turn raw usage data into an actionable retention strategy.

## Business Problem
SaaS companies lose revenue every month to churn, and by the time a customer cancels, it's too late to win them back. This project answers the question every subscription business asks: **"Which customers are about to leave, and why?"** It builds a churn risk scoring system that surfaces at-risk users before they cancel, so the business can intervene with the right offer, support, or onboarding nudge.

## Dataset: `ai_saas_users.csv`
40 rows, one row per user. Columns include:

| Column | Description |
|---|---|
| `user_id` | Unique customer identifier |
| `signup_date` | Date the user subscribed |
| `plan_type` | Starter / Pro / Enterprise |
| `monthly_spend_usd` | Monthly recurring revenue from this user |
| `ai_features_used` | Count of distinct AI features activated |
| `api_calls_per_month` | Platform usage volume |
| `support_tickets` | Number of support tickets raised |
| `last_login_date` | Most recent login date |
| `churned` | 1 = cancelled, 0 = still active |
| `churn_date` | Date of cancellation (blank if active) |
| `industry`, `company_size`, `country` | Customer firmographic data |

## SQL Script: `project1_ai_saas_churn_analysis.sql`
Contains 10 progressively deeper queries:

1. **Churn rate by plan** — which subscription tier leaks the most customers
2. **AI feature adoption vs churn** — the core retention driver
3. **Time-to-churn analysis** — how many days until a typical user cancels
4. **Support ticket churn signal** — frustration as an early warning sign
5. **Login recency risk segmentation** — flags active users going cold
6. **Churn by industry × plan** — where to focus retention campaigns
7. **Revenue at risk (MRR impact)** — converts churn % into dollar terms
8. **Cohort retention by signup month** — is the product improving over time
9. **Composite churn risk score (view)** — a 0–12 weighted score combining all risk factors, ready to feed into a Python ML model or CRM trigger
10. **Top at-risk active users** — ranked list for proactive outreach

## Tools & Compatibility
- Written for **SQLite** (uses `julianday()`, `strftime()`)
- PostgreSQL equivalents noted in comments (`EXTRACT(EPOCH FROM ...)`, `TO_CHAR()`)
- No external dependencies — works in any standard SQL client (DB Browser for SQLite, pgAdmin, DBeaver, BigQuery sandbox, etc.)

## How to Run
1. Load `ai_saas_users.csv` into a table named `ai_saas_users` (the `CREATE TABLE` statement is included at the top of the script)
2. Run the script section by section — each block is commented with the business question it answers
3. The final `CREATE VIEW churn_risk_scores` can be queried independently for ongoing monitoring

## Key Insights to Highlight in Interviews
- Users with 5+ AI features adopted churn at a dramatically lower rate than users with 0–1 — proving AI feature adoption is the strongest retention lever
- Starter-plan churn happens fast (within 30–45 days), pointing to a free-trial/onboarding gap
- 5+ support tickets is a near-certain churn predictor — a clear trigger point for proactive CSM outreach

## Skills Demonstrated
SQL aggregation, window-style risk scoring, date arithmetic, cohort analysis, CASE-based segmentation, view creation, and translating SQL output into business recommendations — directly relevant to Data Analyst / Product Analyst interviews.
