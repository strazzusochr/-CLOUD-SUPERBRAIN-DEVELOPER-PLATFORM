ALTER TABLE refresh_token_families
  ADD COLUMN expires_at TEXT;

-- Families created before this migration did not carry a server-side expiry.
-- Bind them to their original creation time and revoke every still-active legacy
-- family fail-closed; only post-migration issuance may create an active family.
UPDATE refresh_token_families
SET
  expires_at = strftime('%Y-%m-%dT%H:%M:%fZ', created_at, '+604800 seconds'),
  updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now'),
  revoked_at = CASE
    WHEN revoked_at IS NULL THEN strftime('%Y-%m-%dT%H:%M:%fZ', 'now')
    ELSE revoked_at
  END,
  revocation_reason = CASE
    WHEN revoked_at IS NULL THEN 'refresh_expiry_migration_required'
    ELSE revocation_reason
  END
WHERE expires_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_refresh_token_families_expires_at
  ON refresh_token_families(expires_at);

-- Building this index performs a fail-closed duplicate preflight over every
-- existing row before the invariant is installed. A duplicate aborts the
-- migration; refresh/logout must never resolve an active hash ambiguously.
CREATE UNIQUE INDEX IF NOT EXISTS idx_refresh_token_families_active_token_hash
  ON refresh_token_families(active_token_hash);

-- SQLite cannot add a deployed NOT NULL/CHECK column without rebuilding the
-- table. These triggers enforce the same invariant for every future write:
-- expires_at is canonical UTC and exactly seven days after created_at.
CREATE TRIGGER IF NOT EXISTS trg_refresh_token_families_expiry_insert
BEFORE INSERT ON refresh_token_families
WHEN
  NEW.expires_at IS NULL
  OR strftime('%Y-%m-%dT%H:%M:%fZ', NEW.created_at, '+604800 seconds') IS NULL
  OR NEW.expires_at <> strftime('%Y-%m-%dT%H:%M:%fZ', NEW.created_at, '+604800 seconds')
BEGIN
  SELECT RAISE(ABORT, 'refresh family expiry must equal created_at + 604800 seconds');
END;

CREATE TRIGGER IF NOT EXISTS trg_refresh_token_families_expiry_update
BEFORE UPDATE OF created_at, expires_at ON refresh_token_families
WHEN
  NEW.expires_at IS NULL
  OR strftime('%Y-%m-%dT%H:%M:%fZ', NEW.created_at, '+604800 seconds') IS NULL
  OR NEW.expires_at <> strftime('%Y-%m-%dT%H:%M:%fZ', NEW.created_at, '+604800 seconds')
BEGIN
  SELECT RAISE(ABORT, 'refresh family expiry must remain created_at + 604800 seconds');
END;
