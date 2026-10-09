const DEFAULT_BASE_URL = "https://opentrust.in/api/v1";
const VERSION = "0.1.0";

/** Base class. Catch this to handle anything that goes wrong talking to OpenTrust. */
export class OpenTrustError extends Error {
  constructor(message, { status, code } = {}) {
    super(message);
    this.name = new.target.name;
    this.status = status;
    this.code = code;
  }
}
export class ConnectionError extends OpenTrustError {}       // network failure or timeout
export class AuthenticationError extends OpenTrustError {}   // 401
export class NoChecksError extends OpenTrustError {}         // 402: allowance used up
export class NotApprovedError extends OpenTrustError {}      // 403
export class DuplicateReportError extends OpenTrustError {}  // 409
export class InvalidRequestError extends OpenTrustError {}   // 422
export class RateLimitError extends OpenTrustError {}        // 429
export class ServerError extends OpenTrustError {}           // 5xx

const ERROR_BY_STATUS = { 401: AuthenticationError, 402: NoChecksError, 403: NotApprovedError, 409: DuplicateReportError, 422: InvalidRequestError, 429: RateLimitError };

function toLookup(h, extra = {}) {
  return {
    phoneLast4: h.phone_last4,
    reported: (h.report_count ?? 0) > 0,
    reportCount: h.report_count ?? 0,
    reports: (h.reports ?? []).map((r) => ({
      reasonCode: r.reason_code,
      reason: r.reason,
      notes: r.notes ?? null,
      reportedAt: r.reported_at,
      reporterVerified: r.reporter_verified,
    })),
    notice: extra.notice ?? h.notice,
    checksRemaining: extra.checksRemaining ?? h.checks_remaining,
  };
}

export class OpenTrust {
  /**
   * @param {{ apiKey?: string, baseUrl?: string, timeoutMs?: number, fetch?: typeof fetch }} [options]
   */
  constructor({ apiKey = globalThis.process?.env?.OPENTRUST_API_KEY, baseUrl = globalThis.process?.env?.OPENTRUST_BASE_URL ?? DEFAULT_BASE_URL, timeoutMs = 5000, fetch: fetchImpl = globalThis.fetch } = {}) {
    if (!apiKey) throw new TypeError("apiKey is required (or set OPENTRUST_API_KEY)");
    this.apiKey = apiKey;
    this.baseUrl = baseUrl.replace(/\/$/, "");
    this.timeoutMs = timeoutMs;
    this.fetch = fetchImpl;
  }

  /** Check one number. Uses one check from your allowance. */
  async lookup(phone) {
    return toLookup(await this.#request("POST", "/lookups", { phone }));
  }

  /** Check up to 100 numbers. All or nothing: if you don't have enough checks, none are used. */
  async lookupMany(phones) {
    const body = await this.#request("POST", "/lookups/batch", { phones });
    return body.results.map((r) => toLookup(r, { notice: body.notice, checksRemaining: body.checks_remaining }));
  }

  /** Share an experience with a number. Optional, and doesn't change your allowance. */
  async report({ phone, reasonCode, notes }) {
    const body = await this.#request("POST", "/reports", { phone, reason_code: reasonCode, ...(notes ? { notes } : {}) });
    return { id: body.id, phoneLast4: body.phone_last4 };
  }

  /** Your remaining checks and usage. */
  async me() {
    const b = await this.#request("GET", "/me");
    return { merchant: b.merchant, checksRemaining: b.checks_remaining, reportsSubmitted: b.reports_submitted };
  }

  async #request(method, path, payload) {
    const headers = { Authorization: `Bearer ${this.apiKey}`, Accept: "application/json", "User-Agent": `opentrust-node/${VERSION}` };
    if (payload) headers["Content-Type"] = "application/json";
    let res;
    try {
      res = await this.fetch(`${this.baseUrl}${path}`, { method, headers, body: payload ? JSON.stringify(payload) : undefined, signal: AbortSignal.timeout(this.timeoutMs) });
    } catch (e) {
      throw new ConnectionError(`could not reach OpenTrust: ${e.name}: ${e.message}`);
    }
    const body = await res.json().catch(() => ({}));
    if (!res.ok) {
      const err = body?.error ?? {};
      const Klass = ERROR_BY_STATUS[res.status] ?? (res.status >= 500 ? ServerError : OpenTrustError);
      throw new Klass(err.message ?? `OpenTrust returned HTTP ${res.status}`, { status: res.status, code: err.code });
    }
    return body;
  }
}

export default OpenTrust;
