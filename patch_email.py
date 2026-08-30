import re

with open(r'backend/src/services/email.ts', 'r', encoding='utf-8') as f:
    content = f.read()

target = """export async function sendOtpEmail(to: string, code = '000000') {
  const subject = 'Your StayNest verification code';
  const text = `Your verification code is ${code}. If you did not request this, please ignore.`;
  const html = `<p>Your verification code is <strong>${code}</strong>.</p><p>If you did not request this, please ignore this message.</p>`;

  const info = await transporter.sendMail({
    from: env.emailFrom || env.smtpUser,
    to,
    subject,
    text,
    html,
  });

  return info;
}"""

replacement = """export async function sendOtpEmail(to: string, code = '000000') {
  const subject = `StayNest Security: Your OTP Verification Code [${code}]`;
  const text = `Hello,\\n\\nThank you for choosing StayNest!\\n\\nTo complete your secure verification, please use the following one-time password (OTP):\\n\\n${code}\\n\\nThis code will expire in 10 minutes. For your security, do not share this code with anyone.\\n\\nIf you did not request this verification, you can safely ignore this email.\\n\\nBest regards,\\nThe StayNest Security Team`;
  
  const html = `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e2e8f0; border-radius: 8px;">
      <h2 style="color: #3F37C9; margin-bottom: 20px;">StayNest Security Verification</h2>
      <p style="color: #4a5568; font-size: 16px; line-height: 1.5;">Hello,</p>
      <p style="color: #4a5568; font-size: 16px; line-height: 1.5;">Thank you for using StayNest. To complete your secure verification, please use the following one-time password (OTP):</p>
      <div style="background-color: #f7fafc; border: 1px solid #e2e8f0; border-radius: 4px; padding: 15px; margin: 25px 0; text-align: center;">
        <span style="font-size: 24px; font-weight: bold; letter-spacing: 5px; color: #2d3748;">${code}</span>
      </div>
      <p style="color: #4a5568; font-size: 16px; line-height: 1.5;">This code will expire in 10 minutes. For your security, do not share this code with anyone.</p>
      <p style="color: #718096; font-size: 14px; margin-top: 30px;">If you did not request this verification, you can safely ignore this email.</p>
      <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 20px 0;">
      <p style="color: #a0aec0; font-size: 12px; text-align: center;">This is an automated message from StayNest. Please do not reply directly to this email.</p>
    </div>
  `;

  const info = await transporter.sendMail({
    from: `"StayNest Security" <${env.emailFrom || env.smtpUser}>`,
    to,
    subject,
    text,
    html,
  });

  return info;
}"""

content = content.replace(target, replacement)

with open(r'backend/src/services/email.ts', 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated email.ts with robust template")
