-- ==============================================================
-- SECTION 2: COHORT OVERVIEW
-- Full dataset + broken down by life stage
-- ==============================================================
-- 2a. Full dataset overview
SELECT COUNT(*) AS total_patients,
    ROUND(AVG(Age), 1) AS avg_age,
    MIN(Age) AS min_age,
    MAX(Age) AS max_age,
    SUM(
        CASE
            WHEN Diagnosis_Class != 0 THEN 1
            ELSE 0
        END
    ) AS total_adhd,
    ROUND(
        100.0 * SUM(
            CASE
                WHEN Diagnosis_Class != 0 THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        1
    ) AS overall_prevalence_pct,
    SUM(
        CASE
            WHEN Gender = 1 THEN 1
            ELSE 0
        END
    ) AS male_count,
    SUM(
        CASE
            WHEN Gender = 2 THEN 1
            ELSE 0
        END
    ) AS female_count
FROM adhd_patients;
-- 2b. Overview by life stage
SELECT Life_Stage,
    COUNT(*) AS patients,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 1) AS pct_of_total,
    SUM(
        CASE
            WHEN Diagnosis_Class != 0 THEN 1
            ELSE 0
        END
    ) AS adhd_count,
    ROUND(
        100.0 * SUM(
            CASE
                WHEN Diagnosis_Class != 0 THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        1
    ) AS adhd_prevalence_pct,
    ROUND(AVG(Total_Severity), 2) AS avg_total_severity
FROM adhd_clean
GROUP BY Life_Stage
ORDER BY MIN(Age);
-- ==============================================================
-- SECTION 3: DIAGNOSIS DISTRIBUTION
-- Full + pediatric cohort comparison
-- ==============================================================
-- 3a. Full dataset diagnosis distribution
SELECT Diagnosis_Label,
    COUNT(*) AS patient_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 1) AS percentage,
    ROUND(AVG(Total_Severity), 2) AS avg_severity,
    ROUND(AVG(Hyperactivity_Index), 2) AS avg_hyperactivity,
    ROUND(AVG(Inattention_Index), 2) AS avg_inattention
FROM adhd_clean
GROUP BY Diagnosis_Label,
    Diagnosis_Class
ORDER BY Diagnosis_Class;
-- 3b. Pediatric cohort only (5-14) — your Excel dashboard cohort
SELECT Diagnosis_Label,
    COUNT(*) AS patient_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 1) AS percentage
FROM adhd_clean
WHERE Age BETWEEN 5 AND 14
GROUP BY Diagnosis_Label,
    Diagnosis_Class
ORDER BY Diagnosis_Class;
-- ==============================================================
-- SECTION 4: PREVALENCE BY AGE WITH ROLLING AVERAGE
-- Window function — shows symptom trajectory across childhood
-- ==============================================================
SELECT Age,
    COUNT(*) AS total_patients,
    SUM(
        CASE
            WHEN Diagnosis_Class != 0 THEN 1
            ELSE 0
        END
    ) AS adhd_count,
    ROUND(
        100.0 * SUM(
            CASE
                WHEN Diagnosis_Class != 0 THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        1
    ) AS prevalence_pct,
    -- 3-year rolling average prevalence (smooths noise)
    ROUND(
        AVG(
            100.0 * SUM(
                CASE
                    WHEN Diagnosis_Class != 0 THEN 1
                    ELSE 0
                END
            ) / COUNT(*)
        ) OVER (
            ORDER BY Age ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ),
        1
    ) AS rolling_3yr_prevalence,
    -- Cumulative patient count
    SUM(COUNT(*)) OVER (
        ORDER BY Age
    ) AS cumulative_patients
FROM adhd_patients
WHERE Age BETWEEN 5 AND 18
GROUP BY Age
ORDER BY Age;
-- ==============================================================
-- SECTION 5: LIFE-STAGE COHORT COMPARISON
-- ADHD vs No-ADHD across all lifestyle variables — per life stage
-- The most clinically meaningful query in this script
-- ==============================================================
SELECT Life_Stage,
    Diagnosis_Label,
    COUNT(*) AS n,
    ROUND(AVG(Total_Severity), 2) AS avg_severity,
    ROUND(AVG(Sleep_Hours), 2) AS avg_sleep,
    ROUND(AVG(Daily_Phone_Usage_Hours), 2) AS avg_screen_time,
    ROUND(AVG(Daily_Walking_Running_Hours), 2) AS avg_activity,
    ROUND(AVG(Daily_Coffee_Tea_Consumption), 2) AS avg_caffeine,
    ROUND(AVG(Focus_Score_Video), 2) AS avg_focus_score,
    ROUND(AVG(Anxiety_Depression_Levels), 2) AS avg_anxiety,
    ROUND(AVG(Learning_Difficulties::NUMERIC), 2) AS avg_learning_diff,
    ROUND(AVG(Difficulty_Organizing_Tasks::NUMERIC), 2) AS avg_org_difficulty
FROM adhd_clean
WHERE Life_Stage IS NOT NULL
GROUP BY Life_Stage,
    Diagnosis_Label,
    Diagnosis_Class
ORDER BY Life_Stage,
    Diagnosis_Class;
-- ==============================================================
-- SECTION 6: RISK STRATIFICATION USING CTEs
-- 3-stage CTE pipeline: score → flag → summarise
-- ==============================================================
WITH severity_scored AS (
    -- Stage 1: compute severity quartiles
    SELECT *,
        NTILE(4) OVER (
            PARTITION BY Diagnosis_Label
            ORDER BY Total_Severity
        ) AS severity_quartile
    FROM adhd_clean
    WHERE Age BETWEEN 5 AND 14
),
risk_flagged AS (
    -- Stage 2: assign risk category from lifestyle flags
    SELECT *,
        CASE
            WHEN Sleep_Risk_Flag = 1
            AND High_Screen_Flag = 1
            AND Anxiety_Risk_Flag = 1 THEN 'Critical Risk'
            WHEN Sleep_Risk_Flag = 1
            AND High_Screen_Flag = 1 THEN 'High Risk'
            WHEN Sleep_Risk_Flag = 1
            OR High_Screen_Flag = 1 THEN 'Moderate Risk'
            ELSE 'Low Risk'
        END AS Risk_Category
    FROM severity_scored
),
summary AS (
    -- Stage 3: summarise by diagnosis + risk
    SELECT Diagnosis_Label,
        Risk_Category,
        COUNT(*) AS patient_count,
        ROUND(AVG(Total_Severity), 2) AS avg_severity,
        ROUND(AVG(Sleep_Hours), 2) AS avg_sleep,
        ROUND(AVG(Daily_Phone_Usage_Hours), 2) AS avg_screen_time,
        ROUND(AVG(Anxiety_Depression_Levels)::NUMERIC, 2) AS avg_anxiety,
        SUM(
            CASE
                WHEN Family_History = 'Yes' THEN 1
                ELSE 0
            END
        ) AS family_history_count
    FROM risk_flagged
    GROUP BY Diagnosis_Label,
        Risk_Category
)
SELECT *,
    ROUND(
        100.0 * patient_count / SUM(patient_count) OVER (PARTITION BY Diagnosis_Label),
        1
    ) AS pct_within_diagnosis
FROM summary
ORDER BY Diagnosis_Label,
    CASE
        Risk_Category
        WHEN 'Critical Risk' THEN 1
        WHEN 'High Risk' THEN 2
        WHEN 'Moderate Risk' THEN 3
        ELSE 4
    END;
-- ==============================================================
-- SECTION 7: STATISTICAL PERCENTILES BY DIAGNOSIS
-- PostgreSQL-specific PERCENTILE_CONT function
-- Produces clinical-grade score distribution table
-- ==============================================================
SELECT Diagnosis_Label,
    COUNT(*) AS n,
    -- Hyperactivity statistics
    ROUND(AVG(Hyperactivity_Index), 2) AS mean_hyperactivity,
    ROUND(STDDEV(Hyperactivity_Index), 2) AS sd_hyperactivity,
    PERCENTILE_CONT(0.25) WITHIN GROUP (
        ORDER BY Hyperactivity_Index
    ) AS p25_hyperactivity,
    PERCENTILE_CONT(0.50) WITHIN GROUP (
        ORDER BY Hyperactivity_Index
    ) AS median_hyperactivity,
    PERCENTILE_CONT(0.75) WITHIN GROUP (
        ORDER BY Hyperactivity_Index
    ) AS p75_hyperactivity,
    -- Inattention statistics
    ROUND(AVG(Inattention_Index), 2) AS mean_inattention,
    ROUND(STDDEV(Inattention_Index), 2) AS sd_inattention,
    PERCENTILE_CONT(0.25) WITHIN GROUP (
        ORDER BY Inattention_Index
    ) AS p25_inattention,
    PERCENTILE_CONT(0.50) WITHIN GROUP (
        ORDER BY Inattention_Index
    ) AS median_inattention,
    PERCENTILE_CONT(0.75) WITHIN GROUP (
        ORDER BY Inattention_Index
    ) AS p75_inattention,
    -- Total severity statistics
    ROUND(AVG(Total_Severity), 2) AS mean_total_severity,
    PERCENTILE_CONT(0.50) WITHIN GROUP (
        ORDER BY Total_Severity
    ) AS median_total_severity,
    PERCENTILE_CONT(0.90) WITHIN GROUP (
        ORDER BY Total_Severity
    ) AS p90_total_severity
FROM adhd_clean
GROUP BY Diagnosis_Label,
    Diagnosis_Class
ORDER BY Diagnosis_Class;
-- ==============================================================
-- SECTION 8: LIFESTYLE FACTOR ANALYSIS
-- Correlation-style breakdown: how each lifestyle variable
-- tracks against ADHD status and severity
-- ==============================================================
-- 8a. Sleep hours distribution across diagnosis groups
WITH sleep_bucketed AS (
    SELECT Diagnosis_Label,
        Diagnosis_Class,
        Total_Severity,
        CASE
            WHEN Sleep_Hours < 6 THEN 'Under 6hrs (Severe Sleep Risk)'
            WHEN Sleep_Hours < 7 THEN '6-7hrs (Mild Sleep Risk)'
            WHEN Sleep_Hours < 9 THEN '7-9hrs (Normal)'
            ELSE 'Over 9hrs'
        END AS Sleep_Category,
        CASE
            WHEN Sleep_Hours < 6 THEN 1
            WHEN Sleep_Hours < 7 THEN 2
            WHEN Sleep_Hours < 9 THEN 3
            ELSE 4
        END AS Sleep_Order
    FROM adhd_clean
    WHERE Age BETWEEN 5 AND 14
)
SELECT Diagnosis_Label,
    Sleep_Category,
    COUNT(*) AS patient_count,
    ROUND(AVG(Total_Severity), 2) AS avg_severity
FROM sleep_bucketed
GROUP BY Diagnosis_Label,
    Diagnosis_Class,
    Sleep_Category,
    Sleep_Order
ORDER BY Diagnosis_Class,
    Sleep_Order;
-- 8b. Screen time vs severity — ranked buckets
SELECT CASE
        WHEN Daily_Phone_Usage_Hours < 2 THEN 'Low (<2hrs)'
        WHEN Daily_Phone_Usage_Hours < 4 THEN 'Moderate (2-4hrs)'
        WHEN Daily_Phone_Usage_Hours < 6 THEN 'High (4-6hrs)'
        ELSE 'Very High (6+ hrs)'
    END AS Screen_Time_Bucket,
    COUNT(*) AS total_patients,
    ROUND(AVG(Total_Severity), 2) AS avg_severity,
    ROUND(AVG(Anxiety_Depression_Levels), 2) AS avg_anxiety,
    SUM(
        CASE
            WHEN Diagnosis_Class != 0 THEN 1
            ELSE 0
        END
    ) AS adhd_count,
    ROUND(
        100.0 * SUM(
            CASE
                WHEN Diagnosis_Class != 0 THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        1
    ) AS adhd_prevalence_pct
FROM adhd_clean
WHERE Age BETWEEN 5 AND 14
GROUP BY Screen_Time_Bucket
ORDER BY AVG(Daily_Phone_Usage_Hours);
-- ==============================================================
-- SECTION 9: FAMILY HISTORY IMPACT
-- Does family history of ADHD predict higher severity?
-- ==============================================================
SELECT Family_History,
    Diagnosis_Label,
    COUNT(*) AS patient_count,
    ROUND(AVG(Total_Severity), 2) AS avg_severity,
    ROUND(AVG(Hyperactivity_Index), 2) AS avg_hyperactivity,
    ROUND(AVG(Inattention_Index), 2) AS avg_inattention,
    ROUND(AVG(Anxiety_Depression_Levels), 2) AS avg_anxiety,
    -- Percentage within each family history group
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY Family_History),
        1
    ) AS pct_within_group
FROM adhd_clean
WHERE Age BETWEEN 5 AND 14
GROUP BY Family_History,
    Diagnosis_Label,
    Diagnosis_Class
ORDER BY Family_History,
    Diagnosis_Class;
-- ==============================================================
-- SECTION 10: SEVERITY RANKING + OUTLIER DETECTION
-- Z-score based outlier flagging using STDDEV window function
-- ==============================================================
WITH population_stats AS (
    -- Compute mean and SD per diagnosis group
    SELECT Diagnosis_Class,
        Diagnosis_Label,
        AVG(Total_Severity) AS mean_sev,
        STDDEV(Total_Severity) AS std_sev
    FROM adhd_clean
    WHERE Age BETWEEN 5 AND 14
    GROUP BY Diagnosis_Class,
        Diagnosis_Label
),
patient_ranked AS (
    SELECT a.id,
        a.Age,
        a.Gender,
        a.Diagnosis_Label,
        a.Total_Severity,
        a.Hyperactivity_Index,
        a.Inattention_Index,
        a.Sleep_Hours,
        a.Daily_Phone_Usage_Hours,
        a.Anxiety_Depression_Levels,
        -- Rank within diagnosis group
        RANK() OVER (
            PARTITION BY a.Diagnosis_Class
            ORDER BY a.Total_Severity DESC
        ) AS severity_rank,
        -- Z-score
        ROUND(
            (a.Total_Severity - p.mean_sev) / NULLIF(p.std_sev, 0),
            2
        ) AS z_score,
        -- Outlier flag (beyond 2 SD)
        CASE
            WHEN ABS(
                (a.Total_Severity - p.mean_sev) / NULLIF(p.std_sev, 0)
            ) > 2 THEN 'Outlier'
            ELSE 'Normal'
        END AS outlier_flag
    FROM adhd_clean a
        JOIN population_stats p ON a.Diagnosis_Class = p.Diagnosis_Class
    WHERE a.Age BETWEEN 5 AND 14
)
SELECT *
FROM patient_ranked
WHERE severity_rank <= 5
    OR outlier_flag = 'Outlier'
ORDER BY Diagnosis_Label,
    severity_rank;
-- ==============================================================
-- SECTION 11: COMORBIDITY RISK MATRIX
-- Cross-tabulation of risk factors — how they co-occur
-- across diagnosis groups
-- ==============================================================
SELECT Diagnosis_Label,
    -- Individual risk factor rates
    ROUND(100.0 * AVG(Sleep_Risk_Flag), 1) AS pct_sleep_risk,
    ROUND(100.0 * AVG(High_Screen_Flag), 1) AS pct_high_screen,
    ROUND(100.0 * AVG(Anxiety_Risk_Flag), 1) AS pct_anxiety_risk,
    ROUND(100.0 * AVG(Learning_Difficulties::NUMERIC), 1) AS pct_learning_diff,
    ROUND(
        100.0 * AVG(Difficulty_Organizing_Tasks::NUMERIC),
        1
    ) AS pct_org_difficulty,
    -- Co-occurrence rates
    ROUND(
        100.0 * SUM(
            CASE
                WHEN Sleep_Risk_Flag = 1
                AND High_Screen_Flag = 1 THEN 1
                ELSE 0
            END
        )::NUMERIC / COUNT(*),
        1
    ) AS pct_sleep_AND_screen,
    ROUND(
        100.0 * SUM(
            CASE
                WHEN Sleep_Risk_Flag = 1
                AND Anxiety_Risk_Flag = 1 THEN 1
                ELSE 0
            END
        )::NUMERIC / COUNT(*),
        1
    ) AS pct_sleep_AND_anxiety,
    ROUND(
        100.0 * SUM(
            CASE
                WHEN Sleep_Risk_Flag = 1
                AND High_Screen_Flag = 1
                AND Anxiety_Risk_Flag = 1 THEN 1
                ELSE 0
            END
        )::NUMERIC / COUNT(*),
        1
    ) AS pct_all_three_risks
FROM adhd_clean
WHERE Age BETWEEN 5 AND 14
GROUP BY Diagnosis_Label,
    Diagnosis_Class
ORDER BY Diagnosis_Class;
-- ==============================================================
-- SECTION 12: GENDER ANALYSIS
-- ADHD prevalence and severity split by gender
-- ==============================================================
-- 12a. Gender prevalence
SELECT Gender,
    Diagnosis_Label,
    COUNT(*) AS patient_count,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY Gender),
        1
    ) AS pct_within_gender,
    ROUND(AVG(Total_Severity), 2) AS avg_severity,
    ROUND(AVG(Hyperactivity_Index), 2) AS avg_hyperactivity,
    ROUND(AVG(Inattention_Index), 2) AS avg_inattention
FROM adhd_clean
WHERE Age BETWEEN 5 AND 14
GROUP BY Gender,
    Diagnosis_Label,
    Diagnosis_Class
ORDER BY Gender,
    Diagnosis_Class;
-- 12b. Gender severity gap (pivot-style)
SELECT Diagnosis_Label,
    ROUND(
        AVG(
            CASE
                WHEN Gender = 'Male' THEN Total_Severity
            END
        ),
        2
    ) AS avg_severity_male,
    ROUND(
        AVG(
            CASE
                WHEN Gender = 'Female' THEN Total_Severity
            END
        ),
        2
    ) AS avg_severity_female,
    ROUND(
        AVG(
            CASE
                WHEN Gender = 'Male' THEN Total_Severity
            END
        ) - AVG(
            CASE
                WHEN Gender = 'Female' THEN Total_Severity
            END
        ),
        2
    ) AS severity_gap_M_minus_F
FROM adhd_clean
WHERE Age BETWEEN 5 AND 14
GROUP BY Diagnosis_Label,
    Diagnosis_Class
ORDER BY Diagnosis_Class;
-- ==============================================================
-- SECTION 13: EDUCATIONAL LEVEL VS DIAGNOSIS
-- How does school stage map to diagnosis rates?
-- ==============================================================
SELECT Educational_Level,
    COUNT(*) AS total,
    SUM(
        CASE
            WHEN Diagnosis_Class != 0 THEN 1
            ELSE 0
        END
    ) AS adhd_count,
    ROUND(
        100.0 * SUM(
            CASE
                WHEN Diagnosis_Class != 0 THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        1
    ) AS adhd_prevalence_pct,
    ROUND(AVG(Total_Severity), 2) AS avg_severity,
    ROUND(AVG(Focus_Score_Video), 2) AS avg_focus,
    ROUND(AVG(Learning_Difficulties::NUMERIC), 2) AS avg_learning_diff,
    -- Rank educational levels by prevalence
    RANK() OVER (
        ORDER BY 100.0 * SUM(
                CASE
                    WHEN Diagnosis_Class != 0 THEN 1
                    ELSE 0
                END
            ) / COUNT(*) DESC
    ) AS prevalence_rank
FROM adhd_clean
GROUP BY Educational_Level
ORDER BY adhd_prevalence_pct DESC;
