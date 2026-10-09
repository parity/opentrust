export interface OpenTrustOptions {
  /** Defaults to process.env.OPENTRUST_API_KEY */
  apiKey?: string;
  baseUrl?: string;
  /** Default 5000 */
  timeoutMs?: number;
  fetch?: typeof fetch;
}

export interface Report {
  reasonCode: string;
  /** Human-readable description of what the merchant observed */
  reason: string;
  notes: string | null;
  reportedAt: string;
  reporterVerified: boolean;
}

/** Reports are unverified observations from individual merchants, not a finding about anyone. */
export interface Lookup {
  phoneLast4: string;
  reported: boolean;
  reportCount: number;
  reports: Report[];
  /** Keep this in front of anyone who sees the result */
  notice: string;
  checksRemaining: number;
}

export class OpenTrust {
  constructor(options?: OpenTrustOptions);
  lookup(phone: string): Promise<Lookup>;
  lookupMany(phones: string[]): Promise<Lookup[]>;
  report(input: { phone: string; reasonCode: string; notes?: string }): Promise<{ id: number; phoneLast4: string }>;
  me(): Promise<{ merchant: string; checksRemaining: number; reportsSubmitted: number }>;
}
export default OpenTrust;

export class OpenTrustError extends Error { status?: number; code?: string }
export class ConnectionError extends OpenTrustError {}
export class AuthenticationError extends OpenTrustError {}
export class NoChecksError extends OpenTrustError {}
export class NotApprovedError extends OpenTrustError {}
export class DuplicateReportError extends OpenTrustError {}
export class InvalidRequestError extends OpenTrustError {}
export class RateLimitError extends OpenTrustError {}
export class ServerError extends OpenTrustError {}
