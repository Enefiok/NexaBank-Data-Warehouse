-- ==========================================
-- NEXABANK MASTER AUTOMATION SCRIPT (ABSOLUTE FINAL VERSION)
-- ==========================================

/*
====================================================================
NEXABANK DATA WAREHOUSE - SETUP INSTRUCTIONS
====================================================================
1. Ensure you have MySQL 8.0+ and MySQL Workbench installed.
2. Create a folder on your computer for this project.
3. Inside that folder, create an 'input' folder and place the 5 raw 
   data files inside it (raw_source1... through raw_source5...).
4. IMPORTANT: Update the file paths in the 'STEP 6: LOAD DATA' 
   section below to match the location of your 'input' folder.
   (Example: 'C:/YourName/Projects/NexaBank/input/raw_source1...')
5. Open this file in MySQL Workbench and click the Execute (Lightning Bolt) button.
====================================================================
*/

-- STEP 1: PERMISSIONS
SET GLOBAL local_infile = 1;
SET SQL_SAFE_UPDATES = 0;

-- STEP 2: ARCHIVE OLD DATA (Safe method that won't crash on first run)
DROP PROCEDURE IF EXISTS archive_nexabank_data;
DELIMITER //
CREATE PROCEDURE archive_nexabank_data()
BEGIN
    DECLARE db_exists INT;
    SELECT COUNT(*) INTO db_exists FROM information_schema.SCHEMATA WHERE SCHEMA_NAME = 'nexabank_dw';
    
    IF db_exists > 0 THEN
        CREATE DATABASE IF NOT EXISTS nexabank_history;
        
        DROP TABLE IF EXISTS nexabank_history.dim_customers_archive;
        DROP TABLE IF EXISTS nexabank_history.fct_transactions_archive;
        DROP TABLE IF EXISTS nexabank_history.fct_loans_archive;
        
        CREATE TABLE nexabank_history.dim_customers_archive AS 
            SELECT *, NOW() as archived_at FROM nexabank_dw.dim_customers;
        CREATE TABLE nexabank_history.fct_transactions_archive AS 
            SELECT *, NOW() as archived_at FROM nexabank_dw.fct_transactions;
        CREATE TABLE nexabank_history.fct_loans_archive AS 
            SELECT *, NOW() as archived_at FROM nexabank_dw.fct_loans;
    END IF;
END //
DELIMITER ;

CALL archive_nexabank_data();
DROP PROCEDURE IF EXISTS archive_nexabank_data;

-- STEP 3: CLEAN SLATE
DROP DATABASE IF EXISTS nexabank_dw;
CREATE DATABASE nexabank_dw CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE nexabank_dw;

-- STEP 4: CREATE STAGING TABLES
CREATE TABLE stg_transactions (transaction_id VARCHAR(50), customer_id VARCHAR(50), branch_id VARCHAR(50), raw_transaction_type VARCHAR(100), raw_channel VARCHAR(100), raw_transaction_date VARCHAR(50), raw_transaction_time VARCHAR(50), amount_local VARCHAR(100), local_currency VARCHAR(10), amount_usd VARCHAR(100), raw_description VARCHAR(255), reference_code VARCHAR(100), balance_after_local VARCHAR(100));
CREATE TABLE stg_loans (loan_id VARCHAR(50), customer_id VARCHAR(50), branch_id VARCHAR(50), raw_loan_status VARCHAR(100), loan_purpose VARCHAR(150), local_currency VARCHAR(10), loan_amount_local VARCHAR(100), loan_amount_usd VARCHAR(100), interest_rate_pct VARCHAR(100), tenure_months VARCHAR(50), amount_repaid_local VARCHAR(100), outstanding_balance VARCHAR(100), raw_disbursement_date VARCHAR(50), raw_maturity_date VARCHAR(50));
CREATE TABLE stg_customers (customer_id VARCHAR(50), account_number VARCHAR(100), raw_first_name VARCHAR(100), raw_last_name VARCHAR(100), raw_email VARCHAR(150), raw_phone VARCHAR(100), raw_country VARCHAR(100), raw_city VARCHAR(150), account_type VARCHAR(100), raw_kyc_status VARCHAR(100), bvn_nin VARCHAR(100), annual_income_local VARCHAR(100), local_currency VARCHAR(10), raw_dob VARCHAR(50), raw_account_open_date VARCHAR(50));
CREATE TABLE stg_branch_metrics (branch_id VARCHAR(50), raw_branch_name VARCHAR(150), raw_country VARCHAR(100), raw_local_currency VARCHAR(10), report_date VARCHAR(50), total_transactions VARCHAR(50), total_debit_local VARCHAR(100), total_credit_local VARCHAR(100), new_accounts_opened VARCHAR(50), loan_applications VARCHAR(50), atm_downtime_minutes VARCHAR(50), raw_staff_count VARCHAR(50), net_inflow_outflow VARCHAR(100));
CREATE TABLE stg_fx_rates (currency_code VARCHAR(10), currency_name VARCHAR(100), rate_to_usd VARCHAR(100), buy_rate_local VARCHAR(100), sell_rate_local VARCHAR(100), effective_date VARCHAR(50), source VARCHAR(150));

-- STEP 5: CREATE PRODUCTION TABLES (FIXED: Increased size to DECIMAL(30,2) to prevent ANY truncation)
CREATE TABLE dim_fx_rates (currency_code CHAR(3) PRIMARY KEY, currency_name VARCHAR(100) NOT NULL, rate_to_usd DECIMAL(18,6) NOT NULL, buy_rate_local DECIMAL(18,6) NOT NULL, sell_rate_local DECIMAL(18,6) NOT NULL, effective_date DATE NOT NULL);
CREATE TABLE dim_branches (branch_id INT PRIMARY KEY, branch_name VARCHAR(150) NOT NULL, country VARCHAR(100) NOT NULL, local_currency CHAR(3) NOT NULL);
CREATE TABLE dim_customers (customer_id INT PRIMARY KEY, account_number VARCHAR(50) UNIQUE NOT NULL, first_name VARCHAR(100) NOT NULL, last_name VARCHAR(100) NOT NULL, full_name VARCHAR(210) NOT NULL, email VARCHAR(150), phone_clean VARCHAR(50), country VARCHAR(100), city VARCHAR(150), account_type VARCHAR(100), kyc_status VARCHAR(50), annual_income_usd DECIMAL(30,2), account_open_date DATE);
CREATE TABLE fct_transactions (transaction_id INT PRIMARY KEY, customer_id INT NOT NULL, branch_id INT NOT NULL, currency_code CHAR(3) NOT NULL, transaction_type VARCHAR(50) NOT NULL, channel VARCHAR(100) NOT NULL, transaction_date DATE NOT NULL, transaction_time TIME, amount_local DECIMAL(18,2) NOT NULL, amount_usd DECIMAL(30,2) NOT NULL, description VARCHAR(255), reference_code VARCHAR(100), balance_after_local DECIMAL(18,2), balance_after_usd DECIMAL(30,2), FOREIGN KEY (customer_id) REFERENCES dim_customers(customer_id), FOREIGN KEY (branch_id) REFERENCES dim_branches(branch_id), FOREIGN KEY (currency_code) REFERENCES dim_fx_rates(currency_code));
CREATE TABLE fct_loans (loan_id INT PRIMARY KEY, customer_id INT NOT NULL, branch_id INT NOT NULL, currency_code CHAR(3) NOT NULL, loan_purpose VARCHAR(150), loan_status VARCHAR(50), loan_amount_local DECIMAL(18,2), loan_amount_usd DECIMAL(30,2), interest_rate_pct DECIMAL(10,2), tenure_months INT, amount_repaid_local DECIMAL(18,2), outstanding_balance DECIMAL(30,2), disbursement_date DATE, maturity_date DATE, FOREIGN KEY (customer_id) REFERENCES dim_customers(customer_id), FOREIGN KEY (branch_id) REFERENCES dim_branches(branch_id), FOREIGN KEY (currency_code) REFERENCES dim_fx_rates(currency_code));
CREATE TABLE fct_branch_daily_metrics (metric_id INT AUTO_INCREMENT PRIMARY KEY, branch_id INT NOT NULL, report_date DATE NOT NULL, total_transactions INT DEFAULT 0, total_debit_local DECIMAL(18,2) DEFAULT 0, total_credit_local DECIMAL(18,2) DEFAULT 0, new_accounts_opened INT DEFAULT 0, loan_applications INT DEFAULT 0, atm_downtime_mins INT DEFAULT 0, staff_count INT DEFAULT 0, net_inflow_outflow DECIMAL(18,2) DEFAULT 0, FOREIGN KEY (branch_id) REFERENCES dim_branches(branch_id));

-- STEP 6: LOAD DATA FROM INPUT FOLDER
LOAD DATA LOCAL INFILE 'C:/Users/user/Downloads/nexabank_raw_data/NexaBank_Project/input/raw_source1_core_transactions.csv' INTO TABLE stg_transactions FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS;
LOAD DATA LOCAL INFILE 'C:/Users/user/Downloads/nexabank_raw_data/NexaBank_Project/input/raw_source3_customer_kyc.tsv' INTO TABLE stg_customers FIELDS TERMINATED BY '\t' ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS;
LOAD DATA LOCAL INFILE 'C:/Users/user/Downloads/nexabank_raw_data/NexaBank_Project/input/raw_source2_loan_portfolio.csv' INTO TABLE stg_loans FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS;
LOAD DATA LOCAL INFILE 'C:/Users/user/Downloads/nexabank_raw_data/NexaBank_Project/input/raw_source4_branch_performance.csv' INTO TABLE stg_branch_metrics FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS;
LOAD DATA LOCAL INFILE 'C:/Users/user/Downloads/nexabank_raw_data/NexaBank_Project/input/raw_source5_fx_reference_rates.csv' INTO TABLE stg_fx_rates FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS;

-- STEP 7: ETL PIPELINE (FIXED: Added ROUND(..., 2) to all money calculations to stop Error 1265)
INSERT INTO dim_fx_rates (currency_code, currency_name, rate_to_usd, buy_rate_local, sell_rate_local, effective_date) 
SELECT UPPER(TRIM(currency_code)), TRIM(currency_name), CAST(REPLACE(rate_to_usd,',','') AS DECIMAL(18,6)), CAST(REPLACE(buy_rate_local,',','') AS DECIMAL(18,6)), CAST(REPLACE(sell_rate_local,',','') AS DECIMAL(18,6)), STR_TO_DATE(TRIM(effective_date), '%Y-%m-%d') FROM stg_fx_rates;

INSERT INTO dim_branches (branch_id, branch_name, country, local_currency) 
SELECT DISTINCT CAST(branch_id AS UNSIGNED), CASE CAST(branch_id AS UNSIGNED) WHEN 101 THEN 'Victoria Island Lagos' WHEN 102 THEN 'Ikeja GRA Lagos' WHEN 103 THEN 'Abuja Central' WHEN 104 THEN 'Port Harcourt City' WHEN 105 THEN 'Kano Commercial District' WHEN 106 THEN 'Accra Downtown' WHEN 107 THEN 'Kumasi Branch' WHEN 108 THEN 'Nairobi CBD' WHEN 109 THEN 'Mombasa Coastal' WHEN 110 THEN 'Johannesburg Sandton' WHEN 111 THEN 'Cape Town City Centre' WHEN 112 THEN 'London Canary Wharf' WHEN 113 THEN 'Frankfurt International' WHEN 114 THEN 'Dubai DIFC' WHEN 115 THEN 'New York Midtown' ELSE 'Unknown' END, CONCAT(UPPER(LEFT(TRIM(raw_country), 1)), LOWER(SUBSTRING(TRIM(raw_country), 2))), UPPER(TRIM(raw_local_currency)) FROM stg_branch_metrics;

INSERT INTO dim_customers (customer_id, account_number, first_name, last_name, full_name, email, phone_clean, country, city, account_type, kyc_status, annual_income_usd, account_open_date) 
SELECT CAST(c.customer_id AS UNSIGNED), TRIM(c.account_number), CONCAT(UPPER(LEFT(LOWER(TRIM(c.raw_first_name)), 1)), SUBSTRING(LOWER(TRIM(c.raw_first_name)), 2)), CONCAT(UPPER(LEFT(LOWER(TRIM(c.raw_last_name)), 1)), SUBSTRING(LOWER(TRIM(c.raw_last_name)), 2)), CONCAT_WS(' ', CONCAT(UPPER(LEFT(LOWER(TRIM(c.raw_first_name)), 1)), SUBSTRING(LOWER(TRIM(c.raw_first_name)), 2)), CONCAT(UPPER(LEFT(LOWER(TRIM(c.raw_last_name)), 1)), SUBSTRING(LOWER(TRIM(c.raw_last_name)), 2))), NULLIF(TRIM(c.raw_email), ''), NULLIF(REGEXP_REPLACE(TRIM(c.raw_phone), '[^0-9+]', ''), ''), TRIM(c.raw_country), TRIM(c.raw_city), TRIM(c.account_type), CASE UPPER(TRIM(c.raw_kyc_status)) WHEN 'VERIFIED' THEN 'Verified' WHEN 'FAILED' THEN 'Failed' WHEN 'UNDER REVIEW' THEN 'Under Review' WHEN 'EXPIRED' THEN 'Expired' WHEN 'PENDING' THEN 'Pending' ELSE 'Unknown' END, ROUND(CASE WHEN TRIM(c.annual_income_local) REGEXP '^-?[0-9,]+([.][0-9]+)?$' AND TRIM(fx.rate_to_usd) REGEXP '^-?[0-9]+([.][0-9]+)?$' THEN CAST(REPLACE(TRIM(c.annual_income_local), ',', '') AS DECIMAL(30,2)) * CAST(TRIM(fx.rate_to_usd) AS DECIMAL(18,6)) ELSE NULL END, 2), COALESCE(CASE WHEN TRIM(c.raw_account_open_date) REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN STR_TO_DATE(TRIM(c.raw_account_open_date), '%Y-%m-%d') WHEN TRIM(c.raw_account_open_date) REGEXP '^[0-9]{2}-[A-Za-z]{3}-[0-9]{4}$' THEN STR_TO_DATE(TRIM(c.raw_account_open_date), '%d-%b-%Y') WHEN TRIM(c.raw_account_open_date) REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$' THEN CASE WHEN CAST(SUBSTRING_INDEX(TRIM(c.raw_account_open_date), '/', 1) AS UNSIGNED) > 12 THEN STR_TO_DATE(TRIM(c.raw_account_open_date), '%d/%m/%Y') ELSE STR_TO_DATE(TRIM(c.raw_account_open_date), '%m/%d/%Y') END ELSE NULL END, '1970-01-01') FROM stg_customers AS c JOIN dim_fx_rates AS fx ON UPPER(TRIM(c.local_currency)) = UPPER(TRIM(fx.currency_code));

INSERT INTO fct_transactions (transaction_id, customer_id, branch_id, currency_code, transaction_type, channel, transaction_date, transaction_time, amount_local, amount_usd, description, reference_code, balance_after_local, balance_after_usd) 
SELECT CAST(t.transaction_id AS UNSIGNED), CAST(t.customer_id AS UNSIGNED), CAST(t.branch_id AS UNSIGNED), UPPER(TRIM(t.local_currency)), CONCAT(UPPER(LEFT(LOWER(TRIM(t.raw_transaction_type)), 1)), SUBSTRING(LOWER(TRIM(t.raw_transaction_type)), 2)), CASE UPPER(TRIM(t.raw_channel)) WHEN '' THEN 'Unknown' WHEN 'A.T.M' THEN 'ATM' WHEN 'ATM' THEN 'ATM' WHEN 'POS' THEN 'POS Terminal' WHEN 'POS TERMINAL' THEN 'POS Terminal' WHEN '*966#' THEN 'USSD' ELSE CONCAT(UPPER(LEFT(LOWER(TRIM(t.raw_channel)), 1)), SUBSTRING(LOWER(TRIM(t.raw_channel)), 2)) END, COALESCE(CASE WHEN TRIM(t.raw_transaction_date) REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN STR_TO_DATE(TRIM(t.raw_transaction_date), '%Y-%m-%d') WHEN TRIM(t.raw_transaction_date) REGEXP '^[0-9]{2}-[A-Za-z]{3}-[0-9]{4}$' THEN STR_TO_DATE(TRIM(t.raw_transaction_date), '%d-%b-%Y') WHEN TRIM(t.raw_transaction_date) REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$' THEN CASE WHEN CAST(SUBSTRING_INDEX(TRIM(t.raw_transaction_date), '/', 1) AS UNSIGNED) > 12 THEN STR_TO_DATE(TRIM(t.raw_transaction_date), '%d/%m/%Y') ELSE STR_TO_DATE(TRIM(t.raw_transaction_date), '%m/%d/%Y') END ELSE NULL END, '1970-01-01'), STR_TO_DATE(TRIM(t.raw_transaction_time), '%H:%i:%s'), CAST(REPLACE(TRIM(t.amount_local), ',', '') AS DECIMAL(18,2)), ROUND(CAST(REPLACE(TRIM(t.amount_local), ',', '') AS DECIMAL(30,2)) * fx.rate_to_usd, 2), TRIM(t.raw_description), TRIM(t.reference_code), CAST(REPLACE(TRIM(t.balance_after_local), ',', '') AS DECIMAL(18,2)), ROUND(CAST(REPLACE(TRIM(t.balance_after_local), ',', '') AS DECIMAL(30,2)) * fx.rate_to_usd, 2) FROM stg_transactions t JOIN dim_fx_rates fx ON UPPER(TRIM(t.local_currency)) = fx.currency_code;

INSERT INTO fct_loans (loan_id, customer_id, branch_id, currency_code, loan_purpose, loan_status, loan_amount_local, loan_amount_usd, interest_rate_pct, tenure_months, amount_repaid_local, outstanding_balance, disbursement_date, maturity_date) 
SELECT CAST(l.loan_id AS UNSIGNED), CAST(l.customer_id AS UNSIGNED), CAST(l.branch_id AS UNSIGNED), UPPER(TRIM(l.local_currency)), TRIM(l.loan_purpose), CASE UPPER(TRIM(l.raw_loan_status)) WHEN 'ACTIVE' THEN 'Active' WHEN 'FULLY PAID' THEN 'Fully Paid' WHEN 'DEFAULTED' THEN 'Defaulted' WHEN 'WRITTEN OFF' THEN 'Written Off' WHEN 'RESTRUCTURED' THEN 'Restructured' WHEN 'APPROVED' THEN 'Approved' WHEN 'PENDING REVIEW' THEN 'Pending Review' ELSE 'Unknown' END, CAST(REPLACE(TRIM(l.loan_amount_local), ',', '') AS DECIMAL(18,2)), ROUND(CAST(REPLACE(TRIM(l.loan_amount_local), ',', '') AS DECIMAL(30,2)) * fx.rate_to_usd, 2), CAST(REPLACE(TRIM(l.interest_rate_pct), ',', '') AS DECIMAL(10,2)), CAST(l.tenure_months AS UNSIGNED), CAST(REPLACE(TRIM(l.amount_repaid_local), ',', '') AS DECIMAL(18,2)), ROUND(CAST(REPLACE(TRIM(l.outstanding_balance), ',', '') AS DECIMAL(30,2)) * fx.rate_to_usd, 2), COALESCE(CASE WHEN TRIM(l.raw_disbursement_date) REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN STR_TO_DATE(TRIM(l.raw_disbursement_date), '%Y-%m-%d') WHEN TRIM(l.raw_disbursement_date) REGEXP '^[0-9]{2}-[A-Za-z]{3}-[0-9]{4}$' THEN STR_TO_DATE(TRIM(l.raw_disbursement_date), '%d-%b-%Y') WHEN TRIM(l.raw_disbursement_date) REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$' THEN CASE WHEN CAST(SUBSTRING_INDEX(TRIM(l.raw_disbursement_date), '/', 1) AS UNSIGNED) > 12 THEN STR_TO_DATE(TRIM(l.raw_disbursement_date), '%d/%m/%Y') ELSE STR_TO_DATE(TRIM(l.raw_disbursement_date), '%m/%d/%Y') END ELSE NULL END, '1970-01-01'), COALESCE(CASE WHEN TRIM(l.raw_maturity_date) REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN STR_TO_DATE(TRIM(l.raw_maturity_date), '%Y-%m-%d') WHEN TRIM(l.raw_maturity_date) REGEXP '^[0-9]{2}-[A-Za-z]{3}-[0-9]{4}$' THEN STR_TO_DATE(TRIM(l.raw_maturity_date), '%d-%b-%Y') WHEN TRIM(l.raw_maturity_date) REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$' THEN CASE WHEN CAST(SUBSTRING_INDEX(TRIM(l.raw_maturity_date), '/', 1) AS UNSIGNED) > 12 THEN STR_TO_DATE(TRIM(l.raw_maturity_date), '%d/%m/%Y') ELSE STR_TO_DATE(TRIM(l.raw_maturity_date), '%m/%d/%Y') END ELSE NULL END, '1970-01-01') FROM stg_loans l JOIN dim_fx_rates fx ON UPPER(TRIM(l.local_currency)) = fx.currency_code;

-- FIXED: Explicitly listing columns to prevent Error 1136
INSERT INTO fct_branch_daily_metrics (branch_id, report_date, total_transactions, total_debit_local, total_credit_local, new_accounts_opened, loan_applications, atm_downtime_mins, staff_count, net_inflow_outflow) 
SELECT b.branch_id, COALESCE(CASE WHEN TRIM(m.report_date) REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN STR_TO_DATE(TRIM(m.report_date), '%Y-%m-%d') WHEN TRIM(m.report_date) REGEXP '^[0-9]{2}-[A-Za-z]{3}-[0-9]{4}$' THEN STR_TO_DATE(TRIM(m.report_date), '%d-%b-%Y') WHEN TRIM(m.report_date) REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$' THEN CASE WHEN CAST(SUBSTRING_INDEX(TRIM(m.report_date), '/', 1) AS UNSIGNED) > 12 THEN STR_TO_DATE(TRIM(m.report_date), '%d/%m/%Y') ELSE STR_TO_DATE(TRIM(m.report_date), '%m/%d/%Y') END ELSE NULL END, '1970-01-01'), COALESCE(CAST(REPLACE(TRIM(m.total_transactions), ',', '') AS UNSIGNED), 0), COALESCE(CAST(REPLACE(TRIM(m.total_debit_local), ',', '') AS DECIMAL(18,2)), 0), COALESCE(CAST(REPLACE(TRIM(m.total_credit_local), ',', '') AS DECIMAL(18,2)), 0), COALESCE(CAST(REPLACE(TRIM(m.new_accounts_opened), ',', '') AS UNSIGNED), 0), COALESCE(CAST(REPLACE(TRIM(m.loan_applications), ',', '') AS UNSIGNED), 0), COALESCE(CAST(REPLACE(TRIM(m.atm_downtime_minutes), ',', '') AS UNSIGNED), 0), COALESCE(CAST(REPLACE(TRIM(m.raw_staff_count), ',', '') AS UNSIGNED), 0), COALESCE(CAST(REPLACE(TRIM(m.net_inflow_outflow), ',', '') AS DECIMAL(18,2)), 0) FROM stg_branch_metrics AS m JOIN dim_branches AS b ON CAST(m.branch_id AS UNSIGNED) = b.branch_id;

-- STEP 8: RUN BUSINESS INTELLIGENCE QUERIES
-- Q4.1: Branch Revenue
SELECT b.branch_name, COALESCE(SUM(CASE WHEN t.transaction_type = 'Credit' THEN t.amount_usd ELSE 0 END), 0) AS total_credits_usd, COALESCE(SUM(CASE WHEN t.transaction_type = 'Debit' THEN t.amount_usd ELSE 0 END), 0) AS total_debits_usd, COALESCE(SUM(CASE WHEN t.transaction_type = 'Credit' THEN t.amount_usd WHEN t.transaction_type = 'Debit' THEN -t.amount_usd ELSE 0 END), 0) AS net_position_usd, COUNT(t.transaction_id) AS transaction_count, ROUND(AVG(t.amount_usd), 2) AS avg_transaction_usd FROM dim_branches b LEFT JOIN fct_transactions t ON b.branch_id = t.branch_id GROUP BY b.branch_id, b.branch_name ORDER BY net_position_usd DESC;

-- Q4.2: Loan Risk
SELECT loan_status, COUNT(*) AS total_loans, ROUND(SUM(loan_amount_usd), 2) AS total_disbursed_usd, ROUND(SUM(outstanding_balance), 2) AS total_outstanding_usd FROM fct_loans GROUP BY loan_status ORDER BY total_disbursed_usd DESC;

-- Q4.3: Customer Segmentation
WITH customer_volume AS (SELECT c.customer_id, c.full_name, COUNT(t.transaction_id) AS transaction_count, COALESCE(SUM(t.amount_usd), 0) AS total_usd_volume FROM dim_customers c LEFT JOIN fct_transactions t ON c.customer_id = t.customer_id GROUP BY c.customer_id, c.full_name), ranked_customers AS (SELECT *, PERCENT_RANK() OVER (ORDER BY total_usd_volume) AS percentile_rank FROM customer_volume) SELECT customer_id, full_name, transaction_count, ROUND(total_usd_volume, 2) AS total_usd_volume, CASE WHEN percentile_rank >= 0.95 THEN 'Whale' WHEN percentile_rank >= 0.75 THEN 'Premium' WHEN percentile_rank >= 0.25 THEN 'Standard' ELSE 'Entry-Level' END AS customer_segment FROM ranked_customers ORDER BY total_usd_volume DESC LIMIT 20;

-- Q4.4: Channel Performance
SELECT channel, COUNT(*) AS transaction_count, ROUND(SUM(amount_usd), 2) AS total_usd_volume, ROUND(AVG(amount_usd), 2) AS average_transaction_usd FROM fct_transactions GROUP BY channel ORDER BY total_usd_volume DESC;

-- Q4.5: NPL Ratio by Branch
SELECT b.branch_name, ROUND(SUM(l.loan_amount_usd), 2) AS total_disbursed_usd, ROUND(SUM(CASE WHEN l.loan_status IN ('Defaulted', 'Written Off') THEN l.loan_amount_usd ELSE 0 END), 2) AS npl_amount_usd, ROUND(SUM(CASE WHEN l.loan_status IN ('Defaulted', 'Written Off') THEN l.loan_amount_usd ELSE 0 END) / NULLIF(SUM(l.loan_amount_usd), 0) * 100, 2) AS npl_ratio_pct FROM dim_branches b JOIN fct_loans l ON b.branch_id = l.branch_id GROUP BY b.branch_id, b.branch_name ORDER BY npl_ratio_pct DESC;

-- Q4.6: Dormant Customers
SELECT c.full_name, c.country, c.account_type, c.kyc_status, c.account_open_date, DATEDIFF(CURDATE(), c.account_open_date) AS days_since_account_opening FROM dim_customers c LEFT JOIN fct_transactions t ON c.customer_id = t.customer_id WHERE t.customer_id IS NULL ORDER BY days_since_account_opening DESC LIMIT 20;

-- Q4.7: ATM Downtime
SELECT b.branch_name, DATE_FORMAT(m.report_date, '%Y-%m') AS report_month, ROUND(AVG(m.total_transactions), 2) AS avg_monthly_transactions, ROUND(AVG(m.atm_downtime_mins), 2) AS avg_atm_downtime_minutes, CASE WHEN AVG(m.atm_downtime_mins) > 60 THEN 'Critical Downtime' ELSE 'Normal Downtime' END AS downtime_status FROM fct_branch_daily_metrics m JOIN dim_branches b ON m.branch_id = b.branch_id GROUP BY b.branch_id, b.branch_name, DATE_FORMAT(m.report_date, '%Y-%m') ORDER BY report_month, b.branch_name;

-- Q4.8: FX Exposure
SELECT CONCAT(currency_code, '/USD') AS currency_pair, currency_code, COUNT(*) AS transaction_count, ROUND(SUM(amount_local), 2) AS total_local_currency_volume, ROUND(SUM(amount_usd), 2) AS total_usd_volume FROM fct_transactions GROUP BY currency_code ORDER BY total_usd_volume DESC;

-- STEP 9: FINAL VALIDATION
SELECT '✅ MASTER SCRIPT COMPLETE!' AS Status;
SELECT 'Customers' AS Table_Name, COUNT(*) AS Row_Count FROM dim_customers
UNION ALL SELECT 'Transactions', COUNT(*) FROM fct_transactions
UNION ALL SELECT 'Loans', COUNT(*) FROM fct_loans
UNION ALL SELECT 'Branch Metrics', COUNT(*) FROM fct_branch_daily_metrics;