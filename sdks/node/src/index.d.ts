export interface OpenTrustOptions {
  /** Defaults to process.env.OPENTRUST_API_KEY */
  apiKey?: string;
  baseUrl?: string;
  /** Default 5000 */
  timeoutMs?: number;
  fetch?: typeof fetch;
  /** Send the SHA-256 of each number instead of the number. Limits what is sent; does not make a number anonymous. Default false */
  hashNumbers?: boolean;
}

export interface Report {
  reasonCode: string;
  /** Human-readable description of what the merchant observed */
  reason: string;
  notes: string | null;
  /** The date the merchant says it happened (YYYY-MM-DD), if they said */
  incidentAt: string | null;
  /** Who the reporter says confirmed it (not verified by OpenTrust), or null */
  confirmedBy: "bank" | "payment_gateway" | "law_enforcement" | null;
  reportedAt: string;
  reporterVerified: boolean;
}

/** Reports are unverified observations from individual merchants, not a finding about anyone. */
export interface Lookup {
  /** Empty when the number was sent as a hash: we never saw it */
  phoneLast4: string | null;
  /** Set when the number was sent as a hash */
  phoneSha256: string | null;
  reported: boolean;
  /** Reports from OTHER merchants only */
  reportCount: number;
  /** True when you have shared this number yourself */
  ownReport: boolean;
  reports: Report[];
  /** Keep this in front of anyone who sees the result */
  notice: string;
  checksRemaining: number;
}

export interface ReportInput { phone: string; reasonCode: string; notes?: string; /** A Date or an ISO 8601 string; not in the future */ incidentAt?: Date | string; /** Only if they told you it was confirmed; shown to other merchants */ confirmedBy?: "bank" | "payment_gateway" | "law_enforcement"; /** Private reference for administrators, never shown; needs confirmedBy */ evidenceRef?: string }
export interface BatchResult {
  index: number;
  status: "recorded" | "duplicate" | "invalid";
  id: number | null;
  phoneLast4: string | null;
  errorCode: string | null;
  errorMessage: string | null;
}
export interface ReasonCode { code: string; group: string; label: string; description: string; /** When to use this code */ useWhen: string; /** When not to */ notWhen: string }

export class OpenTrust {
  constructor(options?: OpenTrustOptions);
  lookup(phone: string): Promise<Lookup>;
  lookupMany(phones: string[]): Promise<Lookup[]>;
  report(input: ReportInput): Promise<{ id: number; phoneLast4: string }>;
  /** 1 to 100 reports; one bad row never stops the rest */
  reportMany(reports: ReportInput[]): Promise<BatchResult[]>;
  /** Rejects with NotFoundError if you have no active report for that number */
  withdrawReport(phone: string): Promise<{ phoneLast4: string; status: "withdrawn" }>;
  reasonCodes(): Promise<ReasonCode[]>;
  /** Development aid: asks OpenTrust whether it computes the same SHA-256 as this library. Sends the number: use a test number. */
  verifyHashing(testPhone: string): Promise<{ phone: string; phone_sha256: string; match: boolean }>;
  me(): Promise<{ merchant: string; checksRemaining: number; reportsSubmitted: number }>;
}
export default OpenTrust;

/** "+91" followed by the ten digits. Throws InvalidPhoneError for anything that is not an Indian mobile number. */
export function normalizePhone(raw: string): string;
/** The 64 lowercase hex characters OpenTrust expects as phone_sha256 */
export function hashPhone(raw: string): string;
/** The length of the text that is hashed (13), sent as phone_length */
export function hashedLength(raw: string): number;
/** The last four digits */
export function last4(raw: string): string;
export class InvalidPhoneError extends TypeError {}

export class OpenTrustError extends Error { status?: number; code?: string }
export class ConnectionError extends OpenTrustError {}
export class AuthenticationError extends OpenTrustError {}
export class NoChecksError extends OpenTrustError {}
export class NotApprovedError extends OpenTrustError {}
export class NotFoundError extends OpenTrustError {}
export class DuplicateReportError extends OpenTrustError {}
export class InvalidRequestError extends OpenTrustError {}
export class RateLimitError extends OpenTrustError {}
export class ServerError extends OpenTrustError {}
