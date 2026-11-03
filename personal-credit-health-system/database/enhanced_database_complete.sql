-- ============================================================================
-- PERSONAL CREDIT HEALTH AND DEBT REPAYMENT PLANNING SYSTEM
-- Enhanced MySQL 8.0+ Database Script
--
-- Includes:
--   1. Seven relational tables
--   2. Primary keys, foreign keys, constraints and indexes
--   3. Two views
--   4. Four triggers (one calculation + three validation triggers)
--   5. Three stored procedures
--   6. DDL, DML, JOIN, GROUP BY, HAVING, ORDER BY and subquery examples
--   7. Safe ALTER/DROP demonstration using a temporary table
--   8. Safe COMMIT/ROLLBACK demonstration using a temporary table
--
-- IMPORTANT:
--   - Intended for MySQL 8.0+.
--   - Back up your database before running any schema changes.
--   - This script does NOT drop the project database or its seven main tables.
--   - The optional seed section uses U03941/L03941 and avoids overwriting
--     existing profile/loan/plan records.
--   - Run the script in MySQL Workbench with the complete script selected.
-- ============================================================================

CREATE DATABASE IF NOT EXISTS credit_health_db
    CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE credit_health_db;

-- ============================================================================
-- SECTION 1: DDL - TABLE CREATION
-- ============================================================================

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

-- Additional account table for application login.
CREATE TABLE IF NOT EXISTS app_account (
    account_id INT NOT NULL AUTO_INCREMENT,
    user_id VARCHAR(10) NOT NULL,
    email VARCHAR(254) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role ENUM('owner','viewer') NOT NULL DEFAULT 'owner',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (account_id),
    UNIQUE KEY uq_app_account_email (email),
    UNIQUE KEY uq_app_account_user (user_id),
    CONSTRAINT fk_app_account_user
        FOREIGN KEY (user_id) REFERENCES `user` (user_id)
) ENGINE=InnoDB;

-- ============================================================================
-- SECTION 2: DDL - INDEXES
-- Create secondary indexes only when they do not already exist.
-- The primary keys and UNIQUE indexes are defined in the table definitions.
-- ============================================================================

DROP PROCEDURE IF EXISTS _ensure_project_index;
DELIMITER //
CREATE PROCEDURE _ensure_project_index(
    IN p_table_name VARCHAR(64),
    IN p_index_name VARCHAR(64),
    IN p_index_definition VARCHAR(500)
)
BEGIN
    DECLARE v_index_count INT DEFAULT 0;

    SELECT COUNT(*)
      INTO v_index_count
      FROM information_schema.statistics
     WHERE table_schema = DATABASE()
       AND table_name = p_table_name
       AND index_name = p_index_name;

    IF v_index_count = 0 THEN
        SET @index_sql = CONCAT(
            'CREATE INDEX `', REPLACE(p_index_name, '`', '``'),
            '` ON `', REPLACE(p_table_name, '`', '``'),
            '` (', p_index_definition, ')'
        );
        PREPARE index_stmt FROM @index_sql;
        EXECUTE index_stmt;
        DEALLOCATE PREPARE index_stmt;
    END IF;
END //
DELIMITER ;

CALL _ensure_project_index('financial_profile', 'idx_profile_user_date',
                            '`user_id`, `record_date`');
CALL _ensure_project_index('loan', 'idx_loan_user_type',
                            '`user_id`, `loan_type`');
CALL _ensure_project_index('repayment', 'idx_repayment_loan_due',
                            '`loan_id`, `due_date`');
CALL _ensure_project_index('repayment', 'idx_repayment_status_due',
                            '`payment_status`, `due_date`');
CALL _ensure_project_index('repayment_plan', 'idx_plan_user_status',
                            '`user_id`, `plan_status`');
CALL _ensure_project_index('plan_payment', 'idx_plan_payment_plan_month',
                            '`plan_id`, `due_month`');

DROP PROCEDURE IF EXISTS _ensure_project_index;

-- ============================================================================
-- SECTION 3: VIEWS
-- ============================================================================

CREATE OR REPLACE VIEW vw_loan_summary AS
SELECT
    l.loan_id,
    l.user_id,
    l.loan_type,
    l.loan_amount_usd,
    l.monthly_emi_usd,
    l.loan_term_months,
    l.loan_interest_rate_pct,
    COUNT(r.payment_id) AS repayment_count,
    COALESCE(SUM(r.remaining_balance_usd), 0) AS remaining_balance_usd
FROM loan AS l
LEFT JOIN repayment AS r ON r.loan_id = l.loan_id
GROUP BY
    l.loan_id, l.user_id, l.loan_type, l.loan_amount_usd,
    l.monthly_emi_usd, l.loan_term_months, l.loan_interest_rate_pct;

CREATE OR REPLACE VIEW vw_repayment_status AS
SELECT
    payment_id,
    loan_id,
    installment_number,
    due_date,
    payment_date,
    amount_due_usd,
    amount_paid_usd,
    payment_status,
    days_late,
    remaining_balance_usd
FROM repayment;

-- ============================================================================
-- SECTION 4: STORED PROCEDURES
-- ============================================================================

DROP PROCEDURE IF EXISTS GetLoanRepaymentDetails;
DROP PROCEDURE IF EXISTS GetOverdueRepayments;
DROP PROCEDURE IF EXISTS GetUserDebtSummary;

DELIMITER //

-- Existing procedure: retrieves installments for one loan.
CREATE PROCEDURE GetLoanRepaymentDetails(IN p_loan_id VARCHAR(10))
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
    WHERE loan_id = p_loan_id
    ORDER BY installment_number;
END //

-- New procedure: lists overdue unpaid/partially paid installments
-- as of the supplied date.
CREATE PROCEDURE GetOverdueRepayments(IN p_as_of_date DATE)
BEGIN
    SELECT
        r.payment_id,
        r.loan_id,
        l.user_id,
        r.installment_number,
        r.due_date,
        r.amount_due_usd,
        r.amount_paid_usd,
        (r.amount_due_usd - r.amount_paid_usd) AS unpaid_amount_usd,
        GREATEST(DATEDIFF(p_as_of_date, r.due_date), 0) AS overdue_days
    FROM repayment AS r
    INNER JOIN loan AS l ON l.loan_id = r.loan_id
    WHERE r.due_date < p_as_of_date
      AND r.amount_paid_usd < r.amount_due_usd
    ORDER BY r.due_date ASC;
END //

-- New procedure: provides a debt summary for one user.
-- Outstanding balance uses the latest installment balance for each loan.
-- If a loan has no repayment rows yet, its original loan amount is used.
CREATE PROCEDURE GetUserDebtSummary(IN p_user_id VARCHAR(10))
BEGIN
    SELECT
        u.user_id,
        COALESCE((
            SELECT SUM(l.loan_amount_usd)
            FROM loan AS l
            WHERE l.user_id = u.user_id
        ), 0) AS total_loan_amount_usd,
        COALESCE((
            SELECT SUM(r.amount_paid_usd)
            FROM repayment AS r
            INNER JOIN loan AS l2 ON l2.loan_id = r.loan_id
            WHERE l2.user_id = u.user_id
        ), 0) AS total_amount_paid_usd,
        COALESCE((
            SELECT SUM(
                COALESCE(
                    (
                        SELECT r2.remaining_balance_usd
                        FROM repayment AS r2
                        WHERE r2.loan_id = l3.loan_id
                        ORDER BY r2.installment_number DESC
                        LIMIT 1
                    ),
                    l3.loan_amount_usd
                )
            )
            FROM loan AS l3
            WHERE l3.user_id = u.user_id
        ), 0) AS current_outstanding_balance_usd
    FROM `user` AS u
    WHERE u.user_id = p_user_id;
END //

DELIMITER ;

-- ============================================================================
-- SECTION 5: TRIGGERS
-- Four triggers total: one calculation trigger and three validation triggers.
-- ============================================================================

DROP TRIGGER IF EXISTS Calculate_Days_Late;
DROP TRIGGER IF EXISTS Validate_Repayment_Amount;
DROP TRIGGER IF EXISTS Validate_Repayment_Date;
DROP TRIGGER IF EXISTS Validate_Repayment_Update;

DELIMITER //

-- Existing trigger: calculate days late automatically before INSERT.
CREATE TRIGGER Calculate_Days_Late
BEFORE INSERT ON repayment
FOR EACH ROW
BEGIN
    SET NEW.days_late =
        CASE
            WHEN NEW.payment_date IS NOT NULL
                THEN GREATEST(DATEDIFF(NEW.payment_date, NEW.due_date), 0)
            ELSE GREATEST(DATEDIFF(CURDATE(), NEW.due_date), 0)
        END;
END //

-- New trigger: reject an amount paid greater than the installment amount.
-- Partial payments and zero payments remain allowed.
CREATE TRIGGER Validate_Repayment_Amount
BEFORE INSERT ON repayment
FOR EACH ROW
BEGIN
    IF NEW.amount_paid_usd > NEW.amount_due_usd THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
                'Invalid repayment: amount paid cannot exceed amount due';
    END IF;
END //

-- New trigger: reject a payment date later than the current date.
CREATE TRIGGER Validate_Repayment_Date
BEFORE INSERT ON repayment
FOR EACH ROW
BEGIN
    IF NEW.payment_date IS NOT NULL
       AND NEW.payment_date > CURDATE() THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
                'Invalid repayment: payment date cannot be in the future';
    END IF;
END //

-- New trigger: apply the same validation when a repayment is updated.
CREATE TRIGGER Validate_Repayment_Update
BEFORE UPDATE ON repayment
FOR EACH ROW
BEGIN
    IF NEW.amount_paid_usd > NEW.amount_due_usd THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
                'Invalid repayment update: amount paid cannot exceed amount due';
    END IF;

    IF NEW.payment_date IS NOT NULL
       AND NEW.payment_date > CURDATE() THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT =
                'Invalid repayment update: payment date cannot be in the future';
    END IF;

    SET NEW.days_late =
        CASE
            WHEN NEW.payment_date IS NOT NULL
                THEN GREATEST(DATEDIFF(NEW.payment_date, NEW.due_date), 0)
            ELSE GREATEST(DATEDIFF(CURDATE(), NEW.due_date), 0)
        END;
END //

DELIMITER ;

-- ============================================================================
-- SECTION 6: OPTIONAL, SAFE SAMPLE DATA
-- The following inserts are idempotent and do not overwrite existing values.
-- They create a small example dataset only if these IDs are not already used.
-- ============================================================================

INSERT INTO `user` (user_id)
VALUES ('U03941')
ON DUPLICATE KEY UPDATE user_id = user_id;

INSERT INTO financial_profile
(
    user_id, monthly_income_usd, monthly_expenses_usd, savings_usd,
    has_loan, debt_to_income_ratio, credit_score, record_date
)
SELECT
    'U03941', 5000.00, 2500.00, 4000.00,
    'Yes', 35.00, 720, '2026-08-24'
WHERE NOT EXISTS (
    SELECT 1
    FROM financial_profile
    WHERE user_id = 'U03941'
      AND record_date = '2026-08-24'
);

INSERT INTO loan
(
    loan_id, user_id, loan_type, loan_amount_usd, loan_term_months,
    monthly_emi_usd, loan_interest_rate_pct
)
VALUES
    ('L03941', 'U03941', 'Personal', 10000.00, 24, 500.00, 8.50)
ON DUPLICATE KEY UPDATE loan_id = loan_id;

INSERT INTO repayment_plan
(
    user_id, plan_date, total_months, monthly_available_amount,
    risk_level, plan_status
)
SELECT
    'U03941', '2026-08-24', 12, 2339.46, 'High', 'Active'
WHERE NOT EXISTS (
    SELECT 1
    FROM repayment_plan
    WHERE user_id = 'U03941'
      AND plan_date = '2026-08-24'
);

INSERT INTO plan_payment
(
    plan_id, loan_id, due_month, planned_amount_usd, priority_order
)
SELECT
    rp.plan_id, 'L03941', '2026-09-01', 794.82, 1
FROM repayment_plan AS rp
WHERE rp.user_id = 'U03941'
  AND rp.plan_date = '2026-08-24'
  AND NOT EXISTS (
      SELECT 1
      FROM plan_payment AS pp
      WHERE pp.plan_id = rp.plan_id
        AND pp.loan_id = 'L03941'
        AND pp.due_month = '2026-09-01'
  );

-- ============================================================================
-- SECTION 7: SAFE ALTER AND DROP DEMONSTRATION
-- Uses a temporary table; does not alter/drop any real project table.
-- ============================================================================

DROP TEMPORARY TABLE IF EXISTS ddl_demo;
CREATE TEMPORARY TABLE ddl_demo (
    demo_id INT NOT NULL PRIMARY KEY,
    demo_name VARCHAR(50) NOT NULL
) ENGINE=InnoDB;

-- ALTER demonstration: add a column.
ALTER TABLE ddl_demo
ADD COLUMN demo_status VARCHAR(20) NOT NULL DEFAULT 'Active';

-- Verify ALTER.
DESCRIBE ddl_demo;

-- DROP demonstration: remove the temporary demonstration table.
DROP TEMPORARY TABLE ddl_demo;

-- ============================================================================
-- SECTION 8: SAFE DML DEMONSTRATION
-- INSERT, SELECT, UPDATE and DELETE are demonstrated on a temporary table.
-- No actual project records are changed.
-- ============================================================================

DROP TEMPORARY TABLE IF EXISTS dml_demo;
CREATE TEMPORARY TABLE dml_demo (
    demo_id INT NOT NULL PRIMARY KEY,
    demo_description VARCHAR(100) NOT NULL
) ENGINE=InnoDB;

-- INSERT
INSERT INTO dml_demo (demo_id, demo_description)
VALUES (1, 'Initial demonstration record');

-- SELECT
SELECT * FROM dml_demo;

-- UPDATE
UPDATE dml_demo
SET demo_description = 'Updated demonstration record'
WHERE demo_id = 1;

-- Verify UPDATE
SELECT * FROM dml_demo;

-- DELETE
DELETE FROM dml_demo
WHERE demo_id = 1;

-- Verify DELETE (returns zero rows)
SELECT * FROM dml_demo;

DROP TEMPORARY TABLE dml_demo;

-- ============================================================================
-- SECTION 9: DML AND QUERY DEMONSTRATIONS
-- These are read-only SELECT examples against the project data.
-- ============================================================================

-- 8.1 SELECT: display repayment records.
SELECT * FROM repayment;

-- 8.2 INNER JOIN: combine loans and their repayment records.
SELECT
    l.loan_id,
    l.user_id,
    l.loan_type,
    r.payment_id,
    r.installment_number,
    r.payment_status,
    r.amount_paid_usd,
    r.days_late
FROM loan AS l
INNER JOIN repayment AS r ON r.loan_id = l.loan_id
ORDER BY l.loan_id, r.installment_number;

-- 8.3 LEFT JOIN: include loans even when they have no repayment records.
SELECT
    l.loan_id,
    l.user_id,
    l.loan_amount_usd,
    COUNT(r.payment_id) AS number_of_repayments
FROM loan AS l
LEFT JOIN repayment AS r ON r.loan_id = l.loan_id
GROUP BY l.loan_id, l.user_id, l.loan_amount_usd
ORDER BY number_of_repayments DESC;

-- 8.4 GROUP BY with aggregate functions.
SELECT
    loan_id,
    COUNT(*) AS installment_count,
    SUM(amount_due_usd) AS total_due_usd,
    SUM(amount_paid_usd) AS total_paid_usd
FROM repayment
GROUP BY loan_id;

-- 8.5 HAVING: show loans whose total recorded amount paid exceeds 1000.
SELECT
    loan_id,
    SUM(amount_paid_usd) AS total_paid_usd
FROM repayment
GROUP BY loan_id
HAVING SUM(amount_paid_usd) > 1000;

-- 8.6 ORDER BY: list the most delayed repayments first.
SELECT
    payment_id,
    loan_id,
    due_date,
    payment_date,
    days_late
FROM repayment
ORDER BY days_late DESC, due_date ASC;

-- 8.7 Aggregate functions: count, average and maximum delay.
SELECT
    COUNT(*) AS total_repayment_records,
    COALESCE(AVG(days_late), 0) AS average_days_late,
    COALESCE(MAX(days_late), 0) AS maximum_days_late
FROM repayment;

-- 8.8 Subquery: loans that have at least one late repayment.
SELECT
    loan_id,
    user_id,
    loan_type,
    loan_amount_usd
FROM loan
WHERE loan_id IN (
    SELECT loan_id
    FROM repayment
    WHERE days_late > 0
);

-- 8.9 Correlated subquery: loans with at least one repayment record.
SELECT
    l.loan_id,
    l.user_id,
    l.loan_amount_usd
FROM loan AS l
WHERE EXISTS (
    SELECT 1
    FROM repayment AS r
    WHERE r.loan_id = l.loan_id
);

-- 8.10 View demonstrations.
SELECT * FROM vw_loan_summary;
SELECT * FROM vw_repayment_status;

-- 8.11 Index verification.
SHOW INDEX FROM financial_profile;
SHOW INDEX FROM loan;
SHOW INDEX FROM repayment;
SHOW INDEX FROM repayment_plan;
SHOW INDEX FROM plan_payment;

-- ============================================================================
-- SECTION 10: STORED PROCEDURE EXECUTION EXAMPLES
-- Use IDs that exist in your database. LTEST001 and TEST0001 are examples
-- from the project's current demonstration data; replace if your data differs.
-- ============================================================================

-- These IDs are from the current project demonstration data.
-- If you run this on a clean database with only the optional U03941 seed,
-- replace LTEST001 with L03941 and TEST0001 with U03941.
CALL GetLoanRepaymentDetails('LTEST001');
CALL GetOverdueRepayments(CURDATE());
CALL GetUserDebtSummary('TEST0001');

-- ============================================================================
-- SECTION 11: TRIGGER VERIFICATION
-- ============================================================================

SHOW TRIGGERS FROM credit_health_db;

-- Inspect the trigger-generated days_late values.
SELECT
    payment_id,
    loan_id,
    due_date,
    payment_date,
    payment_status,
    days_late
FROM repayment
ORDER BY payment_id;

-- Optional negative tests: execute ONE AT A TIME only if loan LTEST001 exists.
-- Each statement is expected to fail with MySQL Error 1644 / SQLSTATE 45000.
-- Uncomment and run separately; do not include them in a full-script run.
--
-- Test amount validation (amount_paid_usd > amount_due_usd):
-- INSERT INTO repayment
-- (payment_id, loan_id, installment_number, due_date, payment_date,
--  amount_due_usd, amount_paid_usd, payment_status, remaining_balance_usd)
-- VALUES
-- ('PERR_AMOUNT', 'LTEST001', 99, CURDATE(), CURDATE(),
--  100.00, 150.00, 'Paid', 0.00);
--
-- Test future-date validation:
-- INSERT INTO repayment
-- (payment_id, loan_id, installment_number, due_date, payment_date,
--  amount_due_usd, amount_paid_usd, payment_status, remaining_balance_usd)
-- VALUES
-- ('PERR_DATE', 'LTEST001', 98, CURDATE(), DATE_ADD(CURDATE(), INTERVAL 1 DAY),
--  100.00, 50.00, 'Pending', 50.00);

-- ============================================================================
-- SECTION 12: SAFE TRANSACTION DEMONSTRATION
-- Uses a temporary InnoDB table so no real project data is changed.
-- ============================================================================

DROP TEMPORARY TABLE IF EXISTS transaction_demo;
CREATE TEMPORARY TABLE transaction_demo (
    demo_id INT NOT NULL PRIMARY KEY,
    description VARCHAR(100) NOT NULL
) ENGINE=InnoDB;

-- COMMIT example: this row should remain in the temporary table.
START TRANSACTION;
INSERT INTO transaction_demo (demo_id, description)
VALUES (1, 'This row is committed');
COMMIT;

-- ROLLBACK example: this row should not remain in the temporary table.
START TRANSACTION;
INSERT INTO transaction_demo (demo_id, description)
VALUES (2, 'This row is rolled back');
ROLLBACK;

-- Only demo_id 1 should be returned.
SELECT * FROM transaction_demo;

DROP TEMPORARY TABLE transaction_demo;

-- ============================================================================
-- SECTION 13: FINAL DATABASE OBJECT VERIFICATION
-- ============================================================================

SHOW TABLES;
SHOW FULL TABLES WHERE Table_type = 'VIEW';
SHOW TRIGGERS FROM credit_health_db;
SHOW PROCEDURE STATUS WHERE Db = 'credit_health_db';

-- End of enhanced database script.
