-- PERSONAL CREDIT HEALTH AND DEBT REPAYMENT PLANNING SYSTEM
-- MySQL 8.0+ | Individual project script
-- Run scripts in numerical order where dependencies apply.
USE credit_health_db;

-- 07 VIEWS
-- vw_loan_summary uses the latest installment's remaining balance per loan.
-- This avoids adding cumulative balance snapshots across installments.

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
    COALESCE(
        (SELECT r2.remaining_balance_usd
         FROM repayment AS r2
         WHERE r2.loan_id = l.loan_id
         ORDER BY r2.installment_number DESC
         LIMIT 1),
        l.loan_amount_usd
    ) AS remaining_balance_usd
FROM loan AS l
LEFT JOIN repayment AS r ON r.loan_id = l.loan_id
GROUP BY
    l.loan_id, l.user_id, l.loan_type, l.loan_amount_usd,
    l.monthly_emi_usd, l.loan_term_months, l.loan_interest_rate_pct;

CREATE OR REPLACE VIEW vw_repayment_status AS
SELECT
    payment_id, loan_id, installment_number, due_date, payment_date,
    amount_due_usd, amount_paid_usd, payment_status, days_late,
    remaining_balance_usd
FROM repayment;

-- View verification
SELECT * FROM vw_loan_summary;
SELECT * FROM vw_repayment_status;
