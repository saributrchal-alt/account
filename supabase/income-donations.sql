-- Income ledger for temple donations
CREATE TABLE IF NOT EXISTS account_income (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  income_date DATE NOT NULL,
  source_type TEXT NOT NULL DEFAULT 'donation',
  source_id TEXT,
  donor_name TEXT,
  category TEXT,
  purpose TEXT,
  amount NUMERIC(12,2) NOT NULL CHECK (amount > 0),
  note TEXT,
  verification_status TEXT,
  source_created_at TIMESTAMPTZ,
  imported_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_account_income_source
ON account_income(source_type, source_id)
WHERE source_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_account_income_date
ON account_income(income_date DESC);

ALTER TABLE account_income ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE ON account_income TO service_role;

CREATE OR REPLACE VIEW account_financial_summary AS
SELECT
  COALESCE((SELECT SUM(amount) FROM account_income),0)::NUMERIC(14,2) AS total_income,
  COALESCE((SELECT SUM(amount) FROM account_expense_payments),0)::NUMERIC(14,2) AS total_expense,
  (COALESCE((SELECT SUM(amount) FROM account_income),0) -
   COALESCE((SELECT SUM(amount) FROM account_expense_payments),0))::NUMERIC(14,2) AS net_balance;

GRANT SELECT ON account_financial_summary TO service_role;
