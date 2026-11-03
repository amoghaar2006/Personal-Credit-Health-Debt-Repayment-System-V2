-- Enhanced MySQL 8.0+ schema for Personal Credit Health and Debt Repayment Planning System.
-- Intended for a clean database install. Existing table names and core columns are retained.
-- Existing report data is not bundled; the report does not provide the full source dataset.

CREATE DATABASE IF NOT EXISTS credit_health_db CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE credit_health_db;

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
    CONSTRAINT fk_financial_profile_user FOREIGN KEY (user_id) REFERENCES `user` (user_id),
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
    CONSTRAINT fk_loan_user FOREIGN KEY (user_id) REFERENCES `user` (user_id),
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
    CONSTRAINT fk_repayment_loan FOREIGN KEY (loan_id) REFERENCES loan (loan_id),
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
    CONSTRAINT fk_repayment_plan_user FOREIGN KEY (user_id) REFERENCES `user` (user_id),
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
    CONSTRAINT fk_plan_payment_plan FOREIGN KEY (plan_id) REFERENCES repayment_plan (plan_id),
    CONSTRAINT fk_plan_payment_loan FOREIGN KEY (loan_id) REFERENCES loan (loan_id),
    CONSTRAINT chk_planned_amount CHECK (planned_amount_usd >= 0),
    CONSTRAINT chk_priority_order CHECK (priority_order > 0)
) ENGINE=InnoDB;

-- Additional account table for optional application login. It does not replace USER.
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
    CONSTRAINT fk_app_account_user FOREIGN KEY (user_id) REFERENCES `user` (user_id)
) ENGINE=InnoDB;

-- Query-performance indexes (created as part of clean install).
CREATE INDEX idx_profile_user_date ON financial_profile(user_id, record_date);
CREATE INDEX idx_loan_user_type ON loan(user_id, loan_type);
CREATE INDEX idx_repayment_loan_due ON repayment(loan_id, due_date);
CREATE INDEX idx_repayment_status_due ON repayment(payment_status, due_date);
CREATE INDEX idx_plan_user_status ON repayment_plan(user_id, plan_status);
CREATE INDEX idx_plan_payment_plan_month ON plan_payment(plan_id, due_month);

-- Useful dashboard/reporting views.
CREATE OR REPLACE VIEW vw_loan_summary AS
SELECT l.loan_id, l.user_id, l.loan_type, l.loan_amount_usd,
       l.monthly_emi_usd, l.loan_term_months, l.loan_interest_rate_pct,
       COUNT(r.payment_id) AS repayment_count,
       COALESCE(SUM(r.remaining_balance_usd), 0) AS remaining_balance_usd
FROM loan l
LEFT JOIN repayment r ON r.loan_id = l.loan_id
GROUP BY l.loan_id, l.user_id, l.loan_type, l.loan_amount_usd,
         l.monthly_emi_usd, l.loan_term_months, l.loan_interest_rate_pct;

CREATE OR REPLACE VIEW vw_repayment_status AS
SELECT payment_id, loan_id, installment_number, due_date, payment_date,
       amount_due_usd, amount_paid_usd, payment_status, days_late,
       remaining_balance_usd
FROM repayment;

DROP PROCEDURE IF EXISTS GetLoanRepaymentDetails;
DELIMITER //
CREATE PROCEDURE GetLoanRepaymentDetails(IN p_loan_id VARCHAR(10))
BEGIN
    SELECT loan_id, installment_number, due_date, payment_date,
           amount_due_usd, amount_paid_usd, payment_status, days_late,
           remaining_balance_usd
    FROM repayment
    WHERE loan_id = p_loan_id
    ORDER BY installment_number;
END //

DROP TRIGGER IF EXISTS Calculate_Days_Late;
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
DELIMITER ;

-- Sample row matching the explicit single-user DML example in the report.
INSERT INTO `user` (user_id) VALUES ('U03941')
ON DUPLICATE KEY UPDATE user_id = VALUES(user_id);

INSERT INTO financial_profile
(user_id, monthly_income_usd, monthly_expenses_usd, savings_usd,
 has_loan, debt_to_income_ratio, credit_score, record_date)
SELECT 'U03941', 5000.00, 2500.00, 4000.00, 'Yes', 35.00, 720, '2026-08-24'
WHERE NOT EXISTS (
    SELECT 1 FROM financial_profile
    WHERE user_id='U03941' AND record_date='2026-08-24'
);

INSERT INTO loan
(loan_id, user_id, loan_type, loan_amount_usd, loan_term_months,
 monthly_emi_usd, loan_interest_rate_pct)
VALUES ('L03941', 'U03941', 'Personal', 10000.00, 24, 500.00, 8.50)
ON DUPLICATE KEY UPDATE loan_id=VALUES(loan_id);

INSERT INTO repayment_plan
(plan_id, user_id, plan_date, total_months, monthly_available_amount, risk_level, plan_status)
VALUES (1, 'U03941', '2026-08-24', 12, 2339.46, 'High', 'Active')
ON DUPLICATE KEY UPDATE user_id=VALUES(user_id), plan_date=VALUES(plan_date),
 total_months=VALUES(total_months), monthly_available_amount=VALUES(monthly_available_amount),
 risk_level=VALUES(risk_level), plan_status=VALUES(plan_status);

INSERT INTO plan_payment (plan_id, loan_id, due_month, planned_amount_usd, priority_order)
SELECT 1, 'L03941', '2026-09-01', 794.82, 1
WHERE NOT EXISTS (
    SELECT 1 FROM plan_payment
    WHERE plan_id=1 AND loan_id='L03941' AND due_month='2026-09-01'
);
