CREATE OR REPLACE PROCEDURE sp_transfer(p_from CHAR(10), p_to CHAR(10), p_amt NUMERIC, p_narr TEXT)
LANGUAGE plpgsql AS $$
DECLARE v_from account%ROWTYPE; v_to account%ROWTYPE; v_txn BIGINT; v_min NUMERIC;
BEGIN
  IF p_amt <= 0 THEN RAISE EXCEPTION 'Amount must be positive'; END IF;
  IF p_from = p_to THEN RAISE EXCEPTION 'Cannot transfer to same account'; END IF;
  -- Lock both rows in a fixed order (account_number) to prevent deadlocks
  PERFORM 1 FROM account WHERE account_number IN (p_from,p_to) ORDER BY account_number FOR UPDATE;
  SELECT * INTO v_from FROM account WHERE account_number=p_from;
  SELECT * INTO v_to   FROM account WHERE account_number=p_to;
  IF v_from.status<>'ACTIVE' OR v_to.status<>'ACTIVE' THEN RAISE EXCEPTION 'Account not ACTIVE'; END IF;
  SELECT min_balance INTO v_min FROM account_type WHERE type_code=v_from.type_code;
  IF v_from.balance - p_amt < v_min THEN RAISE EXCEPTION 'Insufficient funds (min balance %)', v_min; END IF;
  INSERT INTO transaction(txn_type,amount,status,narration) VALUES('TRANSFER',p_amt,'SUCCESS',p_narr) RETURNING txn_id INTO v_txn;
  UPDATE account SET balance=balance-p_amt WHERE account_id=v_from.account_id;
  UPDATE account SET balance=balance+p_amt WHERE account_id=v_to.account_id;
  INSERT INTO ledger_entry(txn_id,account_id,direction,amount,balance_after) VALUES
    (v_txn,v_from.account_id,'D',p_amt,v_from.balance-p_amt),
    (v_txn,v_to.account_id,'C',p_amt,v_to.balance+p_amt);
END $$;
