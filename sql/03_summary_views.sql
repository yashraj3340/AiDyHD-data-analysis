-- ==============================================================
-- SECTION 14: EXECUTIVE SUMMARY VIEW
-- One-query summary a non-technical stakeholder can read
-- ==============================================================
CREATE OR REPLACE VIEW adhd_executive_summary AS WITH base AS (
        SELECT Life_Stage,
            CASE
                Life_Stage
                WHEN 'Early Childhood (3-4)' THEN 1
                WHEN 'Pediatric (5-14)' THEN 2
                WHEN 'Adolescent (15-18)' THEN 3
                WHEN 'Adult (19-55)' THEN 4
            END AS stage_order,
            COUNT(*) AS total_patients,
            SUM(
                CASE
                    WHEN Diagnosis_Class != 0 THEN 1
                    ELSE 0
                END
            ) AS adhd_total,
            SUM(
                CASE
                    WHEN Diagnosis_Class = 1 THEN 1
                    ELSE 0
                END
            ) AS inattentive_count,
            SUM(
                CASE
                    WHEN Diagnosis_Class = 2 THEN 1
                    ELSE 0
                END
            ) AS hyperactive_count,
            SUM(
                CASE
                    WHEN Diagnosis_Class = 3 THEN 1
                    ELSE 0
                END
            ) AS combined_count,
            ROUND(AVG(Total_Severity), 1) AS avg_severity,
            ROUND(AVG(Sleep_Hours), 1) AS avg_sleep,
            ROUND(AVG(Daily_Phone_Usage_Hours), 1) AS avg_screen_time,
            ROUND(AVG(Anxiety_Depression_Levels), 1) AS avg_anxiety,
            SUM(
                CASE
                    WHEN Family_History = 'Yes' THEN 1
                    ELSE 0
                END
            ) AS family_history_yes
        FROM adhd_clean
        WHERE Life_Stage IS NOT NULL
        GROUP BY Life_Stage
    )
SELECT Life_Stage,
    total_patients,
    ROUND(100.0 * adhd_total / total_patients, 1) AS adhd_prevalence_pct,
    inattentive_count,
    hyperactive_count,
    combined_count,
    avg_severity,
    avg_sleep,
    avg_screen_time,
    avg_anxiety,
    ROUND(100.0 * family_history_yes / total_patients, 1) AS family_history_pct
FROM base
ORDER BY stage_order;
-- Run the executive summary
SELECT *
FROM adhd_executive_summary;
