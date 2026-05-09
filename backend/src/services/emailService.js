const nodemailer = require('nodemailer');

let transporter = null;
let configWarningPrinted = false;

function isConfigured() {
  return !!(
    process.env.SMTP_HOST &&
    process.env.SMTP_USER &&
    process.env.SMTP_PASS
  );
}

function getTransporter() {
  if (transporter) return transporter;
  if (!isConfigured()) {
    if (!configWarningPrinted) {
      console.warn(
        'Email service is NOT configured. Set SMTP_HOST, SMTP_USER, SMTP_PASS, and SMTP_FROM env vars to enable email delivery. ' +
        'In development, OTP codes will be logged to the console as a fallback.'
      );
      configWarningPrinted = true;
    }
    return null;
  }

  transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port: parseInt(process.env.SMTP_PORT || '587', 10),
    secure: process.env.SMTP_SECURE === 'true',
    auth: {
      user: process.env.SMTP_USER,
      pass: process.env.SMTP_PASS,
    },
  });

  return transporter;
}

async function sendOtpEmail(to, code, language = 'he') {
  const fromAddress = process.env.SMTP_FROM || process.env.SMTP_USER;
  const t = getTransporter();

  if (!t) {
    console.log(`========================================`);
    console.log(`[DEV ONLY] Password reset OTP for ${to}: ${code}`);
    console.log(`Code is valid for 15 minutes.`);
    console.log(`Configure SMTP env vars to send via email.`);
    console.log(`========================================`);
    return { success: false, dev: true };
  }

  const isHebrew = language === 'he';
  const subject = isHebrew ? 'קוד אימות לאיפוס סיסמה - Monity' : 'Password Reset Code - Monity';
  const greeting = isHebrew ? 'שלום' : 'Hello';
  const intro = isHebrew
    ? 'קיבלנו בקשה לאיפוס הסיסמה לחשבון Monity שלך. הקוד שלך הוא:'
    : 'We received a request to reset your Monity password. Your verification code is:';
  const validity = isHebrew
    ? 'הקוד תקף ל-15 דקות.'
    : 'This code is valid for 15 minutes.';
  const ignore = isHebrew
    ? 'אם לא ביקשת איפוס סיסמה, אנא התעלם מאימייל זה.'
    : 'If you did not request a password reset, please ignore this email.';
  const signature = isHebrew ? 'בברכה,\nצוות Monity' : 'Regards,\nThe Monity Team';
  const direction = isHebrew ? 'rtl' : 'ltr';
  const align = isHebrew ? 'right' : 'left';

  const html = `
<!DOCTYPE html>
<html lang="${language}" dir="${direction}">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<title>${subject}</title>
</head>
<body style="margin:0;padding:0;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;background:#f5f5f7;">
  <table role="presentation" cellspacing="0" cellpadding="0" border="0" width="100%" style="background:#f5f5f7;padding:40px 20px;">
    <tr>
      <td align="center">
        <table role="presentation" cellspacing="0" cellpadding="0" border="0" width="100%" style="max-width:520px;background:#ffffff;border-radius:20px;overflow:hidden;box-shadow:0 8px 32px rgba(0,0,0,0.06);">
          <tr>
            <td style="background:linear-gradient(135deg,#0F2027 0%,#203A43 50%,#2C5364 100%);padding:48px 32px;text-align:center;">
              <div style="display:inline-block;width:72px;height:72px;background:linear-gradient(135deg,#0D8B7D,#0FA68B);border-radius:18px;line-height:72px;font-size:36px;color:#ffffff;font-weight:bold;">
                M
              </div>
              <h1 style="margin:24px 0 0;color:#ffffff;font-size:28px;font-weight:700;letter-spacing:0.5px;">Monity</h1>
            </td>
          </tr>
          <tr>
            <td style="padding:40px 32px;text-align:${align};direction:${direction};">
              <h2 style="margin:0 0 12px;color:#1a1a1a;font-size:22px;font-weight:600;">${subject}</h2>
              <p style="margin:0 0 24px;color:#555555;font-size:15px;line-height:1.6;">${greeting},<br/>${intro}</p>
              <div style="background:linear-gradient(135deg,#f7f8fa 0%,#eef0f4 100%);border-radius:14px;padding:28px;text-align:center;margin:24px 0;border:1px solid #e5e7eb;">
                <div style="font-family:'SF Mono',Menlo,Monaco,Consolas,monospace;font-size:38px;font-weight:700;letter-spacing:8px;color:#0F2027;">${code}</div>
              </div>
              <p style="margin:0 0 12px;color:#888888;font-size:13px;line-height:1.6;">${validity}</p>
              <p style="margin:0 0 24px;color:#888888;font-size:13px;line-height:1.6;">${ignore}</p>
              <hr style="border:none;border-top:1px solid #eaeaea;margin:24px 0;" />
              <p style="margin:0;color:#999999;font-size:13px;line-height:1.6;white-space:pre-line;">${signature}</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
  `.trim();

  const text = `${greeting},\n\n${intro}\n\n${code}\n\n${validity}\n\n${ignore}\n\n${signature}`;

  try {
    await t.sendMail({
      from: fromAddress,
      to,
      subject,
      text,
      html,
    });
    return { success: true };
  } catch (err) {
    console.error('Email send error:', err.message);
    console.log(`[FALLBACK] OTP for ${to}: ${code}`);
    return { success: false, error: err.message };
  }
}

module.exports = {
  sendOtpEmail,
  isConfigured,
};
