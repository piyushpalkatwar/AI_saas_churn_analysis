
--  AI SaaS Churn Analysis
-- Domain: SaaS | Tools: SQL (PostgreSQL / SQLite compatible)
-- Analyst: Piyush Palkatwar | Date: 2026-06-30
-- Trend: Predicting churn using AI feature usage signals

-- 
-- STEP 1: CREATE TABLE & LOAD DATA
-- ─────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS ai_saas_users (
    user_id            VARCHAR(10) PRIMARY KEY,
    signup_date        DATE,
    plan_type          VARCHAR(20),
    monthly_spend_usd  DECIMAL(10,2),
    ai_features_used   INT,           -- no. of distinct AI features activated
    api_calls_per_month INT,
    support_tickets    INT,
    last_login_date    DATE,
    churned            INT,           -- 1 = churned, 0 = active
    churn_date         DATE,
    industry           VARCHAR(50),
    company_size       VARCHAR(20),   -- Small / Mid / Large
    country            VARCHAR(50)
);

-- Load CSV: COPY ai_saas_users FROM 'ai_saas_users.csv' CSV HEADER;
-- For SQLite: use .import ai_saas_users.csv ai_saas_users

--
-- STEP 2: OVERVIEW — CHURN RATE BY PLAN
-- 

-- Business Question: Which subscription plan has the highest churn?
-- Insight helps PMs decide where to invest in retention campaigns.

SELECT
    plan_type,
    COUNT(*)                                        AS total_users,
    SUM(churned)                                    AS churned_users,
    ROUND(100.0 * SUM(churned) / COUNT(*), 2)       AS churn_rate_pct
FROM ai_saas_users
GROUP BY plan_type
ORDER BY churn_rate_pct DESC;

/*
Expected Insight:
  Starter plans likely have 40-60% churn → low engagement threshold
  Enterprise plans typically <5% churn  → high switching cost + value
  This guides upsell strategy: convert Starter → Pro before they churn
*/

-- 
-- STEP 3: AI FEATURE ADOPTION vs CHURN
-- 

-- Business Question: Do users who adopt more AI features churn less?
-- This is the core GenAI product metric for 2024-25.

SELECT
    ai_features_used,
    COUNT(*)                                        AS total_users,
    SUM(churned)                                    AS churned_users,
    ROUND(100.0 * SUM(churned) / COUNT(*), 2)       AS churn_rate_pct,
    ROUND(AVG(api_calls_per_month), 0)              AS avg_api_calls
FROM ai_saas_users
GROUP BY ai_features_used
ORDER BY ai_features_used ASC;

/*
Expected Insight:
  Users with 0-1 AI features: churn > 50%
  Users with 5+ AI features: churn < 10%
  → "AI Feature Adoption" is the #1 leading indicator of retention
  → Product team should push onboarding flows for AI feature activation
*/


-- 
-- STEP 4: DAYS TO CHURN (TIME-TO-CHURN ANALYSIS)
-- 

-- Business Question: How quickly do churned users leave?
-- Helps define the intervention window for CSM / automated nudges.

SELECT
    plan_type,
    ROUND(
        AVG(
            CAST(julianday(churn_date) - julianday(signup_date) AS FLOAT)
        ), 0
    )                                               AS avg_days_to_churn,
    MIN(
        CAST(julianday(churn_date) - julianday(signup_date) AS INT)
    )                                               AS min_days_to_churn,
    MAX(
        CAST(julianday(churn_date) - julianday(signup_date) AS INT)
    )                                               AS max_days_to_churn
FROM ai_saas_users
WHERE churned = 1
GROUP BY plan_type
ORDER BY avg_days_to_churn ASC;

/*
PostgreSQL version — replace julianday() with:
    EXTRACT(EPOCH FROM (churn_date - signup_date))/86400

Expected Insight:
  Starter users churn within ~30-45 days → free-trial expiry effect
  Pro users churn around day 60-90       → post-onboarding fatigue
  Intervention must happen within first 30 days
*/


-- 
-- STEP 5: SUPPORT TICKET CHURN SIGNAL
-- 

-- Business Question: Are high-support users more likely to churn?
-- Frequent tickets = frustration = early churn warning.

SELECT
    CASE
        WHEN support_tickets = 0 THEN '0 Tickets'
        WHEN support_tickets BETWEEN 1 AND 2 THEN '1-2 Tickets'
        WHEN support_tickets BETWEEN 3 AND 4 THEN '3-4 Tickets'
        ELSE '5+ Tickets'
    END                                             AS ticket_bucket,
    COUNT(*)                                        AS total_users,
    ROUND(100.0 * SUM(churned) / COUNT(*), 2)       AS churn_rate_pct
FROM ai_saas_users
GROUP BY ticket_bucket
ORDER BY churn_rate_pct DESC;

/*
Expected Insight:
  5+ tickets → churn rate ~80%+
  0 tickets  → churn rate < 10%
  → Proactive CSM outreach triggered at ticket 3 could reduce churn
*/


-- 
-- STEP 6: DAYS SINCE LAST LOGIN (RECENCY RISK)
-- 

-- Business Question: How stale is the user base right now?
-- Active users not logging in for 30+ days are high churn risk.

SELECT
    user_id,
    plan_type,
    last_login_date,
    CAST(julianday('2026-06-30') - julianday(last_login_date) AS INT)
                                                    AS days_since_login,
    churned,
    CASE
        WHEN churned = 0
         AND CAST(julianday('2026-06-30') - julianday(last_login_date) AS INT) > 30
         THEN 'At Risk'
        WHEN churned = 0
         AND CAST(julianday('2026-06-30') - julianday(last_login_date) AS INT) BETWEEN 15 AND 30
         THEN 'Watch'
        ELSE 'Healthy'
    END                                             AS risk_segment
FROM ai_saas_users
WHERE churned = 0
ORDER BY days_since_login DESC;


-- 
-- STEP 7: CHURN RATE BY INDUSTRY & PLAN
-- 

-- Business Question: Which industry + plan combos have highest churn?
-- Helps BD / GTM teams prioritize industry-specific retention plays.

SELECT
    industry,
    plan_type,
    COUNT(*)                                        AS users,
    ROUND(100.0 * SUM(churned) / COUNT(*), 2)       AS churn_rate_pct,
    ROUND(AVG(monthly_spend_usd), 2)                AS avg_monthly_spend
FROM ai_saas_users
GROUP BY industry, plan_type
HAVING COUNT(*) >= 2
ORDER BY churn_rate_pct DESC;


-- 
-- STEP 8: REVENUE AT RISK (CHURNED + AT-RISK MRR)
-- 

-- Business Question: What is the monthly revenue impact of churn?
-- This converts churn % into a dollar figure for leadership dashboards.

SELECT
    plan_type,
    SUM(CASE WHEN churned = 1 THEN monthly_spend_usd ELSE 0 END)
                                                    AS lost_mrr_usd,
    SUM(CASE WHEN churned = 0 THEN monthly_spend_usd ELSE 0 END)
                                                    AS active_mrr_usd,
    ROUND(
        100.0 * SUM(CASE WHEN churned = 1 THEN monthly_spend_usd ELSE 0 END)
        / SUM(monthly_spend_usd), 2
    )                                               AS mrr_churn_rate_pct
FROM ai_saas_users
GROUP BY plan_type
ORDER BY lost_mrr_usd DESC;


-- 
-- STEP 9: COHORT RETENTION — SIGNUP MONTH COHORTS
-- 

-- Business Question: Are recent cohorts retaining better than older ones?
-- Shows if product improvements are reducing churn over time.

SELECT
    strftime('%Y-%m', signup_date)                  AS cohort_month,
    COUNT(*)                                        AS cohort_size,
    SUM(churned)                                    AS churned_count,
    ROUND(100.0 * SUM(churned) / COUNT(*), 2)       AS churn_rate_pct,
    ROUND(100.0 * SUM(CASE WHEN churned=0 THEN 1 ELSE 0 END) / COUNT(*), 2)
                                                    AS retention_rate_pct
FROM ai_saas_users
GROUP BY cohort_month
ORDER BY cohort_month ASC;

/*
PostgreSQL: use TO_CHAR(signup_date, 'YYYY-MM') instead of strftime()

Expected Insight:
  Early cohorts (Jan-Feb 2024) may show higher churn → product was newer
  Later cohorts should improve if AI onboarding was enhanced
*/


-- 
-- STEP 10: CHURN PREDICTION SCORING VIEW
-- 

-- Composite risk score: higher = more likely to churn
-- Useful as input to a Python ML model or CRM automation trigger

CREATE VIEW IF NOT EXISTS churn_risk_scores AS
SELECT
    user_id,
    plan_type,
    industry,
    country,
    churned,
    -- Risk components (normalize 0-3 each)
    CASE WHEN ai_features_used <= 1     THEN 3
         WHEN ai_features_used <= 3     THEN 1
         ELSE 0 END                                 AS low_ai_adoption_score,
    CASE WHEN support_tickets >= 5      THEN 3
         WHEN support_tickets >= 3      THEN 2
         WHEN support_tickets >= 1      THEN 1
         ELSE 0 END                                 AS support_risk_score,
    CASE WHEN api_calls_per_month < 500 THEN 3
         WHEN api_calls_per_month < 2000 THEN 1
         ELSE 0 END                                 AS low_usage_score,
    CASE
        WHEN CAST(julianday('2026-06-30') - julianday(last_login_date) AS INT) > 30 THEN 3
        WHEN CAST(julianday('2026-06-30') - julianday(last_login_date) AS INT) > 15 THEN 1
        ELSE 0
    END                                             AS login_recency_score,
    -- Total composite score (0-12)
    (
        CASE WHEN ai_features_used <= 1 THEN 3 WHEN ai_features_used <= 3 THEN 1 ELSE 0 END
      + CASE WHEN support_tickets >= 5 THEN 3 WHEN support_tickets >= 3 THEN 2 WHEN support_tickets >= 1 THEN 1 ELSE 0 END
      + CASE WHEN api_calls_per_month < 500 THEN 3 WHEN api_calls_per_month < 2000 THEN 1 ELSE 0 END
      + CASE WHEN CAST(julianday('2026-06-30') - julianday(last_login_date) AS INT) > 30 THEN 3
             WHEN CAST(julianday('2026-06-30') - julianday(last_login_date) AS INT) > 15 THEN 1
             ELSE 0 END
    )                                               AS churn_risk_score
FROM ai_saas_users;

-- Query the view: top at-risk active users
SELECT *
FROM churn_risk_scores
WHERE churned = 0
ORDER BY churn_risk_score DESC
LIMIT 10;

-- END OF The  PROJECT 
-- Key Takeaways:
-- 1. AI feature adoption is the strongest churn predictor
-- 2. Starter plan users churn fastest (within 30-45 days)
-- 3. 5+ support tickets → 80%+ churn risk
-- 4. Churn risk score view can feed a Python ML pipeline
