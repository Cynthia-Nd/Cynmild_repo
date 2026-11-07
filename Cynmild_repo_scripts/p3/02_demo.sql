-- Prepare two known accounts (active ones)
UPDATE account SET balance=100000, status='ACTIVE' WHERE account_number IN ('3000000001','3000000002');
\echo '--- A. COMMIT: successful transfer 25,000'
BEGIN; CALL sp_transfer('3000000001','3000000002',25000,'Rent'); COMMIT;
SELECT account_number,balance FROM account WHERE account_number IN ('3000000001','3000000002') ORDER BY 1;
\echo '--- B. ROLLBACK: failed transfer (insufficient funds) leaves balances untouched'
BEGIN;
CALL sp_transfer('3000000001','3000000002',9999999,'Too large');
ROLLBACK;
SELECT account_number,balance FROM account WHERE account_number IN ('3000000001','3000000002') ORDER BY 1;
\echo '--- C. Explicit ROLLBACK after partial work (atomicity)'
BEGIN; UPDATE account SET balance=balance-5000 WHERE account_number='3000000001'; SELECT balance AS inside_tx FROM account WHERE account_number='3000000001'; ROLLBACK;
SELECT balance AS after_rollback FROM account WHERE account_number='3000000001';
\echo '--- D. Audit: ledger must balance (debits = credits) per transfer'
SELECT t.txn_id, SUM(CASE direction WHEN 'D' THEN l.amount END) debits, SUM(CASE direction WHEN 'C' THEN l.amount END) credits FROM transaction t JOIN ledger_entry l USING(txn_id) WHERE t.narration='Rent' GROUP BY t.txn_id;
\echo '--- E. Audit trail written by trigger'
SELECT record_id, old_value, new_value FROM audit_log ORDER BY audit_id DESC LIMIT 2;
