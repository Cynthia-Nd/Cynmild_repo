"""Portfolio 4 - NoSQL for Cynmild. Uses mongomock (in-memory, pymongo-compatible API);
the same calls run unchanged against MongoDB. Also a graph (networkx) fraud-ring example and key-value session cache."""
import mongomock, random, json, networkx as nx
random.seed(7)
db = mongomock.MongoClient().Cynmild
# Document model: embed recent transactions + KYC + devices in a customer-centric 360 document
for i in range(1, 501):
    db.customer_profiles.insert_one({
        "_id": i, "name": f"Customer {i}", "kyc": {"status": random.choice(["VERIFIED","PENDING"]), "bvn_last4": f"{random.randint(0,9999):04d}"},
        "devices": [{"id": f"dev-{random.randint(1,300)}", "os": random.choice(["Android","iOS"])} for _ in range(random.randint(1,3))],
        "accounts": [{"no": f"30{i:08d}", "type": random.choice(["SAV","WAL"]), "balance": round(random.uniform(1e4,9e5),2)}],
        "recent_txns": [{"ref": f"T{i}-{k}", "amt": round(random.uniform(100,2e5),2), "channel": random.choice(["USSD","MOBILE","WEB"]), "ts": f"2026-10-{random.randint(1,28):02d}"} for k in range(random.randint(1,8))],
    })
print("Documents:", db.customer_profiles.count_documents({}))
print("\nQ1 find one customer 360 view:"); print(json.dumps(db.customer_profiles.find_one({"_id": 42}, {"name":1,"kyc":1,"accounts":1}), indent=1))
print("\nQ2 aggregation - txn volume by channel:")
for r in db.customer_profiles.aggregate([{"$unwind":"$recent_txns"},{"$group":{"_id":"$recent_txns.channel","count":{"$sum":1},"total":{"$sum":"$recent_txns.amt"}}},{"$sort":{"total":-1}}]):
    print(f"  {r['_id']:7s} count={r['count']:4d} total={r['total']:,.2f}")
db.customer_profiles.create_index("devices.id")
print("\nQ3 shared-device lookup (index on devices.id):", db.customer_profiles.count_documents({"devices.id": "dev-17"}), "customers use dev-17")
# Key-value: session / idempotency store (Redis-style semantics)
kv = {}
def put_once(key, val): return kv.setdefault(key, val) is val
print("\nKV idempotency: first request accepted =", put_once("idem:T1", "ok"), "| duplicate retry accepted =", put_once("idem:T1", "ok2"))
# Graph: devices shared between customers -> suspicious rings
G = nx.Graph()
for d in db.customer_profiles.find({}, {"devices":1}):
    for dev in d["devices"]: G.add_edge(f"C{d['_id']}", dev["id"])
comp = sorted((c for c in nx.connected_components(G)), key=len, reverse=True)
print(f"\nGraph: {G.number_of_nodes()} nodes, {G.number_of_edges()} edges; largest component size={len(comp[0])}")
dev_deg = sorted(((n,G.degree(n)) for n in G if n.startswith('dev-')), key=lambda x:-x[1])[:3]
print("Most-shared devices (possible mule/fraud indicators):", dev_deg)
