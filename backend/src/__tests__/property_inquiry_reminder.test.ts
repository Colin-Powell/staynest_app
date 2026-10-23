import test from "node:test";
import assert from "node:assert/strict";

import { buildPropertyInquiryReminderContent } from "../services/email.js";

test("property inquiry reminder summarises unprocessed inquiries when a batch is waiting", () => {
  const content = buildPropertyInquiryReminderContent({
    to: "landlord@example.com",
    landlordName: "Grace",
    tenantName: "Sam",
    propertyName: "Nairobi Studio",
    propertyUrl: "https://staynest.top/properties/123",
    message: "Hi, is it still available?",
    pendingCount: 3,
    conversationId: "conv-123",
    messageId: "msg-123",
  });

  assert.match(content.subject, /3 unprocessed inquiries/i);
  assert.match(content.text, /3 unprocessed inquiries/i);
  assert.match(content.html, /3 unprocessed inquiries/i);
  assert.match(content.html, /Nairobi Studio/i);
});
