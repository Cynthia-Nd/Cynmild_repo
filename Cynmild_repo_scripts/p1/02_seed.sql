INSERT INTO branch(branch_name,city) VALUES ('Ikeja Main','Lagos'),('Wuse II','Abuja'),('GRA Port Harcourt','Port Harcourt'),('Ring Road','Ibadan');
INSERT INTO account_type VALUES ('SAV','Savings',1000),('CUR','Current',5000),('WAL','Fintech Wallet',0);
-- 20,000 customers, 30,000 accounts, 600,000 transactions (synthetic)
INSERT INTO customer(full_name,email,phone,bvn,kyc_status)
SELECT 'Customer '||g, 'user'||g||'@example.com', '080'||lpad(g::text,8,'0'), lpad((22000000000+g)::text,11,'0'),
       (ARRAY['VERIFIED','VERIFIED','VERIFIED','PENDING','REJECTED'])[1+g%5]
FROM generate_series(1,20000) g;
INSERT INTO account(account_number,customer_id,branch_id,type_code,balance,status)
SELECT lpad((3000000000+g)::text,10,'0'), 1+(g%20000), 1+(g%4), (ARRAY['SAV','CUR','WAL'])[1+g%3],
       round((random()*900000+10000)::numeric,2), (ARRAY['ACTIVE','ACTIVE','ACTIVE','ACTIVE','FROZEN'])[1+g%5]
FROM generate_series(1,30000) g;
INSERT INTO transaction(txn_type,amount,status,narration,created_at)
SELECT (ARRAY['DEPOSIT','WITHDRAWAL','TRANSFER','TRANSFER'])[1+g%4], round((random()*200000+100)::numeric,2),
       (ARRAY['SUCCESS','SUCCESS','SUCCESS','SUCCESS','SUCCESS','SUCCESS','SUCCESS','FAILED','PENDING','SUCCESS'])[1+g%10],
       'Seed txn '||g, now() - (random()*365||' days')::interval
FROM generate_series(1,600000) g;
INSERT INTO ledger_entry(txn_id,account_id,direction,amount,balance_after,posted_at)
SELECT t.txn_id, 1+(t.txn_id*7 % 30000), CASE WHEN t.txn_type='DEPOSIT' THEN 'C' ELSE 'D' END, t.amount, 0, t.created_at
FROM transaction t;
INSERT INTO ledger_entry(txn_id,account_id,direction,amount,balance_after,posted_at)
SELECT t.txn_id, 1+(t.txn_id*13 % 30000), 'C', t.amount, 0, t.created_at FROM transaction t WHERE t.txn_type='TRANSFER';
ANALYZE;
