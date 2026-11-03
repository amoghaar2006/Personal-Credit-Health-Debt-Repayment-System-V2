-- PERSONAL CREDIT HEALTH AND DEBT REPAYMENT PLANNING SYSTEM
-- MySQL 8.0+ | Individual project script
-- Run scripts in numerical order where dependencies apply.
USE credit_health_db;

-- 06 TRIGGERS
-- Four triggers: days-late calculation, amount validation, date validation,
-- and validation/recalculation on UPDATE.

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

-- Trigger verification
SHOW TRIGGERS FROM credit_health_db;
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
