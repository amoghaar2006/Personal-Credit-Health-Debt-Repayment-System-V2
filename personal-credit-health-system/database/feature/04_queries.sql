-- PERSONAL CREDIT HEALTH AND DEBT REPAYMENT PLANNING SYSTEM
-- MySQL 8.0+ | Individual project script
-- Run scripts in numerical order where dependencies apply.
USE credit_health_db;

-- 04 SQL QUERIES
-- SELECT, INNER JOIN, LEFT JOIN, GROUP BY, HAVING, ORDER BY, aggregates
-- and subqueries. Run after inserting or loading project data.

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
