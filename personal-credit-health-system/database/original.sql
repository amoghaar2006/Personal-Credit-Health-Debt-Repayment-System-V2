-- ============================================================
-- Personal Credit Health and Debt Repayment Planning System
-- Source: DBMS project report, pages 13-27
-- MySQL 8.0+
--
-- IMPORTANT SOURCE LIMITATIONS:
-- 1. The report screenshots show pre-existing rows from a larger
--    dataset that is NOT included in the PDF. Therefore the aggregate
--    query and the first 10-row outputs cannot be reproduced exactly
--    from this file alone.
-- 2. The report has inconsistencies between CREATE TABLE and later
--    INSERT/SELECT screenshots (noted inline). This script resolves
--    those inconsistencies so it executes on a clean MySQL database.
-- 3. Run this file in a fresh MySQL environment. It does not DROP
--    existing databases/tables or delete existing data.
-- ============================================================

CREATE DATABASE IF NOT EXISTS credit_health_db;
USE credit_health_db;

-- ============================================================
-- 5. DDL STATEMENTS (report pages 13-18)
-- ============================================================

CREATE TABLE IF NOT EXISTS `user` (
    user_id VARCHAR(10) NOT NULL,
    PRIMARY KEY (user_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS financial_profile (
    profile_id INT NOT NULL AUTO_INCREMENT,
    user_id VARCHAR(10) NOT NULL,
    monthly_income_usd DECIMAL(12,2) NOT NULL,
    monthly_expenses_usd DECIMAL(12,2) NOT NULL,
    savings_usd DECIMAL(14,2) NOT NULL,
    has_loan VARCHAR(3) NOT NULL,
    debt_to_income_ratio DECIMAL(6,2) NOT NULL,
    credit_score INT NOT NULL,
    record_date DATE NOT NULL,
    PRIMARY KEY (profile_id),
    CONSTRAINT fk_financial_profile_user
        FOREIGN KEY (user_id) REFERENCES `user` (user_id),
    CONSTRAINT chk_profile_income CHECK (monthly_income_usd >= 0),
    CONSTRAINT chk_profile_expenses CHECK (monthly_expenses_usd >= 0),
    CONSTRAINT chk_profile_savings CHECK (savings_usd >= 0),
    CONSTRAINT chk_profile_has_loan CHECK (has_loan IN ('Yes','No')),
    CONSTRAINT chk_profile_credit_score CHECK (credit_score BETWEEN 300 AND 850)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS loan (
    loan_id VARCHAR(10) NOT NULL,
    user_id VARCHAR(10) NOT NULL,
    loan_type VARCHAR(20) NOT NULL,
    loan_amount_usd DECIMAL(14,2) NOT NULL,
    loan_term_months INT NOT NULL,
    monthly_emi_usd DECIMAL(12,2) NOT NULL,
    loan_interest_rate_pct DECIMAL(6,2) NOT NULL,
    PRIMARY KEY (loan_id),
    CONSTRAINT fk_loan_user
        FOREIGN KEY (user_id) REFERENCES `user` (user_id),
    CONSTRAINT chk_loan_amount CHECK (loan_amount_usd > 0),
    CONSTRAINT chk_loan_term CHECK (loan_term_months > 0),
    CONSTRAINT chk_loan_emi CHECK (monthly_emi_usd >= 0),
    CONSTRAINT chk_loan_interest CHECK (loan_interest_rate_pct >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS repayment (
    payment_id VARCHAR(20) NOT NULL,
    loan_id VARCHAR(10) NOT NULL,
    installment_number INT NOT NULL,
    due_date DATE NOT NULL,
    payment_date DATE NULL,
    amount_due_usd DECIMAL(12,2) NOT NULL,
    amount_paid_usd DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    payment_status VARCHAR(20) NOT NULL,
    days_late INT NOT NULL DEFAULT 0,
    remaining_balance_usd DECIMAL(14,2) NOT NULL,
    PRIMARY KEY (payment_id),
    CONSTRAINT fk_repayment_loan
        FOREIGN KEY (loan_id) REFERENCES loan (loan_id),
    CONSTRAINT chk_repayment_installment CHECK (installment_number > 0),
    CONSTRAINT chk_repayment_due CHECK (amount_due_usd >= 0),
    CONSTRAINT chk_repayment_paid CHECK (amount_paid_usd >= 0),
    CONSTRAINT chk_repayment_late CHECK (days_late >= 0),
    CONSTRAINT chk_repayment_balance CHECK (remaining_balance_usd >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS repayment_plan (
    plan_id INT NOT NULL AUTO_INCREMENT,
    user_id VARCHAR(10) NOT NULL,
    plan_date DATE NOT NULL,
    total_months INT NOT NULL,
    monthly_available_amount DECIMAL(12,2) NOT NULL,
    risk_level VARCHAR(10) NOT NULL,
    -- Added because the report's INSERT and SELECT use plan_status,
    -- although it is absent from the report's CREATE TABLE screenshot.
    plan_status VARCHAR(15) NOT NULL DEFAULT 'Active',
    PRIMARY KEY (plan_id),
    CONSTRAINT fk_repayment_plan_user
        FOREIGN KEY (user_id) REFERENCES `user` (user_id),
    CONSTRAINT chk_plan_months CHECK (total_months > 0),
    CONSTRAINT chk_plan_available CHECK (monthly_available_amount >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS plan_payment (
    plan_payment_id INT NOT NULL AUTO_INCREMENT,
    plan_id INT NOT NULL,
    loan_id VARCHAR(10) NOT NULL,
    due_month DATE NOT NULL,
    planned_amount_usd DECIMAL(12,2) NOT NULL,
    priority_order INT NOT NULL,
    PRIMARY KEY (plan_payment_id),
    CONSTRAINT fk_plan_payment_plan
        FOREIGN KEY (plan_id) REFERENCES repayment_plan (plan_id),
    CONSTRAINT fk_plan_payment_loan
        FOREIGN KEY (loan_id) REFERENCES loan (loan_id),
    CONSTRAINT chk_planned_amount CHECK (planned_amount_usd >= 0),
    CONSTRAINT chk_priority_order CHECK (priority_order > 0)
) ENGINE=InnoDB;

-- Optional structure verification shown alongside DDL in the report.
DESCRIBE `user`;
DESCRIBE financial_profile;
DESCRIBE loan;
DESCRIBE repayment;
DESCRIBE repayment_plan;
DESCRIBE plan_payment;

-- ============================================================
-- 6. DML STATEMENTS (report pages 19-21)
-- ============================================================

-- 6.1 Insertion of USER Record
INSERT INTO `user` (user_id)
VALUES ('U03941')
ON DUPLICATE KEY UPDATE user_id = VALUES(user_id);

SELECT *
FROM `user`
WHERE user_id = 'U03941';

-- 6.2 Insertion of FINANCIAL_PROFILE Record
INSERT INTO financial_profile
    (user_id, monthly_income_usd, monthly_expenses_usd, savings_usd,
     has_loan, debt_to_income_ratio, credit_score, record_date)
SELECT 'U03941', 5000.00, 2500.00, 4000.00,
       'Yes', 35.00, 720, '2026-08-24'
WHERE NOT EXISTS (
    SELECT 1
    FROM financial_profile
    WHERE user_id = 'U03941'
      AND record_date = '2026-08-24'
);

SELECT *
FROM financial_profile
WHERE user_id = 'U03941';

-- 6.3 Insertion of LOAN Record
-- The screenshot's INSERT uses loan_type='Personal', but its displayed
-- row says Education. The screenshot also shows an existing row with
-- this loan_id; ON DUPLICATE KEY UPDATE changes only loan_id, so it
-- does not change the existing row's other values.
INSERT INTO loan
    (loan_id, user_id, loan_type, loan_amount_usd, loan_term_months,
     monthly_emi_usd, loan_interest_rate_pct)
VALUES
    ('L03941', 'U03941', 'Personal', 10000.00, 24, 500.00, 8.50)
ON DUPLICATE KEY UPDATE loan_id = VALUES(loan_id);

SELECT *
FROM loan
WHERE loan_id = 'L03941';

-- 6.4 Insertion of REPAYMENT_PLAN Record
INSERT INTO repayment_plan
    (plan_id, user_id, plan_date, total_months,
     monthly_available_amount, risk_level, plan_status)
VALUES
    (1, 'U03941', '2026-08-24', 12, 2339.46, 'High', 'Active')
ON DUPLICATE KEY UPDATE
    user_id = VALUES(user_id),
    plan_date = VALUES(plan_date),
    total_months = VALUES(total_months),
    monthly_available_amount = VALUES(monthly_available_amount),
    risk_level = VALUES(risk_level),
    plan_status = VALUES(plan_status);

SELECT plan_id, user_id, plan_date, total_months,
       monthly_available_amount, risk_level, plan_status
FROM repayment_plan
WHERE plan_id = 1;

-- 6.5 Insertion of PLAN_PAYMENT Record
INSERT INTO plan_payment
    (plan_id, loan_id, due_month, planned_amount_usd, priority_order)
VALUES
    (1, 'L03941', '2026-09-01', 794.82, 1);

SELECT plan_payment_id, plan_id, loan_id, due_month,
       planned_amount_usd, priority_order
FROM plan_payment
WHERE plan_id = 1;

-- ============================================================
-- 7. QUERIES (report pages 22-25)
-- ============================================================

-- 7.1 Grouping Loans by Type Using Aggregate Functions
SELECT
    loan_type,
    COUNT(*) AS total_loans,
    SUM(loan_amount_usd) AS total_loan_amount,
    AVG(loan_amount_usd) AS average_loan_amount
FROM loan
GROUP BY loan_type;

-- 7.2 Updating the Planned Payment Amount
UPDATE plan_payment
SET planned_amount_usd = 874.30
WHERE plan_id = 1
  AND loan_id = 'L03941'
  AND due_month = '2026-09-01';

SELECT *
FROM plan_payment
WHERE plan_id = 1;

-- 7.3 Deleting a Planned Payment Record
-- This deletes all plan_payment rows for plan 1 and loan L03941,
-- matching the WHERE clause shown in the report.
DELETE FROM plan_payment
WHERE plan_id = 1
  AND loan_id = 'L03941';

SELECT *
FROM plan_payment
WHERE plan_id = 1;

-- 7.4 Retrieving Loan Details Using a Correlated Subquery
SELECT
    l.loan_id,
    l.user_id,
    l.loan_type,
    l.loan_amount_usd,
    (
        SELECT COUNT(*)
        FROM repayment r
        WHERE r.loan_id = l.loan_id
    ) AS total_repayments
FROM loan l
LIMIT 10;

-- 7.5 Retrieving Financial Profiles Using a Nested Query
SELECT
    user_id,
    credit_score,
    monthly_income_usd,
    monthly_expenses_usd,
    savings_usd
FROM financial_profile
WHERE user_id IN (
    SELECT user_id
    FROM loan
)
LIMIT 10;

-- ============================================================
-- 8. STORED PROCEDURES, FUNCTIONS AND TRIGGERS (pages 25-27)
-- ============================================================

-- 8.1.1 Stored Procedure Creation
DROP PROCEDURE IF EXISTS GetLoanRepaymentDetails;

DELIMITER //

CREATE PROCEDURE GetLoanRepaymentDetails(
    IN p_loan_id VARCHAR(10)
)
BEGIN
    SELECT
        loan_id,
        installment_number,
        due_date,
        payment_date,
        amount_due_usd,
        amount_paid_usd,
        payment_status,
        days_late,
        remaining_balance_usd
    FROM repayment
    WHERE loan_id = p_loan_id;
END //

DELIMITER ;

-- 8.1.2 Stored Procedure Execution
-- Use a loan_id that exists in the repayment table.
CALL GetLoanRepaymentDetails('L03941');

-- 8.1.3 Stored Procedure Verification
SHOW PROCEDURE STATUS
WHERE Db = 'credit_health_db'
  AND Name = 'GetLoanRepaymentDetails';

-- 8.2.1 Trigger to Automatically Calculate Days Late
DROP TRIGGER IF EXISTS Calculate_Days_Late;

DELIMITER //

CREATE TRIGGER Calculate_Days_Late
BEFORE INSERT ON repayment
FOR EACH ROW
BEGIN
    SET NEW.days_late =
        CASE
            WHEN NEW.payment_date IS NOT NULL THEN
                GREATEST(
                    DATEDIFF(NEW.payment_date, NEW.due_date), 0
                )
            ELSE
                GREATEST(
                    DATEDIFF(CURDATE(), NEW.due_date), 0
                )
        END;
END //

DELIMITER ;

-- 8.2.2 Trigger Verification
SHOW TRIGGERS
WHERE `Table` = 'repayment';

-- ============================================================
-- END OF SQL SCRIPT
-- ============================================================
