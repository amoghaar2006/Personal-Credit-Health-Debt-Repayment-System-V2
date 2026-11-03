-- PERSONAL CREDIT HEALTH AND DEBT REPAYMENT PLANNING SYSTEM
-- MySQL 8.0+ | Individual project script
-- Run scripts in numerical order where dependencies apply.
USE credit_health_db;

-- 05 STORED PROCEDURES
-- Creates three procedures for loan details, overdue repayments and
-- a user's overall debt summary.

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

-- Procedure execution examples. Use IDs that exist in your database.
-- Change the example IDs if your records use different identifiers.
CALL GetLoanRepaymentDetails('LTEST001');
CALL GetOverdueRepayments(CURDATE());
CALL GetUserDebtSummary('TEST0001');
