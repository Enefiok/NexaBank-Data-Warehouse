-- CRITICAL: Enable file loading to prevent Error 2068
SET GLOBAL local_infile = 1;

-- ==========================================
-- NEXABANK MASTER PROJECT SCRIPT
-- ==========================================

DROP DATABASE IF EXISTS nexabank_dw;

CREATE DATABASE nexabank_dw
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

USE nexabank_dw;

-- ==========================================
-- 1. CREATE STAGING TABLES
-- ==========================================

CREATE TABLE stg_transactions (
    transaction_id VARCHAR(50),
    customer_id VARCHAR(50),
    branch_id VARCHAR(50),
    raw_transaction_type VARCHAR(100),
    raw_channel VARCHAR(100),
    raw_transaction_date VARCHAR(50),
    raw_transaction_time VARCHAR(50),
    amount_local VARCHAR(100),
    local_currency VARCHAR(10),
    amount_usd VARCHAR(100),
    raw_description VARCHAR(255),
    reference_code VARCHAR(100),
    balance_after_local VARCHAR(100)
);

CREATE TABLE stg_loans (
    loan_id VARCHAR(50),
    customer_id VARCHAR(50),
    branch_id VARCHAR(50),
    raw_loan_status VARCHAR(100),
    loan_purpose VARCHAR(150),
    local_currency VARCHAR(10),
    loan_amount_local VARCHAR(100),
    loan_amount_usd VARCHAR(100),
    interest_rate_pct VARCHAR(100),
    tenure_months VARCHAR(50),
    amount_repaid_local VARCHAR(100),
    outstanding_balance VARCHAR(100),
    raw_disbursement_date VARCHAR(50),
    raw_maturity_date VARCHAR(50)
);

CREATE TABLE stg_customers (
    customer_id VARCHAR(50),
    account_number VARCHAR(100),
    raw_first_name VARCHAR(100),
    raw_last_name VARCHAR(100),
    raw_email VARCHAR(150),
    raw_phone VARCHAR(100),
    raw_country VARCHAR(100),
    raw_city VARCHAR(150),
    account_type VARCHAR(100),
    raw_kyc_status VARCHAR(100),
    bvn_nin VARCHAR(100),
    annual_income_local VARCHAR(100),
    local_currency VARCHAR(10),
    raw_dob VARCHAR(50),
    raw_account_open_date VARCHAR(50)
);

CREATE TABLE stg_branch_metrics (
    branch_id VARCHAR(50),
    raw_branch_name VARCHAR(150),
    raw_country VARCHAR(100),
    raw_local_currency VARCHAR(10),
    report_date VARCHAR(50),
    total_transactions VARCHAR(50),
    total_debit_local VARCHAR(100),
    total_credit_local VARCHAR(100),
    new_accounts_opened VARCHAR(50),
    loan_applications VARCHAR(50),
    atm_downtime_minutes VARCHAR(50),
    raw_staff_count VARCHAR(50),
    net_inflow_outflow VARCHAR(100)
);

CREATE TABLE stg_fx_rates (
    currency_code VARCHAR(10),
    currency_name VARCHAR(100),
    rate_to_usd VARCHAR(100),
    buy_rate_local VARCHAR(100),
    sell_rate_local VARCHAR(100),
    effective_date VARCHAR(50),
    source VARCHAR(150)
);

-- ==========================================
-- 2. CREATE PRODUCTION TABLES
-- ==========================================

CREATE TABLE dim_fx_rates (
    currency_code CHAR(3) PRIMARY KEY,
    currency_name VARCHAR(100) NOT NULL,
    rate_to_usd DECIMAL(18,6) NOT NULL,
    buy_rate_local DECIMAL(18,6) NOT NULL,
    sell_rate_local DECIMAL(18,6) NOT NULL,
    effective_date DATE NOT NULL
);

CREATE TABLE dim_branches (
    branch_id INT PRIMARY KEY,
    branch_name VARCHAR(150) NOT NULL,
    country VARCHAR(100) NOT NULL,
    local_currency CHAR(3) NOT NULL
);

CREATE TABLE dim_customers (
    customer_id INT PRIMARY KEY,
    account_number VARCHAR(50) UNIQUE NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    full_name VARCHAR(210) NOT NULL,
    email VARCHAR(150),
    phone_clean VARCHAR(50),
    country VARCHAR(100),
    city VARCHAR(150),
    account_type VARCHAR(100),
    kyc_status VARCHAR(50),
    annual_income_usd DECIMAL(18,2),
    account_open_date DATE
);

CREATE TABLE fct_transactions (
    transaction_id INT PRIMARY KEY,
    customer_id INT NOT NULL,
    branch_id INT NOT NULL,
    currency_code CHAR(3) NOT NULL,
    transaction_type VARCHAR(50) NOT NULL,
    channel VARCHAR(100) NOT NULL,
    transaction_date DATE NOT NULL,
    transaction_time TIME,
    amount_local DECIMAL(18,2) NOT NULL,
    amount_usd DECIMAL(18,2) NOT NULL,
    description VARCHAR(255),
    reference_code VARCHAR(100),
    balance_after_local DECIMAL(18,2),
    balance_after_usd DECIMAL(18,2),
    FOREIGN KEY (customer_id) REFERENCES dim_customers(customer_id),
    FOREIGN KEY (branch_id) REFERENCES dim_branches(branch_id),
    FOREIGN KEY (currency_code) REFERENCES dim_fx_rates(currency_code)
);

CREATE TABLE fct_loans (
    loan_id INT PRIMARY KEY,
    customer_id INT NOT NULL,
    branch_id INT NOT NULL,
    currency_code CHAR(3) NOT NULL,
    loan_purpose VARCHAR(150),
    loan_status VARCHAR(50),
    loan_amount_local DECIMAL(18,2),
    loan_amount_usd DECIMAL(18,2),
    interest_rate_pct DECIMAL(10,2),
    tenure_months INT,
    amount_repaid_local DECIMAL(18,2),
    outstanding_balance DECIMAL(18,2),
    disbursement_date DATE,
    maturity_date DATE,
    FOREIGN KEY (customer_id) REFERENCES dim_customers(customer_id),
    FOREIGN KEY (branch_id) REFERENCES dim_branches(branch_id),
    FOREIGN KEY (currency_code) REFERENCES dim_fx_rates(currency_code)
);

CREATE TABLE fct_branch_daily_metrics (
    metric_id INT AUTO_INCREMENT PRIMARY KEY,
    branch_id INT NOT NULL,
    report_date DATE NOT NULL,
    total_transactions INT DEFAULT 0,
    total_debit_local DECIMAL(18,2) DEFAULT 0,
    total_credit_local DECIMAL(18,2) DEFAULT 0,
    new_accounts_opened INT DEFAULT 0,
    loan_applications INT DEFAULT 0,
    atm_downtime_mins INT DEFAULT 0,
    staff_count INT DEFAULT 0,
    net_inflow_outflow DECIMAL(18,2) DEFAULT 0,
    FOREIGN KEY (branch_id) REFERENCES dim_branches(branch_id)
);

-- ==========================================
-- 3. LOAD RAW DATA INTO STAGING TABLES
-- ==========================================

LOAD DATA LOCAL INFILE 'C:/Users/user/Downloads/nexabank_raw_data/nexabank_raw_data/raw_source1_core_transactions.csv'
INTO TABLE stg_transactions
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

LOAD DATA LOCAL INFILE 'C:/Users/user/Downloads/nexabank_raw_data/nexabank_raw_data/raw_source3_customer_kyc.tsv'
INTO TABLE stg_customers
FIELDS TERMINATED BY '\t'
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

LOAD DATA LOCAL INFILE 'C:/Users/user/Downloads/nexabank_raw_data/nexabank_raw_data/raw_source2_loan_portfolio.csv'
INTO TABLE stg_loans
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

LOAD DATA LOCAL INFILE 'C:/Users/user/Downloads/nexabank_raw_data/nexabank_raw_data/raw_source4_branch_performance.csv'
INTO TABLE stg_branch_metrics
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

LOAD DATA LOCAL INFILE 'C:/Users/user/Downloads/nexabank_raw_data/nexabank_raw_data/raw_source5_fx_reference_rates.csv'
INTO TABLE stg_fx_rates
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- ==========================================
-- 4. ETL: CLEAN AND LOAD INTO PRODUCTION
-- ==========================================

-- Load FX Rates
INSERT INTO dim_fx_rates (currency_code, currency_name, rate_to_usd, buy_rate_local, sell_rate_local, effective_date)
SELECT
    UPPER(TRIM(currency_code)),
    TRIM(currency_name),
    CAST(rate_to_usd AS DECIMAL(18,6)),
    CAST(buy_rate_local AS DECIMAL(18,6)),
    CAST(sell_rate_local AS DECIMAL(18,6)),
    STR_TO_DATE(TRIM(effective_date), '%Y-%m-%d')
FROM stg_fx_rates;

-- Load Branches
INSERT INTO dim_branches (branch_id, branch_name, country, local_currency)
SELECT
    branch_id,
    CASE branch_id
        WHEN 101 THEN 'Victoria Island Lagos'
        WHEN 102 THEN 'Ikeja GRA Lagos'
        WHEN 103 THEN 'Abuja Central'
        WHEN 104 THEN 'Port Harcourt City'
        WHEN 105 THEN 'Kano Commercial District'
        WHEN 106 THEN 'Accra Downtown'
        WHEN 107 THEN 'Kumasi Branch'
        WHEN 108 THEN 'Nairobi CBD'
        WHEN 109 THEN 'Mombasa Coastal'
        WHEN 110 THEN 'Johannesburg Sandton'
        WHEN 111 THEN 'Cape Town City Centre'
        WHEN 112 THEN 'London Canary Wharf'
        WHEN 113 THEN 'Frankfurt International'
        WHEN 114 THEN 'Dubai DIFC'
        WHEN 115 THEN 'New York Midtown'
    END,
    CONCAT(UPPER(LEFT(TRIM(raw_country), 1)), LOWER(SUBSTRING(TRIM(raw_country), 2))),
    UPPER(TRIM(raw_local_currency))
FROM stg_branch_metrics
GROUP BY branch_id, raw_country, raw_local_currency;

-- Load Customers
INSERT INTO dim_customers (customer_id, account_number, first_name, last_name, full_name, email, phone_clean, country, city, account_type, kyc_status, annual_income_usd, account_open_date)
SELECT
    CAST(c.customer_id AS UNSIGNED),
    TRIM(c.account_number),
    CONCAT(UPPER(LEFT(LOWER(TRIM(c.raw_first_name)), 1)), SUBSTRING(LOWER(TRIM(c.raw_first_name)), 2)),
    CONCAT(UPPER(LEFT(LOWER(TRIM(c.raw_last_name)), 1)), SUBSTRING(LOWER(TRIM(c.raw_last_name)), 2)),
    CONCAT_WS(' ', CONCAT(UPPER(LEFT(LOWER(TRIM(c.raw_first_name)), 1)), SUBSTRING(LOWER(TRIM(c.raw_first_name)), 2)), CONCAT(UPPER(LEFT(LOWER(TRIM(c.raw_last_name)), 1)), SUBSTRING(LOWER(TRIM(c.raw_last_name)), 2))),
    NULLIF(TRIM(c.raw_email), ''),
    NULLIF(REGEXP_REPLACE(TRIM(c.raw_phone), '[^0-9+]', ''), ''),
    TRIM(c.raw_country),
    TRIM(c.raw_city),
    TRIM(c.account_type),
    CASE UPPER(TRIM(c.raw_kyc_status))
        WHEN 'VERIFIED' THEN 'Verified'
        WHEN 'FAILED' THEN 'Failed'
        WHEN 'UNDER REVIEW' THEN 'Under Review'
        WHEN 'EXPIRED' THEN 'Expired'
        WHEN 'PENDING' THEN 'Pending'
        ELSE 'Unknown'
    END,
    CASE WHEN TRIM(c.annual_income_local) REGEXP '^-?[0-9]+([.][0-9]+)?$' AND TRIM(fx.rate_to_usd) REGEXP '^-?[0-9]+([.][0-9]+)?$' THEN CAST(TRIM(c.annual_income_local) AS DECIMAL(18,2)) * CAST(TRIM(fx.rate_to_usd) AS DECIMAL(18,6)) ELSE NULL END,
    CASE
        WHEN TRIM(c.raw_account_open_date) REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN STR_TO_DATE(TRIM(c.raw_account_open_date), '%Y-%m-%d')
        WHEN TRIM(c.raw_account_open_date) REGEXP '^[0-9]{2}-[A-Za-z]{3}-[0-9]{4}$' THEN STR_TO_DATE(TRIM(c.raw_account_open_date), '%d-%b-%Y')
        WHEN TRIM(c.raw_account_open_date) REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$' THEN CASE WHEN CAST(SUBSTRING_INDEX(TRIM(c.raw_account_open_date), '/', 1) AS UNSIGNED) > 12 THEN STR_TO_DATE(TRIM(c.raw_account_open_date), '%d/%m/%Y') ELSE STR_TO_DATE(TRIM(c.raw_account_open_date), '%m/%d/%Y') END
        ELSE NULL
    END
FROM stg_customers AS c
JOIN dim_fx_rates AS fx ON UPPER(TRIM(c.local_currency)) = UPPER(TRIM(fx.currency_code));

-- Load Transactions
INSERT INTO fct_transactions (transaction_id, customer_id, branch_id, currency_code, transaction_type, channel, transaction_date, transaction_time, amount_local, amount_usd, description, reference_code, balance_after_local, balance_after_usd)
SELECT
    CAST(t.transaction_id AS UNSIGNED),
    CAST(t.customer_id AS UNSIGNED),
    CAST(t.branch_id AS UNSIGNED),
    UPPER(TRIM(t.local_currency)),
    CONCAT(UPPER(LEFT(LOWER(TRIM(t.raw_transaction_type)), 1)), SUBSTRING(LOWER(TRIM(t.raw_transaction_type)), 2)),
    CASE UPPER(TRIM(t.raw_channel))
        WHEN '' THEN 'Unknown' WHEN 'A.T.M' THEN 'ATM' WHEN 'ATM' THEN 'ATM' WHEN 'POS' THEN 'POS Terminal' WHEN 'POS TERMINAL' THEN 'POS Terminal' WHEN '*966#' THEN 'USSD'
        ELSE CONCAT(UPPER(LEFT(LOWER(TRIM(t.raw_channel)), 1)), SUBSTRING(LOWER(TRIM(t.raw_channel)), 2))
    END,
    CASE
        WHEN TRIM(t.raw_transaction_date) REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN STR_TO_DATE(TRIM(t.raw_transaction_date), '%Y-%m-%d')
        WHEN TRIM(t.raw_transaction_date) REGEXP '^[0-9]{2}-[A-Za-z]{3}-[0-9]{4}$' THEN STR_TO_DATE(TRIM(t.raw_transaction_date), '%d-%b-%Y')
        WHEN TRIM(t.raw_transaction_date) REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$' THEN CASE WHEN CAST(SUBSTRING_INDEX(TRIM(t.raw_transaction_date), '/', 1) AS UNSIGNED) > 12 THEN STR_TO_DATE(TRIM(t.raw_transaction_date), '%d/%m/%Y') ELSE STR_TO_DATE(TRIM(t.raw_transaction_date), '%m/%d/%Y') END
        ELSE NULL
    END,
    STR_TO_DATE(TRIM(t.raw_transaction_time), '%H:%i:%s'),
    CAST(t.amount_local AS DECIMAL(18,2)),
    CAST(t.amount_local AS DECIMAL(18,2)) * fx.rate_to_usd,
    TRIM(t.raw_description),
    TRIM(t.reference_code),
    CAST(t.balance_after_local AS DECIMAL(18,2)),
    CAST(t.balance_after_local AS DECIMAL(18,2)) * fx.rate_to_usd
FROM stg_transactions t
JOIN dim_fx_rates fx ON UPPER(TRIM(t.local_currency)) = fx.currency_code;

-- Load Loans
INSERT INTO fct_loans (loan_id, customer_id, branch_id, currency_code, loan_purpose, loan_status, loan_amount_local, loan_amount_usd, interest_rate_pct, tenure_months, amount_repaid_local, outstanding_balance, disbursement_date, maturity_date)
SELECT
    CAST(l.loan_id AS UNSIGNED),
    CAST(l.customer_id AS UNSIGNED),
    CAST(l.branch_id AS UNSIGNED),
    UPPER(TRIM(l.local_currency)),
    TRIM(l.loan_purpose),
    CASE UPPER(TRIM(l.raw_loan_status))
        WHEN 'ACTIVE' THEN 'Active' WHEN 'FULLY PAID' THEN 'Fully Paid' WHEN 'DEFAULTED' THEN 'Defaulted' WHEN 'WRITTEN OFF' THEN 'Written Off' WHEN 'RESTRUCTURED' THEN 'Restructured' WHEN 'APPROVED' THEN 'Approved' WHEN 'PENDING REVIEW' THEN 'Pending Review' ELSE 'Unknown'
    END,
    CAST(l.loan_amount_local AS DECIMAL(18,2)),
    CAST(l.loan_amount_local AS DECIMAL(18,2)) * fx.rate_to_usd,
    CAST(l.interest_rate_pct AS DECIMAL(10,2)),
    CAST(l.tenure_months AS UNSIGNED),
    CAST(l.amount_repaid_local AS DECIMAL(18,2)),
    CAST(l.outstanding_balance AS DECIMAL(18,2)) * fx.rate_to_usd,
    CASE
        WHEN TRIM(l.raw_disbursement_date) REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN STR_TO_DATE(TRIM(l.raw_disbursement_date), '%Y-%m-%d')
        WHEN TRIM(l.raw_disbursement_date) REGEXP '^[0-9]{2}-[A-Za-z]{3}-[0-9]{4}$' THEN STR_TO_DATE(TRIM(l.raw_disbursement_date), '%d-%b-%Y')
        WHEN TRIM(l.raw_disbursement_date) REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$' THEN CASE WHEN CAST(SUBSTRING_INDEX(TRIM(l.raw_disbursement_date), '/', 1) AS UNSIGNED) > 12 THEN STR_TO_DATE(TRIM(l.raw_disbursement_date), '%d/%m/%Y') ELSE STR_TO_DATE(TRIM(l.raw_disbursement_date), '%m/%d/%Y') END
        ELSE NULL
    END,
    CASE
        WHEN TRIM(l.raw_maturity_date) REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN STR_TO_DATE(TRIM(l.raw_maturity_date), '%Y-%m-%d')
        WHEN TRIM(l.raw_maturity_date) REGEXP '^[0-9]{2}-[A-Za-z]{3}-[0-9]{4}$' THEN STR_TO_DATE(TRIM(l.raw_maturity_date), '%d-%b-%Y')
        WHEN TRIM(l.raw_maturity_date) REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$' THEN CASE WHEN CAST(SUBSTRING_INDEX(TRIM(l.raw_maturity_date), '/', 1) AS UNSIGNED) > 12 THEN STR_TO_DATE(TRIM(l.raw_maturity_date), '%d/%m/%Y') ELSE STR_TO_DATE(TRIM(l.raw_maturity_date), '%m/%d/%Y') END
        ELSE NULL
    END
FROM stg_loans l
JOIN dim_fx_rates fx ON UPPER(TRIM(l.local_currency)) = fx.currency_code;

-- Load Branch Daily Metrics
INSERT INTO fct_branch_daily_metrics (branch_id, report_date, total_transactions, total_debit_local, total_credit_local, new_accounts_opened, loan_applications, atm_downtime_mins, staff_count, net_inflow_outflow)
SELECT
    b.branch_id,
    CASE
        WHEN TRIM(m.report_date) REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN STR_TO_DATE(TRIM(m.report_date), '%Y-%m-%d')
        WHEN TRIM(m.report_date) REGEXP '^[0-9]{2}-[A-Za-z]{3}-[0-9]{4}$' THEN STR_TO_DATE(TRIM(m.report_date), '%d-%b-%Y')
        WHEN TRIM(m.report_date) REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$' THEN CASE WHEN CAST(SUBSTRING_INDEX(TRIM(m.report_date), '/', 1) AS UNSIGNED) > 12 THEN STR_TO_DATE(TRIM(m.report_date), '%d/%m/%Y') ELSE STR_TO_DATE(TRIM(m.report_date), '%m/%d/%Y') END
    END,
    COALESCE(CAST(m.total_transactions AS UNSIGNED), 0),
    COALESCE(CAST(m.total_debit_local AS DECIMAL(18,2)), 0),
    COALESCE(CAST(m.total_credit_local AS DECIMAL(18,2)), 0),
    COALESCE(CAST(m.new_accounts_opened AS UNSIGNED), 0),
    COALESCE(CAST(m.loan_applications AS UNSIGNED), 0),
    COALESCE(CAST(m.atm_downtime_minutes AS UNSIGNED), 0),
    COALESCE(CAST(m.raw_staff_count AS UNSIGNED), 0),
    COALESCE(CAST(m.net_inflow_outflow AS DECIMAL(18,2)), 0)
FROM stg_branch_metrics AS m
JOIN dim_branches AS b ON UPPER(TRIM(m.raw_branch_name)) = UPPER(TRIM(b.branch_name));

-- ==========================================
-- 5. BUSINESS INTELLIGENCE QUERIES
-- ==========================================

-- Q4.1 Branch Revenue Intelligence
SELECT b.branch_name, COALESCE(SUM(CASE WHEN t.transaction_type = 'Credit' THEN t.amount_usd ELSE 0 END), 0) AS total_credits_usd, COALESCE(SUM(CASE WHEN t.transaction_type = 'Debit' THEN t.amount_usd ELSE 0 END), 0) AS total_debits_usd, COALESCE(SUM(CASE WHEN t.transaction_type = 'Credit' THEN t.amount_usd WHEN t.transaction_type = 'Debit' THEN -t.amount_usd ELSE 0 END), 0) AS net_position_usd, COUNT(t.transaction_id) AS transaction_count, ROUND(AVG(t.amount_usd), 2) AS avg_transaction_usd FROM dim_branches b LEFT JOIN fct_transactions t ON b.branch_id = t.branch_id GROUP BY b.branch_id, b.branch_name ORDER BY net_position_usd DESC;

-- Q4.2 Loan Portfolio Risk Dashboard
SELECT loan_status, COUNT(*) AS total_loans, ROUND(SUM(loan_amount_usd), 2) AS total_disbursed_usd, ROUND(SUM(outstanding_balance), 2) AS total_outstanding_usd, ROUND(SUM(amount_repaid_local * (SELECT rate_to_usd FROM dim_fx_rates fx WHERE fx.currency_code = fct_loans.currency_code)), 2) AS total_repaid_usd, ROUND(SUM(amount_repaid_local * (SELECT rate_to_usd FROM dim_fx_rates fx WHERE fx.currency_code = fct_loans.currency_code)) / NULLIF(SUM(loan_amount_usd), 0) * 100, 2) AS recovery_rate_pct FROM fct_loans GROUP BY loan_status ORDER BY total_disbursed_usd DESC;

-- Q4.3 Customer Segmentation
WITH customer_volume AS (SELECT c.customer_id, c.full_name, COUNT(t.transaction_id) AS transaction_count, COALESCE(SUM(t.amount_usd), 0) AS total_usd_volume, COALESCE(AVG(t.amount_usd), 0) AS average_transaction_usd FROM dim_customers c LEFT JOIN fct_transactions t ON c.customer_id = t.customer_id GROUP BY c.customer_id, c.full_name), ranked_customers AS (SELECT *, PERCENT_RANK() OVER (ORDER BY total_usd_volume) AS percentile_rank FROM customer_volume) SELECT customer_id, full_name, transaction_count, ROUND(total_usd_volume, 2) AS total_usd_volume, ROUND(average_transaction_usd, 2) AS average_transaction_usd, CASE WHEN percentile_rank >= 0.95 THEN 'Whale' WHEN percentile_rank >= 0.75 THEN 'Premium' WHEN percentile_rank >= 0.25 THEN 'Standard' ELSE 'Entry-Level' END AS customer_segment FROM ranked_customers;

-- Q4.4 Channel Performance
WITH channel_summary AS (SELECT channel, COUNT(*) AS transaction_count, SUM(amount_usd) AS total_usd_volume, AVG(amount_usd) AS average_transaction_usd FROM fct_transactions GROUP BY channel) SELECT channel, transaction_count, ROUND(total_usd_volume, 2) AS total_usd_volume, ROUND(average_transaction_usd, 2) AS average_transaction_usd, ROUND(total_usd_volume / SUM(total_usd_volume) OVER () * 100, 2) AS volume_share_pct FROM channel_summary ORDER BY total_usd_volume DESC;

-- Q4.5 NPL Ratio by Branch
SELECT b.branch_name, ROUND(SUM(l.loan_amount_usd), 2) AS total_disbursed_usd, ROUND(SUM(CASE WHEN l.loan_status IN ('Defaulted', 'Written Off') THEN l.loan_amount_usd ELSE 0 END), 2) AS npl_amount_usd, ROUND(SUM(CASE WHEN l.loan_status IN ('Defaulted', 'Written Off') THEN l.loan_amount_usd ELSE 0 END) / NULLIF(SUM(l.loan_amount_usd), 0) * 100, 2) AS npl_ratio_pct, CASE WHEN SUM(CASE WHEN l.loan_status IN ('Defaulted', 'Written Off') THEN l.loan_amount_usd ELSE 0 END) / NULLIF(SUM(l.loan_amount_usd), 0) * 100 > 15 THEN 'High Risk' WHEN SUM(CASE WHEN l.loan_status IN ('Defaulted', 'Written Off') THEN l.loan_amount_usd ELSE 0 END) / NULLIF(SUM(l.loan_amount_usd), 0) * 100 >= 8 THEN 'Watch' ELSE 'Healthy' END AS risk_flag FROM dim_branches b JOIN fct_loans l ON b.branch_id = l.branch_id GROUP BY b.branch_id, b.branch_name ORDER BY npl_ratio_pct DESC;

-- Q4.6 Dormant Customers
SELECT c.full_name, c.country, c.account_type, c.kyc_status, c.account_open_date, DATEDIFF(CURDATE(), c.account_open_date) AS days_since_account_opening FROM dim_customers c LEFT JOIN fct_transactions t ON c.customer_id = t.customer_id WHERE t.customer_id IS NULL ORDER BY days_since_account_opening DESC;

-- Q4.7 ATM Downtime Impact
SELECT b.branch_name, DATE_FORMAT(m.report_date, '%Y-%m') AS report_month, ROUND(AVG(m.total_transactions), 2) AS avg_monthly_transactions, ROUND(AVG(m.atm_downtime_mins), 2) AS avg_atm_downtime_minutes, CASE WHEN AVG(m.atm_downtime_mins) > 60 THEN 'Critical Downtime' ELSE 'Normal Downtime' END AS downtime_status FROM fct_branch_daily_metrics m JOIN dim_branches b ON m.branch_id = b.branch_id GROUP BY b.branch_id, b.branch_name, DATE_FORMAT(m.report_date, '%Y-%m') ORDER BY report_month, b.branch_name;

-- Q4.8 FX Currency Exposure
SELECT CONCAT(currency_code, '/USD') AS currency_pair, currency_code, COUNT(*) AS transaction_count, ROUND(SUM(amount_local), 2) AS total_local_currency_volume, ROUND(SUM(amount_usd), 2) AS total_usd_volume, ROUND(SUM(amount_usd) / SUM(SUM(amount_usd)) OVER () * 100, 2) AS global_volume_share_pct FROM fct_transactions GROUP BY currency_code ORDER BY total_usd_volume DESC;

-- ==========================================
-- 6. CREATE VIEWS
-- ==========================================

CREATE OR REPLACE VIEW vw_branch_monthly_kpi AS
SELECT b.branch_name, DATE_FORMAT(m.report_date, '%Y-%m') AS report_month, SUM(m.total_transactions) AS total_transactions, ROUND(SUM(m.net_inflow_outflow * fx.rate_to_usd), 2) AS net_flow_usd, SUM(m.new_accounts_opened) AS new_accounts, ROUND(AVG(m.atm_downtime_mins), 2) AS avg_atm_downtime, CASE WHEN AVG(m.atm_downtime_mins) > 60 THEN 'Critical' WHEN AVG(m.atm_downtime_mins) >= 30 THEN 'Watch' ELSE 'Healthy' END AS atm_health_rating FROM fct_branch_daily_metrics m JOIN dim_branches b ON m.branch_id = b.branch_id JOIN dim_fx_rates fx ON b.local_currency = fx.currency_code GROUP BY b.branch_id, b.branch_name, DATE_FORMAT(m.report_date, '%Y-%m');

CREATE OR REPLACE VIEW vw_loan_risk_summary AS
SELECT l.loan_id, c.full_name, b.branch_name, l.loan_purpose, l.loan_status, l.outstanding_balance, CASE WHEN l.loan_status IN ('Defaulted', 'Written Off') THEN DATEDIFF(CURDATE(), l.maturity_date) ELSE 0 END AS days_overdue, CASE WHEN l.loan_status = 'Written Off' THEN 'Critical' WHEN l.loan_status = 'Defaulted' THEN 'High Risk' WHEN l.loan_status = 'Restructured' THEN 'Medium Risk' WHEN l.loan_status = 'Active' THEN 'Watch' ELSE 'Low Risk' END AS risk_tier FROM fct_loans l JOIN dim_customers c ON l.customer_id = c.customer_id JOIN dim_branches b ON l.branch_id = b.branch_id;

CREATE OR REPLACE VIEW vw_dormant_accounts_watchlist AS
SELECT c.customer_id, c.full_name, c.account_type, c.kyc_status, DATEDIFF(CURDATE(), c.account_open_date) AS days_since_account_opening, CASE WHEN c.annual_income_usd >= 100000 THEN 'High Income' WHEN c.annual_income_usd >= 50000 THEN 'Middle Income' ELSE 'Standard Income' END AS annual_income_tier FROM dim_customers c LEFT JOIN fct_transactions t ON c.customer_id = t.customer_id WHERE t.customer_id IS NULL;

-- ==========================================
-- 7. VALIDATION CHECKS
-- ==========================================
SELECT 'dim_customers' AS table_name, COUNT(*) AS row_count FROM dim_customers
UNION ALL SELECT 'fct_transactions', COUNT(*) FROM fct_transactions
UNION ALL SELECT 'fct_loans', COUNT(*) FROM fct_loans
UNION ALL SELECT 'dim_branches', COUNT(*) FROM dim_branches
UNION ALL SELECT 'dim_fx_rates', COUNT(*) FROM dim_fx_rates
UNION ALL SELECT 'fct_branch_daily_metrics', COUNT(*) FROM fct_branch_daily_metrics;        