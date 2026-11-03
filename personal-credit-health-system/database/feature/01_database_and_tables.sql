-- 01 DATABASE AND TABLES
-- Creates the project database and its relational tables.
-- Includes seven core tables plus app_account for optional application login.
CREATE DATABASE IF NOT EXISTS credit_health_db
    CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
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
