-- PERSONAL CREDIT HEALTH AND DEBT REPAYMENT PLANNING SYSTEM
-- MySQL 8.0+ | Individual project script
-- Run scripts in numerical order where dependencies apply.
USE credit_health_db;

-- 08 TRANSACTIONS
-- Demonstrates COMMIT and ROLLBACK on a temporary table so actual project
-- records are not changed.

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
