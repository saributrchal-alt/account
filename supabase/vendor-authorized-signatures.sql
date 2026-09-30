ALTER TABLE account_vendor_authorized_persons
ADD COLUMN IF NOT EXISTS signature_url TEXT,
ADD COLUMN IF NOT EXISTS signature_registered_at TIMESTAMPTZ;

GRANT SELECT, INSERT, UPDATE ON account_vendor_authorized_persons TO service_role;
