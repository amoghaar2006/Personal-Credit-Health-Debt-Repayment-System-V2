-- PERSONAL CREDIT HEALTH AND DEBT REPAYMENT PLANNING SYSTEM
-- MySQL 8.0+ | Individual project script
-- Run scripts in numerical order where dependencies apply.
USE credit_health_db;

-- 02 INSERT DATA AND DML EXAMPLES
-- The sample inserts are designed to avoid duplicate seed records.
-- Review the sample IDs before running against your existing database.

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
