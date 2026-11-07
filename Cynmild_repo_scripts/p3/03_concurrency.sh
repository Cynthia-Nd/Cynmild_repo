P="psql -h /tmp/pg -p 5433 -U postgres -d Cynmild -q -t -A"
$P -c "UPDATE account SET balance=100000 WHERE account_number='3000000001'"
echo "## Without locking: two sessions each read balance, compute new value in app, then write (lost update)"
( $P <<SQL
BEGIN; SELECT balance FROM account WHERE account_number='3000000001'; SELECT pg_sleep(2);
UPDATE account SET balance = 100000 - 30000 WHERE account_number='3000000001'; COMMIT;
SQL
) > /dev/null &
sleep 0.5
$P <<SQL > /dev/null
BEGIN; SELECT balance FROM account WHERE account_number='3000000001';
UPDATE account SET balance = 100000 - 20000 WHERE account_number='3000000001'; COMMIT;
SQL
wait
echo -n "Final balance (expected 50000 after two debits): "; $P -c "SELECT balance FROM account WHERE account_number='3000000001'"
$P -c "UPDATE account SET balance=100000 WHERE account_number='3000000001'"
echo "## With SELECT ... FOR UPDATE (pessimistic lock): second session waits, reads fresh value"
( $P <<SQL
BEGIN; SELECT balance FROM account WHERE account_number='3000000001' FOR UPDATE; SELECT pg_sleep(2);
UPDATE account SET balance = balance - 30000 WHERE account_number='3000000001'; COMMIT;
SQL
) > /dev/null &
sleep 0.5
S=$(date +%s.%N)
$P <<SQL > /dev/null
BEGIN; SELECT balance FROM account WHERE account_number='3000000001' FOR UPDATE;
UPDATE account SET balance = balance - 20000 WHERE account_number='3000000001'; COMMIT;
SQL
E=$(date +%s.%N); wait
echo -n "Final balance: "; $P -c "SELECT balance FROM account WHERE account_number='3000000001'"
echo "Second session blocked for $(echo "$E - $S" | bc) seconds"
echo "## SERIALIZABLE: write-skew style conflict raises serialization failure"
$P -c "UPDATE account SET balance=100000 WHERE account_number='3000000001'"
( $P <<SQL
BEGIN ISOLATION LEVEL SERIALIZABLE; SELECT sum(balance) FROM account WHERE account_number IN ('3000000001','3000000002'); SELECT pg_sleep(2);
UPDATE account SET balance=balance-1 WHERE account_number='3000000001'; COMMIT;
SQL
) 2>&1 | sed 's/^/S1: /' &
sleep 0.5
$P <<SQL 2>&1 | sed 's/^/S2: /'
BEGIN ISOLATION LEVEL SERIALIZABLE; SELECT sum(balance) FROM account WHERE account_number IN ('3000000001','3000000002');
UPDATE account SET balance=balance-1 WHERE account_number='3000000002'; COMMIT;
SQL
wait
