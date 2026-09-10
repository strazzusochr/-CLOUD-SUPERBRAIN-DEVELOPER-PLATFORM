ALTER TABLE builds ADD COLUMN prompt_sha256 TEXT;

UPDATE builds
SET prompt = '[REDACTED]'
WHERE prompt <> '[REDACTED]';
