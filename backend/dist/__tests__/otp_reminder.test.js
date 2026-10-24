import test from "node:test";
import assert from "node:assert/strict";
import { buildOtpReminderEmailContent } from "../services/email.js";
test("OTP follow-up tells users how to find or request a code without exposing one", () => {
    const content = buildOtpReminderEmailContent(1);
    assert.match(content.subject, /StayNest email/i);
    assert.match(content.text, /spam or junk folder/i);
    assert.match(content.text, /request a new code/i);
    assert.match(content.html, /verification screen in the app/i);
    assert.doesNotMatch(content.text, /\b\d{6}\b/);
});
test("second OTP follow-up is clearly labeled as a reminder", () => {
    const content = buildOtpReminderEmailContent(2);
    assert.match(content.subject, /reminder/i);
});
//# sourceMappingURL=otp_reminder.test.js.map