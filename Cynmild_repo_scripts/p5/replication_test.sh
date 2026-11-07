PRI="psql -h /tmp/pg -p 5433 -U postgres -d Cynmild -t -A"; REP="psql -h /tmp/pg -p 5434 -U postgres -d nairapay -t -A"
echo "Replica in recovery (read-only standby)? $($REP -c 'select pg_is_in_recovery()')"
echo "Primary pg_stat_replication (state | sync_state):"; $PRI -c "select state, sync_state from pg_stat_replication"
$PRI -c "INSERT INTO branch(branch_name,city) VALUES ('Replication Test','Enugu')" >/dev/null
sleep 1
echo "Row inserted on primary visible on replica (count): $($REP -c "select count(*) from branch where branch_name='Replication Test'")"
echo "Write attempted on replica:"; $REP -c "INSERT INTO branch(branch_name,city) VALUES ('X','Y')" 2>&1 | head -1
