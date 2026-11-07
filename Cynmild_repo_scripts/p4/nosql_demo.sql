-- Document store: customer-360 documents in JSONB (MongoDB-style schema), with GIN index
DROP TABLE IF EXISTS customer_profiles;
CREATE TABLE customer_profiles (id INT PRIMARY KEY, doc JSONB NOT NULL);
INSERT INTO customer_profiles
SELECT g, jsonb_build_object('name','Customer '||g,
  'kyc', jsonb_build_object('status',(ARRAY['VERIFIED','PENDING'])[1+g%2]),
  'devices', (SELECT jsonb_agg(jsonb_build_object('id','dev-'||(1+((g*k*7)%300)),'os',(ARRAY['Android','iOS'])[1+(g+k)%2])) FROM generate_series(1,1+g%3) k),
  'accounts', jsonb_build_array(jsonb_build_object('no',lpad(g::text,10,'0'),'type','WAL','balance',round((random()*900000)::numeric,2))),
  'recent_txns', (SELECT jsonb_agg(jsonb_build_object('ref','T'||g||'-'||k,'amt',round((random()*200000)::numeric,2),'channel',(ARRAY['USSD','MOBILE','WEB'])[1+(g+k)%3])) FROM generate_series(1,1+g%6) k))
FROM generate_series(1,5000) g;
CREATE INDEX idx_prof_gin ON customer_profiles USING GIN (doc jsonb_path_ops);
\echo '--- Q1 point read of one customer 360 document (no joins)'
SELECT doc->'name' name, doc->'kyc' kyc, doc->'accounts' accounts FROM customer_profiles WHERE id=42;
\echo '--- Q2 aggregation: volume by channel (equivalent of $unwind + $group)'
SELECT t->>'channel' channel, count(*) n, round(sum((t->>'amt')::numeric),2) total
FROM customer_profiles, jsonb_array_elements(doc->'recent_txns') t GROUP BY 1 ORDER BY total DESC;
\echo '--- Q3 containment query on embedded array using GIN (like find({"devices.id":"dev-17"}))'
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF) SELECT count(*) FROM customer_profiles WHERE doc @> '{"devices":[{"id":"dev-17"}]}';
\echo '--- Graph model: customer-device edges, find customers sharing a device with customer 10 (2-hop)'
WITH edges AS (SELECT p.id cust, d->>'id' dev FROM customer_profiles p, jsonb_array_elements(p.doc->'devices') d)
SELECT DISTINCT e2.cust AS linked_customer, e1.dev AS via_device FROM edges e1 JOIN edges e2 ON e1.dev=e2.dev AND e1.cust<>e2.cust WHERE e1.cust=10 ORDER BY 1 LIMIT 8;
\echo '--- Most-shared devices (fraud/mule indicator)'
WITH edges AS (SELECT p.id cust, d->>'id' dev FROM customer_profiles p, jsonb_array_elements(p.doc->'devices') d)
SELECT dev, count(DISTINCT cust) customers FROM edges GROUP BY dev ORDER BY customers DESC, dev LIMIT 3;
