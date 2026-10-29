BEGIN;

ALTER TABLE users ADD COLUMN IF NOT EXISTS is_suspended boolean NOT NULL DEFAULT false;
UPDATE users
SET settings = COALESCE(settings, '{}'::jsonb) || '{"push_permission_granted": false}'::jsonb
WHERE settings->>'push_permission_granted' IS NULL;

WITH ranked_tokens AS (
  SELECT id,
         row_number() OVER (
           PARTITION BY fcm_token
           ORDER BY last_seen_at DESC NULLS LAST, created_at DESC, id
         ) AS token_rank
  FROM users
  WHERE fcm_token IS NOT NULL
)
UPDATE users u
SET fcm_token = NULL
FROM ranked_tokens r
WHERE u.id = r.id AND r.token_rank > 1;

CREATE UNIQUE INDEX IF NOT EXISTS users_fcm_token_unique_idx
  ON users(fcm_token) WHERE fcm_token IS NOT NULL;

CREATE TABLE IF NOT EXISTS promotional_push_campaigns (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text,
  admin_id uuid REFERENCES users(id) ON DELETE SET NULL,
  property_id uuid REFERENCES properties(id) ON DELETE SET NULL,
  title varchar(80) NOT NULL,
  body varchar(180) NOT NULL,
  image_url text NOT NULL,
  audience jsonb NOT NULL DEFAULT '{}'::jsonb,
  status text NOT NULL DEFAULT 'queued',
  eligible_count integer NOT NULL DEFAULT 0,
  submitted_count integer NOT NULL DEFAULT 0,
  failed_count integer NOT NULL DEFAULT 0,
  skipped_count integer NOT NULL DEFAULT 0,
  idempotency_key varchar(128) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  sent_at timestamptz,
  completed_at timestamptz,
  failure_summary text,
  CONSTRAINT promotional_push_campaigns_status_chk
    CHECK (status IN ('queued', 'processing', 'completed', 'completed_with_errors', 'failed')),
  CONSTRAINT promotional_push_campaigns_idempotency_chk
    CHECK (length(idempotency_key) BETWEEN 1 AND 128)
);

CREATE UNIQUE INDEX IF NOT EXISTS promotional_push_campaigns_admin_idempotency_idx
  ON promotional_push_campaigns(admin_id, idempotency_key);
CREATE INDEX IF NOT EXISTS promotional_push_campaigns_created_idx
  ON promotional_push_campaigns(created_at DESC);
CREATE INDEX IF NOT EXISTS promotional_push_campaigns_status_idx
  ON promotional_push_campaigns(status, created_at);

CREATE TABLE IF NOT EXISTS promotional_push_deliveries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id uuid NOT NULL REFERENCES promotional_push_campaigns(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'pending',
  fcm_message_id text,
  attempt_count integer NOT NULL DEFAULT 0,
  last_attempt_at timestamptz,
  error_category varchar(80),
  error_detail varchar(240),
  opened_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT promotional_push_deliveries_status_chk
    CHECK (status IN ('pending', 'sending', 'submitted', 'failed', 'skipped')),
  CONSTRAINT promotional_push_deliveries_campaign_user_idx
    UNIQUE (campaign_id, user_id)
);

CREATE INDEX IF NOT EXISTS promotional_push_deliveries_pending_idx
  ON promotional_push_deliveries(campaign_id, status, created_at);
CREATE INDEX IF NOT EXISTS promotional_push_deliveries_user_idx
  ON promotional_push_deliveries(user_id, campaign_id);

COMMIT;