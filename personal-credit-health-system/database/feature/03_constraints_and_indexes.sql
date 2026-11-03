-- PERSONAL CREDIT HEALTH AND DEBT REPAYMENT PLANNING SYSTEM
-- MySQL 8.0+ | Individual project script
-- Run scripts in numerical order where dependencies apply.
USE credit_health_db;

-- 03 CONSTRAINTS AND INDEXES
-- PRIMARY KEY, FOREIGN KEY and CHECK constraints are declared directly
-- in 01_database_and_tables.sql. This script creates secondary indexes
-- only when they do not already exist, then provides verification queries.

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

-- Constraint and index verification
SHOW CREATE TABLE `user`;
SHOW CREATE TABLE financial_profile;
SHOW CREATE TABLE loan;
SHOW CREATE TABLE repayment;
SHOW CREATE TABLE repayment_plan;
SHOW CREATE TABLE plan_payment;
SHOW INDEX FROM financial_profile;
SHOW INDEX FROM loan;
SHOW INDEX FROM repayment;
SHOW INDEX FROM repayment_plan;
SHOW INDEX FROM plan_payment;
