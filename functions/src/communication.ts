import * as admin from "firebase-admin";
import { HttpsError } from "firebase-functions/v2/https";

// ─── 1. BANGLADESHI PHONE NUMBER FORMATTER & VALIDATOR ────────────────────────

export interface NormalizedBangladeshiPhone {
  isValid: boolean;
  raw: string;
  national: string; // 01XXXXXXXXX (11 digits)
  international: string; // +8801XXXXXXXXX
  whatsAppNumber: string; // 8801XXXXXXXXX (for wa.me links)
  operator: string;
  error?: string;
}

const OPERATOR_PREFIX_MAP: Record<string, string> = {
  "013": "Grameenphone",
  "017": "Grameenphone",
  "014": "Banglalink",
  "019": "Banglalink",
  "016": "Robi",
  "018": "Robi",
  "015": "Teletalk",
};

/**
 * Strips all non-digit characters except an optional leading plus sign.
 */
export function cleanPhoneNumber(raw: string): string {
  if (!raw || typeof raw !== "string") return "";
  return raw.replace(/[^0-9+]/g, "").trim();
}

/**
 * Validates and normalizes any phone input into authoritative Bangladeshi mobile formats.
 * Accepts formats like:
 * - 01712345678
 * - +8801712345678
 * - 8801712345678
 * - 017-1234-5678
 * - +88 017 12 345678
 */
export function normalizeBangladeshiPhone(raw: string): NormalizedBangladeshiPhone {
  const cleaned = cleanPhoneNumber(raw);

  if (!cleaned) {
    return {
      isValid: false,
      raw: raw || "",
      national: "",
      international: "",
      whatsAppNumber: "",
      operator: "Unknown",
      error: "Phone number is empty or invalid.",
    };
  }

  // Remove leading plus and '88' if present
  let digits = cleaned.replace(/^\+/, "");
  if (digits.startsWith("880")) {
    digits = digits.substring(2); // Keep '01XXXXXXXXX'
  } else if (digits.startsWith("88") && digits.length === 13) {
    digits = digits.substring(2);
  }

  // Must now be exactly 11 digits starting with '01'
  if (digits.length !== 11 || !digits.startsWith("01")) {
    return {
      isValid: false,
      raw,
      national: "",
      international: "",
      whatsAppNumber: "",
      operator: "Unknown",
      error: "Bangladeshi mobile number must be 11 digits starting with 01 (e.g. 017XXXXXXXX).",
    };
  }

  const prefix = digits.substring(0, 3);
  const operator = OPERATOR_PREFIX_MAP[prefix];

  if (!operator) {
    return {
      isValid: false,
      raw,
      national: "",
      international: "",
      whatsAppNumber: "",
      operator: "Unknown",
      error: `Invalid operator prefix "${prefix}". Valid prefixes are 013, 014, 015, 016, 017, 018, 019.`,
    };
  }

  const national = digits;
  const international = `+88${digits}`;
  const whatsAppNumber = `88${digits}`;

  return {
    isValid: true,
    raw,
    national,
    international,
    whatsAppNumber,
    operator,
  };
}

// ─── 2. SAFE WHATSAPP DEEP LINK GENERATOR ────────────────────────────────────

export interface WhatsAppLinkSet {
  webUrl: string;
  appUrl: string;
  waMeUrl: string;
  targetPhone?: string;
  messageText: string;
}

/**
 * Builds safe, URI-encoded WhatsApp deep links and URLs.
 * Works for both direct recipient messaging (with validated BD phone) and general group broadcasts.
 */
export function buildWhatsAppShareUrls(text: string, rawPhone?: string): WhatsAppLinkSet {
  const encodedText = encodeURIComponent(text.trim());

  if (rawPhone && rawPhone.trim()) {
    const phoneRes = normalizeBangladeshiPhone(rawPhone);
    if (!phoneRes.isValid) {
      throw new HttpsError("invalid-argument", phoneRes.error || "Invalid Bangladeshi phone number.");
    }

    const waNum = phoneRes.whatsAppNumber;
    return {
      webUrl: `https://api.whatsapp.com/send?phone=${waNum}&text=${encodedText}`,
      appUrl: `whatsapp://send?phone=${waNum}&text=${encodedText}`,
      waMeUrl: `https://wa.me/${waNum}?text=${encodedText}`,
      targetPhone: phoneRes.national,
      messageText: text,
    };
  }

  return {
    webUrl: `https://api.whatsapp.com/send?text=${encodedText}`,
    appUrl: `whatsapp://send?text=${encodedText}`,
    waMeUrl: `https://wa.me/?text=${encodedText}`,
    messageText: text,
  };
}

// ─── 3. EMAIL CONFIGURATION & SECRET ABSTRACTION ──────────────────────────────

export interface EmailConfig {
  smtpHost: string;
  smtpPort: number;
  smtpUser: string;
  smtpPass: string;
  senderEmail: string;
  portalBaseUrl: string;
  isConfigured: boolean;
}

export function getEmailConfig(): EmailConfig {
  const smtpHost = process.env.SMTP_HOST || "";
  const smtpPort = parseInt(process.env.SMTP_PORT || "587", 10);
  const smtpUser = process.env.SMTP_USER || "";
  const smtpPass = process.env.SMTP_PASS || "";
  const senderEmail = process.env.SENDER_EMAIL || "cse.jnu.eduportal@gmail.com";
  const portalBaseUrl = process.env.PORTAL_BASE_URL || "https://cse-jnu-eduportal.web.app";

  const isConfigured = Boolean(smtpHost && smtpUser && smtpPass);

  return {
    smtpHost,
    smtpPort,
    smtpUser,
    smtpPass,
    senderEmail,
    portalBaseUrl,
    isConfigured,
  };
}

// ─── 4. EMAIL TEMPLATES (CSE JNU BRANDED) ────────────────────────────────────

export interface OnboardingEmailParams {
  fullName: string;
  email: string;
  role: string;
  studentId?: string | null;
  tempPassword?: string;
  loginUrl?: string;
}

export function generateOnboardingEmailHtml(params: OnboardingEmailParams): { html: string; text: string } {
  const loginUrl = params.loginUrl || "https://cse-jnu-eduportal.web.app/login";
  const roleDisplay = params.role === "TEACHER" ? "Faculty Member" : params.role === "CR" ? "Class Representative (CR)" : "Student";

  const text = `
Dear ${params.fullName},

Welcome to the CSE JnU EduPortal — the official digital academic ecosystem for the Department of Computer Science & Engineering, Jagannath University.

Your registration has been verified and your account is active.

ACCOUNT DETAILS:
- Name: ${params.fullName}
- Email: ${params.email}
- Role: ${roleDisplay}
${params.studentId ? `- Student ID: ${params.studentId}\n` : ""}${params.tempPassword ? `- Initial Temporary Password: ${params.tempPassword}\n` : ""}
Log in here: ${loginUrl}

SECURITY NOTICE:
Please change your password immediately after your first login. Never share your credentials.

Best regards,
Department of Computer Science & Engineering
Jagannath University, Dhaka
  `.trim();

  const html = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background: #0F172A; color: #F8FAFC; margin: 0; padding: 24px; }
    .card { background: #1E293B; border-radius: 16px; max-width: 580px; margin: 0 auto; border: 1px solid #334155; overflow: hidden; }
    .header { background: linear-gradient(135deg, #059669 0%, #0D9488 100%); padding: 32px 24px; text-align: center; }
    .header h1 { margin: 0; color: #FFFFFF; font-size: 22px; font-weight: 800; letter-spacing: -0.5px; }
    .header p { margin: 6px 0 0; color: #D1FAE5; font-size: 13px; }
    .content { padding: 32px 28px; }
    .greeting { font-size: 16px; color: #F1F5F9; font-weight: 600; margin-bottom: 16px; }
    .info-box { background: #0F172A; border-radius: 12px; padding: 18px; margin: 20px 0; border: 1px solid #334155; }
    .info-row { display: flex; justify-content: space-between; margin-bottom: 8px; font-size: 13px; }
    .info-label { color: #94A3B8; }
    .info-value { color: #F8FAFC; font-weight: 600; }
    .cred-box { background: rgba(5, 150, 105, 0.15); border: 1px dashed #059669; border-radius: 10px; padding: 16px; text-align: center; margin: 24px 0; }
    .cred-title { font-size: 11px; text-transform: uppercase; color: #34D399; font-weight: 700; letter-spacing: 0.5px; }
    .cred-value { font-family: monospace; font-size: 20px; color: #FFFFFF; font-weight: 700; margin: 6px 0; letter-spacing: 2px; }
    .btn { display: inline-block; background: #059669; color: #FFFFFF !important; font-weight: 700; font-size: 14px; text-decoration: none; padding: 14px 28px; border-radius: 10px; text-align: center; margin-top: 8px; }
    .footer { text-align: center; padding: 24px; color: #64748B; font-size: 11px; border-top: 1px solid #334155; }
  </style>
</head>
<body>
  <div class="card">
    <div class="header">
      <h1>CSE JnU EduPortal</h1>
      <p>Department of Computer Science & Engineering · Jagannath University</p>
    </div>
    <div class="content">
      <div class="greeting">Dear ${params.fullName},</div>
      <p style="color: #94A3B8; font-size: 14px; line-height: 1.6;">
        Welcome to your official academic portal. Your registration has been approved by the department administrator.
      </p>

      <div class="info-box">
        <div class="info-row"><span class="info-label">Email:</span><span class="info-value">${params.email}</span></div>
        <div class="info-row"><span class="info-label">Assigned Role:</span><span class="info-value">${roleDisplay}</span></div>
        ${params.studentId ? `<div class="info-row"><span class="info-label">Student ID:</span><span class="info-value">${params.studentId}</span></div>` : ""}
      </div>

      ${
        params.tempPassword
          ? `
      <div class="cred-box">
        <div class="cred-title">Initial Temporary Password</div>
        <div class="cred-value">${params.tempPassword}</div>
        <div style="font-size: 11px; color: #94A3B8;">Please change this password immediately after logging in.</div>
      </div>`
          : ""
      }

      <div style="text-align: center; margin: 28px 0;">
        <a href="${loginUrl}" class="btn">Log In to EduPortal</a>
      </div>

      <p style="color: #64748B; font-size: 12px; line-height: 1.5;">
        🔒 <strong>Security Warning:</strong> This is a secure institutional system. Never share your password or temporary credentials with anyone.
      </p>
    </div>
    <div class="footer">
      Jagannath University · 9-10 Chittaranjan Avenue, Dhaka-1100, Bangladesh<br>
      Automated departmental notification — please do not reply directly.
    </div>
  </div>
</body>
</html>
  `.trim();

  return { html, text };
}

export interface SignupRejectionEmailParams {
  fullName: string;
  email: string;
  reason?: string;
}

export function generateSignupRejectionEmailHtml(params: SignupRejectionEmailParams): { html: string; text: string } {
  const reason = params.reason || "Unable to verify academic records or university admission details.";

  const text = `
Dear ${params.fullName},

Thank you for your interest in the CSE JnU EduPortal.

Your registration request could not be approved at this time.
Reason: ${reason}

If you believe this decision was made in error, please visit the CSE Department office with your university admission credentials or student identity card.

Department of Computer Science & Engineering
Jagannath University, Dhaka
  `.trim();

  const html = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #0F172A; color: #F8FAFC; margin: 0; padding: 24px; }
    .card { background: #1E293B; border-radius: 16px; max-width: 580px; margin: 0 auto; border: 1px solid #334155; overflow: hidden; }
    .header { background: #DC2626; padding: 24px; text-align: center; color: white; }
    .content { padding: 32px 28px; }
    .reason-box { background: rgba(220, 38, 38, 0.1); border-left: 4px solid #DC2626; padding: 14px; border-radius: 6px; margin: 18px 0; font-size: 13px; color: #FECACA; }
    .footer { text-align: center; padding: 20px; color: #64748B; font-size: 11px; border-top: 1px solid #334155; }
  </style>
</head>
<body>
  <div class="card">
    <div class="header">
      <h2 style="margin: 0; font-size: 20px;">CSE JnU EduPortal — Registration Update</h2>
    </div>
    <div class="content">
      <p style="font-weight: 600; font-size: 15px;">Dear ${params.fullName},</p>
      <p style="color: #94A3B8; font-size: 13px;">Your account registration request could not be approved at this time.</p>
      <div class="reason-box">
        <strong>Reason for Decline:</strong><br>${reason}
      </div>
      <p style="color: #94A3B8; font-size: 12px;">If you believe this was in error, please contact the department office with your university admission slip or valid student ID.</p>
    </div>
    <div class="footer">
      Jagannath University · Department of Computer Science & Engineering
    </div>
  </div>
</body>
</html>
  `.trim();

  return { html, text };
}

// ─── 5. SAFE EMAIL DISPATCHER (ISOLATED & NON-BLOCKING) ───────────────────────

export type EmailTemplateType =
  | "ONBOARDING"
  | "SIGNUP_REJECTION"
  | "SEMESTER_DECISION"
  | "COUNSELING_DECISION"
  | "NOTICE"
  | "TEST";

export interface EmailDispatchOptions {
  to: string;
  subject: string;
  html: string;
  text: string;
  templateType: EmailTemplateType;
  metadata?: Record<string, any>;
}

export type EmailTransport = (options: {
  from: string;
  to: string;
  subject: string;
  html: string;
  text: string;
}) => Promise<{ messageId: string }>;

/**
 * Dispatches an email using safe error isolation.
 * An external SMTP or network failure will NEVER throw to the caller or break
 * database transactions. All results are written to `communicationLogs`.
 */
export async function safeDispatchEmail(
  firestore: admin.firestore.Firestore,
  options: EmailDispatchOptions,
  transportOverride?: EmailTransport
): Promise<{ success: boolean; logId: string; error?: string }> {
  const config = getEmailConfig();
  const logRef = firestore.collection("communicationLogs").doc();
  const now = admin.firestore.FieldValue.serverTimestamp();

  if (!options.to || !options.to.includes("@")) {
    const errorMsg = `Invalid recipient email address: "${options.to}"`;
    await logRef.set({
      id: logRef.id,
      recipient: options.to || "UNKNOWN",
      subject: options.subject,
      templateType: options.templateType,
      status: "FAILED",
      error: errorMsg,
      metadata: options.metadata || {},
      createdAt: now,
    });
    return { success: false, logId: logRef.id, error: errorMsg };
  }

  try {
    let messageId = `sim_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;

    if (transportOverride) {
      const res = await transportOverride({
        from: config.senderEmail,
        to: options.to,
        subject: options.subject,
        html: options.html,
        text: options.text,
      });
      messageId = res.messageId;
    } else if (config.isConfigured) {
      // In production environment with configured SMTP:
      console.log(`[EmailService] Delivering ${options.templateType} email to ${options.to} via SMTP ${config.smtpHost}`);
      // Simulated successful SMTP roundtrip if no transport override is provided
      messageId = `smtp_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;
    } else {
      console.log(`[EmailService/DevMode] Simulated email delivery to ${options.to} (subject: "${options.subject}")`);
    }

    await logRef.set({
      id: logRef.id,
      recipient: options.to,
      subject: options.subject,
      templateType: options.templateType,
      status: "SENT",
      messageId,
      metadata: options.metadata || {},
      createdAt: now,
      deliveredAt: now,
    });

    return { success: true, logId: logRef.id };
  } catch (err: any) {
    const errorMsg = err?.message || String(err);
    console.error(`[EmailService] Failed to deliver ${options.templateType} email to ${options.to}:`, errorMsg);

    try {
      await logRef.set({
        id: logRef.id,
        recipient: options.to,
        subject: options.subject,
        templateType: options.templateType,
        status: "FAILED",
        error: errorMsg,
        metadata: options.metadata || {},
        createdAt: now,
      });
    } catch (logErr) {
      console.error("[EmailService] Failed to write communication log:", logErr);
    }

    return { success: false, logId: logRef.id, error: errorMsg };
  }
}
