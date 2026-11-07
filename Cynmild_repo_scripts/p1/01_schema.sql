-- Cynmild Bank & Fintech Platform (simulated) - PostgreSQL 16
CREATE TABLE branch (
  branch_id   SERIAL PRIMARY KEY,
  branch_name VARCHAR(80) NOT NULL UNIQUE,
  city        VARCHAR(60) NOT NULL
);
CREATE TABLE customer (
  customer_id SERIAL PRIMARY KEY,
  full_name   VARCHAR(120) NOT NULL,
  email       VARCHAR(120) NOT NULL UNIQUE,
  phone       VARCHAR(20)  NOT NULL UNIQUE,
  bvn         CHAR(11)     NOT NULL UNIQUE CHECK (bvn ~ '^[0-9]{11}$'),
  kyc_status  VARCHAR(10)  NOT NULL DEFAULT 'PENDING' CHECK (kyc_status IN ('PENDING','VERIFIED','REJECTED')),
  created_at  TIMESTAMP    NOT NULL DEFAULT now()
);
CREATE TABLE account_type (
  type_code   VARCHAR(10) PRIMARY KEY,
  description VARCHAR(60) NOT NULL,
  min_balance NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (min_balance >= 0)
);
CREATE TABLE account (
  account_id     SERIAL PRIMARY KEY,
  account_number CHAR(10) NOT NULL UNIQUE,
  customer_id    INT NOT NULL REFERENCES customer(customer_id) ON DELETE RESTRICT,
  branch_id      INT NOT NULL REFERENCES branch(branch_id),
  type_code      VARCHAR(10) NOT NULL REFERENCES account_type(type_code),
  balance        NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (balance >= 0),
  status         VARCHAR(10) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','FROZEN','CLOSED')),
  opened_at      TIMESTAMP NOT NULL DEFAULT now()
);
CREATE TABLE transaction (
  txn_id       BIGSERIAL PRIMARY KEY,
  txn_ref      UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  txn_type     VARCHAR(12) NOT NULL CHECK (txn_type IN ('DEPOSIT','WITHDRAWAL','TRANSFER','REVERSAL')),
  amount       NUMERIC(14,2) NOT NULL CHECK (amount > 0),
  status       VARCHAR(10) NOT NULL DEFAULT 'SUCCESS' CHECK (status IN ('PENDING','SUCCESS','FAILED','REVERSED')),
  narration    VARCHAR(200),
  reverses_txn BIGINT REFERENCES transaction(txn_id),
  created_at   TIMESTAMP NOT NULL DEFAULT now()
);
-- Double-entry ledger: every txn has >=1 DEBIT/CREDIT line
CREATE TABLE ledger_entry (
  entry_id      BIGSERIAL PRIMARY KEY,
  txn_id        BIGINT NOT NULL REFERENCES transaction(txn_id),
  account_id    INT NOT NULL REFERENCES account(account_id),
  direction     CHAR(1) NOT NULL CHECK (direction IN ('D','C')),
  amount        NUMERIC(14,2) NOT NULL CHECK (amount > 0),
  balance_after NUMERIC(14,2) NOT NULL,
  posted_at     TIMESTAMP NOT NULL DEFAULT now()
);
CREATE TABLE audit_log (
  audit_id   BIGSERIAL PRIMARY KEY,
  table_name VARCHAR(40) NOT NULL,
  record_id  BIGINT NOT NULL,
  action     VARCHAR(10) NOT NULL,
  old_value  JSONB,
  new_value  JSONB,
  changed_at TIMESTAMP NOT NULL DEFAULT now()
);
-- Audit trigger on balance changes
CREATE OR REPLACE FUNCTION trg_audit_balance() RETURNS trigger AS $$
BEGIN
  IF NEW.balance <> OLD.balance THEN
    INSERT INTO audit_log(table_name,record_id,action,old_value,new_value)
    VALUES ('account',OLD.account_id,'UPDATE',
            jsonb_build_object('balance',OLD.balance),jsonb_build_object('balance',NEW.balance));
  END IF;
  RETURN NEW;
END $$ LANGUAGE plpgsql;
CREATE TRIGGER account_balance_audit AFTER UPDATE ON account
FOR EACH ROW EXECUTE FUNCTION trg_audit_balance();
