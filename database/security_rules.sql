
USE momo_sms_system;


DROP USER IF EXISTS 'momo_readonly'@'%';
CREATE USER 'momo_readonly'@'%' IDENTIFIED BY 'Maureen123!';
GRANT SELECT ON momo_sms_system.Transaction_Categories TO 'momo_readonly'@'%';
GRANT SELECT ON momo_sms_system.Raw_SMS_Log TO 'momo_readonly'@'%';
GRANT SELECT ON momo_sms_system.Transactions TO 'momo_readonly'@'%';
GRANT SELECT ON momo_sms_system.Transaction_Participants TO 'momo_readonly'@'%';
GRANT SELECT ON momo_sms_system.System_Logs TO 'momo_readonly'@'%';


DROP USER IF EXISTS 'momo_etl'@'%';
CREATE USER 'momo_etl'@'%' IDENTIFIED BY 'Maureen123!';
GRANT SELECT, INSERT, UPDATE ON momo_sms_system.* TO 'momo_etl'@'%';

-- Admin account — full privileges, used only for maintenance
DROP USER IF EXISTS 'momo_admin'@'%';
CREATE USER 'momo_admin'@'%' IDENTIFIED BY 'Maureen123!';
GRANT ALL PRIVILEGES ON momo_sms_system.* TO 'momo_admin'@'%';

FLUSH PRIVILEGES;

CREATE OR REPLACE VIEW View_Users_Masked AS
SELECT
    user_id,
    full_name,
    CONCAT('*******', RIGHT(phone_number, 4)) AS phone_number_masked,
    user_category,
    created_at
FROM Users;

GRANT SELECT ON momo_sms_system.View_Users_Masked TO 'momo_readonly'@'%';


DELIMITER $$
DROP TRIGGER IF EXISTS trg_prevent_amount_change_after_completion$$
CREATE TRIGGER trg_prevent_amount_change_after_completion
BEFORE UPDATE ON Transactions
FOR EACH ROW
BEGIN
    IF OLD.status = 'COMPLETED'
       AND (NEW.amount <> OLD.amount OR NEW.fee <> OLD.fee)
    THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Amount/fee of a COMPLETED transaction cannot be modified. Use a REVERSAL transaction instead.';
    END IF;
END$$
DELIMITER ;


DELIMITER $$
DROP TRIGGER IF EXISTS trg_audit_transaction_delete$$
CREATE TRIGGER trg_audit_transaction_delete
BEFORE DELETE ON Transactions
FOR EACH ROW
BEGIN
    INSERT INTO System_Logs (related_sms_id, process_step, status, message)
    VALUES (NULL, 'DELETE_TRANSACTION', 'SUCCESS',
            CONCAT('Transaction ', OLD.transaction_id, ' (amount ', OLD.amount, ') deleted at ', NOW()));
END$$
DELIMITER ;

