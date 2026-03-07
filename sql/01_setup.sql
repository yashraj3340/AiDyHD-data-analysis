/*
 ================================================================
 AiDyHD — Pediatric & Lifespan ADHD Diagnostic Analytics
 PostgreSQL Analysis Script
 
 Dataset  : 6,500 patients, ages 3–55, 32 clinical variables
 Author   : Yashraj Gharte
 Created  : 2025-06-01
 
 DIAGNOSIS MAPPING:
 0 = No ADHD
 1 = Inattentive Type
 2 = Hyperactive Type
 3 = Combined Type
 
 CONTENTS:
 ─────────────────────────────────────────────
 in these file
 SECTION 1 : Database Setup & Data Cleaning
 2nd file -- 02_analysis.sql
 SECTION 2 : Cohort Overview
 SECTION 3 : Diagnosis Distribution
 SECTION 4 : Prevalence by Age (Window Functions)
 SECTION 5 : Life-Stage Cohort Comparison
 SECTION 6 : Risk Stratification (CTEs)
 SECTION 7 : Statistical Percentiles by Diagnosis
 SECTION 8 : Lifestyle Factor Analysis
 SECTION 9 : Family History Impact
 SECTION 10 : Severity Ranking + Outlier Detection
 SECTION 11 : Comorbidity Risk Matrix
 SECTION 12 : Gender Analysis
 SECTION 13 : Educational Level vs Diagnosis
 3rd file -- 03_summary_views.sql
 SECTION 14 : Executive Summary View
 ================================================================
 */
-- ==============================================================
-- SECTION 1: DATABASE SETUP & DATA CLEANING
-- ==============================================================
-- Create the main table
CREATE TABLE IF NOT EXISTS adhd_patients (
    id SERIAL PRIMARY KEY,
    Age NUMERIC,
    Gender INTEGER,
    -- 1 = Male, 2 = Female
    Educational_Level VARCHAR(50),
    Family_History VARCHAR(10),
    Sleep_Hours NUMERIC,
    Daily_Activity_Hours NUMERIC,
    Q1_1 INTEGER,
    Q1_2 INTEGER,
    Q1_3 INTEGER,
    Q1_4 INTEGER,
    Q1_5 INTEGER,
    Q1_6 INTEGER,
    Q1_7 INTEGER,
    Q1_8 INTEGER,
    Q1_9 INTEGER,
    Q2_1 INTEGER,
    Q2_2 INTEGER,
    Q2_3 INTEGER,
    Q2_4 INTEGER,
    Q2_5 INTEGER,
    Q2_6 INTEGER,
    Q2_7 INTEGER,
    Q2_8 INTEGER,
    Q2_9 INTEGER,
    Diagnosis_Class INTEGER,
    Daily_Phone_Usage_Hours NUMERIC,
    Daily_Walking_Running_Hours NUMERIC,
    Difficulty_Organizing_Tasks INTEGER,
    Focus_Score_Video NUMERIC,
    Daily_Coffee_Tea_Consumption NUMERIC,
    Learning_Difficulties INTEGER,
    Anxiety_Depression_Levels INTEGER
);
-- Import CSV:
COPY adhd_patients(
    Age,
    Gender,
    Educational_Level,
    Family_History,
    Sleep_Hours,
    Daily_Activity_Hours,
    Q1_1,
    Q1_2,
    Q1_3,
    Q1_4,
    Q1_5,
    Q1_6,
    Q1_7,
    Q1_8,
    Q1_9,
    Q2_1,
    Q2_2,
    Q2_3,
    Q2_4,
    Q2_5,
    Q2_6,
    Q2_7,
    Q2_8,
    Q2_9,
    Diagnosis_Class,
    Daily_Phone_Usage_Hours,
    Daily_Walking_Running_Hours,
    Difficulty_Organizing_Tasks,
    Focus_Score_Video,
    Daily_Coffee_Tea_Consumption,
    Learning_Difficulties,
    Anxiety_Depression_Levels
)
FROM 'C:/Users/Yashraj Gharte/Desktop/final projects/AiDyHD/raw_adhd_data.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',');
--cross check
SELECT *
FROM adhd_patients
LIMIT 10;
-- Create a cleaned view with readable labels and derived columns
-- This view is used by all subsequent queries
CREATE OR REPLACE VIEW adhd_clean AS
SELECT id,
    Age,
    CASE
        WHEN Gender = 1 THEN 'Male'
        ELSE 'Female'
    END AS Gender,
    Educational_Level,
    Family_History,
    Sleep_Hours,
    Daily_Activity_Hours,
    -- Computed cluster scores
    (
        Q1_1 + Q1_2 + Q1_3 + Q1_4 + Q1_5 + Q1_6 + Q1_7 + Q1_8 + Q1_9
    ) AS Hyperactivity_Index,
    (
        Q2_1 + Q2_2 + Q2_3 + Q2_4 + Q2_5 + Q2_6 + Q2_7 + Q2_8 + Q2_9
    ) AS Inattention_Index,
    (
        Q1_1 + Q1_2 + Q1_3 + Q1_4 + Q1_5 + Q1_6 + Q1_7 + Q1_8 + Q1_9 + Q2_1 + Q2_2 + Q2_3 + Q2_4 + Q2_5 + Q2_6 + Q2_7 + Q2_8 + Q2_9
    ) AS Total_Severity,
    -- Readable diagnosis label
    CASE
        Diagnosis_Class
        WHEN 0 THEN 'No ADHD'
        WHEN 1 THEN 'Inattentive Type'
        WHEN 2 THEN 'Hyperactive Type'
        WHEN 3 THEN 'Combined Type'
    END AS Diagnosis_Label,
    Diagnosis_Class,
    -- Life stage segmentation
    CASE
        WHEN Age BETWEEN 3 AND 4 THEN 'Early Childhood (3-4)'
        WHEN Age BETWEEN 5 AND 14 THEN 'Pediatric (5-14)'
        WHEN Age BETWEEN 15 AND 18 THEN 'Adolescent (15-18)'
        WHEN Age BETWEEN 19 AND 55 THEN 'Adult (19-55)'
    END AS Life_Stage,
    -- Age band (pediatric)
    CASE
        WHEN Age BETWEEN 5 AND 6 THEN '5-6 Early'
        WHEN Age BETWEEN 7 AND 8 THEN '7-8 Young'
        WHEN Age BETWEEN 9 AND 10 THEN '9-10 Mid'
        WHEN Age BETWEEN 11 AND 12 THEN '11-12 Pre-Teen'
        WHEN Age BETWEEN 13 AND 14 THEN '13-14 Teen'
    END AS Age_Band,
    Daily_Phone_Usage_Hours,
    Daily_Walking_Running_Hours,
    Difficulty_Organizing_Tasks,
    Focus_Score_Video,
    Daily_Coffee_Tea_Consumption,
    Learning_Difficulties,
    Anxiety_Depression_Levels,
    -- Risk flags
    CASE
        WHEN Sleep_Hours < 7 THEN 1
        ELSE 0
    END AS Sleep_Risk_Flag,
    CASE
        WHEN Daily_Phone_Usage_Hours > 4 THEN 1
        ELSE 0
    END AS High_Screen_Flag,
    CASE
        WHEN Anxiety_Depression_Levels >= 3 THEN 1
        ELSE 0
    END AS Anxiety_Risk_Flag
FROM adhd_patients;
