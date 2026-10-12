const DEFAULT_BASE_URL = "https://opentrust.in/api/v1";
const VERSION = "0.2.0";

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
export class NotFoundError extends OpenTrustError {}         // 404: no active report of yours for that number (withdrawing)
export class DuplicateReportError extends OpenTrustError {}  // 409
export class InvalidRequestError extends OpenTrustError {}   // 422
export class RateLimitError extends OpenTrustError {}        // 429
export class ServerError extends OpenTrustError {}           // 5xx

const ERROR_BY_STATUS = { 401: AuthenticationError, 402: NoChecksError, 403: NotApprovedError, 404: NotFoundError, 409: DuplicateReportError, 422: InvalidRequestError, 429: RateLimitError };

function toPayload({ phone, reasonCode, notes, incidentAt, confirmedBy, evidenceRef }) {
  const incident = incidentAt instanceof Date ? incidentAt.toISOString().slice(0, 10) : incidentAt;
  return { phone, reason_code: reasonCode, ...(notes ? { notes } : {}), ...(incident ? { incident_at: incident } : {}), ...(confirmedBy ? { confirmed_by: confirmedBy } : {}), ...(evidenceRef ? { evidence_ref: evidenceRef } : {}) };
}

function toLookup(h, extra = {}) {
  return {
    phoneLast4: h.phone_last4,
    reported: (h.report_count ?? 0) > 0,
    reportCount: h.report_count ?? 0,
    ownReport: h.own_report === true,
    reports: (h.reports ?? []).map((r) => ({
      reasonCode: r.reason_code,
      reason: r.reason,
      notes: r.notes ?? null,
      incidentAt: r.incident_at ?? null,
      confirmedBy: r.confirmed_by ?? null,
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

  /**
   * Share an experience with a number. Optional, and doesn't change your allowance.
   * incidentAt: when it happened (a Date or an ISO 8601 string); can't be in the future.
   */
  async report(report) {
    const body = await this.#request("POST", "/reports", toPayload(report));
    return { id: body.id, phoneLast4: body.phone_last4 };
  }

  /**
   * Share up to 100 experiences at once. Each is handled on its own, so one bad row never stops the rest.
   * Resolves to one result per report, in order: status is "recorded", "duplicate" (already shared; treat as done) or "invalid".
   */
  async reportMany(reports) {
    if (!Array.isArray(reports) || reports.length < 1 || reports.length > 100) throw new RangeError("reportMany takes 1 to 100 reports");
    const body = await this.#request("POST", "/reports/batch", { reports: reports.map(toPayload) });
    return body.results.map((r) => ({
      index: r.index, status: r.status, id: r.id ?? null, phoneLast4: r.phone_last4 ?? null,
      errorCode: r.error?.code ?? null, errorMessage: r.error?.message ?? null,
    }));
  }

  /** Withdraw your own report for a number. Rejects with NotFoundError if you have no active report for it. */
  async withdrawReport(phone) {
    const body = await this.#request("DELETE", "/reports", { phone });
    return { phoneLast4: body.phone_last4, status: body.status };
  }

  /** The reason codes with their labels and descriptions. */
  async reasonCodes() {
    const body = await this.#request("GET", "/reason_codes");
    return body.reason_codes.map((c) => ({ code: c.code, group: c.group, label: c.label, description: c.description, useWhen: c.use_when, notWhen: c.not_when }));
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
