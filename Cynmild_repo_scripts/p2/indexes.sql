CREATE INDEX idx_ledger_account_posted ON ledger_entry(account_id, posted_at DESC);
CREATE INDEX idx_txn_failed_recent ON transaction(created_at) WHERE status='FAILED';
CREATE INDEX idx_account_customer ON account(customer_id);
ANALYZE;
