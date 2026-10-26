import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import {
  isPropertyEligibleForMessaging,
  orderConversationParticipants,
} from '../services/conversation_policy.js';

test('participant ordering is stable regardless of who initiated the thread', () => {
  assert.deepEqual(orderConversationParticipants('tenant-id', 'landlord-id'), [
    'landlord-id',
    'tenant-id',
  ]);
  assert.deepEqual(orderConversationParticipants('landlord-id', 'tenant-id'), [
    'landlord-id',
    'tenant-id',
  ]);
});

test('only approved listings can start a property enquiry', () => {
  assert.equal(isPropertyEligibleForMessaging('approved'), true);
  assert.equal(isPropertyEligibleForMessaging('APPROVED'), true);
  assert.equal(isPropertyEligibleForMessaging('pending_review'), false);
  assert.equal(isPropertyEligibleForMessaging('unpublished'), false);
  assert.equal(isPropertyEligibleForMessaging(null), false);
});

test('migration preserves general threads and uniquely scopes property threads', () => {
  const migrationPath = fileURLToPath(
    new URL('../../scripts/add-message-conversations.sql', import.meta.url),
  );
  const sql = readFileSync(migrationPath, 'utf8');

  assert.match(sql, /property_id uuid REFERENCES properties\(id\) ON DELETE SET NULL/);
  assert.match(sql, /idx_message_conversations_general_pair[\s\S]*?WHERE context_type = 'general'/);
  assert.match(sql, /idx_message_conversations_property_pair[\s\S]*?property_id\)[\s\S]*?WHERE context_type = 'property'/);
  assert.match(sql, /WHERE conversation_id IS NULL[\s\S]*?GROUP BY LEAST/);
  assert.match(sql, /ALTER TABLE messages ALTER COLUMN conversation_id SET NOT NULL/);
  assert.match(sql, /ON DELETE CASCADE/);
});

test('message actions migration preserves independent visibility and reply links', () => {
  const migrationPath = fileURLToPath(
    new URL('../../scripts/add-message-actions.sql', import.meta.url),
  );
  const sql = readFileSync(migrationPath, 'utf8');

  assert.match(sql, /CREATE TABLE IF NOT EXISTS message_user_deletions/);
  assert.match(sql, /deleted_for_everyone_at timestamptz/);
  assert.match(sql, /delivered_at timestamptz/);
  assert.match(sql, /reply_to_message_id uuid/);
  assert.match(sql, /idempotency_key text/);
  assert.match(sql, /idx_messages_sender_idempotency/);
});