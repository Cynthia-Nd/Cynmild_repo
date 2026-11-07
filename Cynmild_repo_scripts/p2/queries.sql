-- Q1: statement for one account in a date window
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF, TIMING OFF) SELECT le.entry_id, le.direction, le.amount, le.posted_at FROM ledger_entry le WHERE le.account_id = 4321 AND le.posted_at >= now() - interval '90 days' ORDER BY le.posted_at DESC;
-- Q2: customers with total balance over 1.5m, joined across 3 tables
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF) SELECT c.customer_id, c.full_name, SUM(a.balance) total FROM customer c JOIN account a ON a.customer_id=c.customer_id WHERE a.status='ACTIVE' GROUP BY c.customer_id, c.full_name HAVING SUM(a.balance)>1500000 ORDER BY total DESC LIMIT 10;
-- Q3: failed transfers last 30 days
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF, TIMING OFF) SELECT txn_id, amount, created_at FROM transaction WHERE status='FAILED' AND txn_type='TRANSFER' AND created_at >= now() - interval '30 days';
-- Q4: audit - ledger-implied vs stored net movement (top 5 accounts by activity)
SELECT a.account_number, SUM(CASE le.direction WHEN 'C' THEN le.amount ELSE -le.amount END) AS net_movement, COUNT(*) AS entries FROM account a JOIN ledger_entry le USING (account_id) GROUP BY a.account_number ORDER BY entries DESC, a.account_number LIMIT 5;
