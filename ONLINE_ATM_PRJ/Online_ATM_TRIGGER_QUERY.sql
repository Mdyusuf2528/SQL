
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";


CREATE OR REPLACE FUNCTION generate_transaction_id_and_timestamp()
RETURNS TRIGGER AS $$
DECLARE
  transaction_id TEXT;
BEGIN
  transaction_id := uuid_generate_v4()::left(replace(gen_random_uuid()::text, '-', ''), 8);
  NEW.transaction_id := transaction_id;
  NEW.timestamp := TO_CHAR(CURRENT_TIMESTAMP, YYYY-MM-DD HH:MI:SS);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER sbi_balance_trigger
  BEFORE UPDATE ON sbi
  FOR EACH ROW
  WHEN (OLD.balance != NEW.balance) -- Only trigger if the balance has actually changed
  EXECUTE FUNCTION generate_transaction_id_and_timestamp();

CREATE TRIGGER sbi_balance_audit_trigger
  AFTER UPDATE ON sbi
  FOR EACH ROW
  WHEN (OLD.balance != NEW.balance)
  EXECUTE FUNCTION audit_sbi_balance();

CREATE OR REPLACE FUNCTION audit_sbi_balance()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO audit (transaction_id,ac_no,name,withdrawn_amount,timestamp)
  VALUES (NEW.transaction_id, NEW.ac_no,new.name,OLD.balance-NEW.balance, NEW.timestamp);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;