BEGIN;

CREATE TABLE IF NOT EXISTS message_conversations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  participant_one_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  participant_two_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  property_id uuid REFERENCES properties(id) ON DELETE SET NULL,
  context_type text NOT NULL DEFAULT 'general'
    CHECK (context_type IN ('general', 'property')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT message_conversations_participant_order
    CHECK (participant_one_id <= participant_two_id)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_message_conversations_general_pair
  ON message_conversations (participant_one_id, participant_two_id)
  WHERE context_type = 'general';

CREATE UNIQUE INDEX IF NOT EXISTS idx_message_conversations_property_pair
  ON message_conversations (participant_one_id, participant_two_id, property_id)
  WHERE context_type = 'property' AND property_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_message_conversations_property
  ON message_conversations (property_id, updated_at DESC)
  WHERE property_id IS NOT NULL;

ALTER TABLE messages ADD COLUMN IF NOT EXISTS conversation_id uuid;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
      FROM pg_constraint
     WHERE conname = 'messages_conversation_id_fkey'
       AND conrelid = 'messages'::regclass
  ) THEN
    ALTER TABLE messages
      ADD CONSTRAINT messages_conversation_id_fkey
      FOREIGN KEY (conversation_id)
      REFERENCES message_conversations(id)
      ON DELETE CASCADE;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_messages_conversation_history
  ON messages (conversation_id, created_at DESC);

INSERT INTO message_conversations (
  participant_one_id,
  participant_two_id,
  context_type,
  created_at,
  updated_at
)
SELECT LEAST(from_user_id, to_user_id),
       GREATEST(from_user_id, to_user_id),
       'general',
       MIN(created_at),
       MAX(created_at)
  FROM messages
 WHERE conversation_id IS NULL
 GROUP BY LEAST(from_user_id, to_user_id), GREATEST(from_user_id, to_user_id)
ON CONFLICT DO NOTHING;

UPDATE messages AS m
   SET conversation_id = c.id
  FROM message_conversations AS c
 WHERE m.conversation_id IS NULL
   AND c.context_type = 'general'
   AND c.participant_one_id = LEAST(m.from_user_id, m.to_user_id)
   AND c.participant_two_id = GREATEST(m.from_user_id, m.to_user_id);

ALTER TABLE messages ALTER COLUMN conversation_id SET NOT NULL;

COMMIT;