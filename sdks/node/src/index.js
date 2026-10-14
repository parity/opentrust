import { createHash } from "node:crypto";

const DEFAULT_BASE_URL = "https://opentrust.in/api/v1";
const VERSION = "0.3.0";

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
/** Thrown before anything is sent: the value is not an Indian mobile number, so it cannot be checked or hashed. */
export class InvalidPhoneError extends TypeError {}

/**
 * "+91" followed by the ten digits. OpenTrust accepts either a number or its SHA-256, and a hash only matches if it is computed
 * exactly like this: keep the digits, drop a leading 91 (12 digits) or 0 (11 digits), leave 10 digits starting 6-9, prefix "+91".
 * A hash that does not match simply finds nothing, so use these helpers rather than hashing by hand.
 */
export function normalizePhone(raw) {
  let digits = String(raw ?? "").replace(/\D/g, "");
  if (digits.length === 12 && digits.startsWith("91")) digits = digits.slice(2);
  if (digits.length === 11 && digits.startsWith("0")) digits = digits.slice(1);
  if (!/^[6-9]\d{9}$/.test(digits)) throw new InvalidPhoneError("not a valid Indian mobile number");
  return `+91${digits}`;
}

/** The 64 lowercase hex characters OpenTrust expects as phone_sha256: SHA-256 of normalizePhone(raw). */
export function hashPhone(raw) {
  return createHash("sha256").update(normalizePhone(raw)).digest("hex");
}

/** The length of the text that is hashed (13), sent as phone_length. OpenTrust refuses any other value, which catches hashes of a differently written number. */
export function hashedLength(raw) {
  return normalizePhone(raw).length;
}

/** The last four digits, sent with a hashed report so merchants and admins have something to recognise it by. */
export function last4(raw) {
  return normalizePhone(raw).slice(-4);
}

const ERROR_BY_STATUS = { 401: AuthenticationError, 402: NoChecksError, 403: NotApprovedError, 404: NotFoundError, 409: DuplicateReportError, 422: InvalidRequestError, 429: RateLimitError };

/** The number, or (when hashing) its SHA-256 and, for a report, its last four digits. */
function numberFields(phone, hashNumbers, withLast4 = false) {
  if (!hashNumbers) return { phone };
  return { phone_sha256: hashPhone(phone), phone_length: hashedLength(phone), ...(withLast4 ? { phone_last4: last4(phone) } : {}) };
}

function toPayload({ phone, reasonCode, notes, incidentAt, confirmedBy, evidenceRef }, hashNumbers = false) {
  const incident = incidentAt instanceof Date ? incidentAt.toISOString().slice(0, 10) : incidentAt;
  return { ...numberFields(phone, hashNumbers, true), reason_code: reasonCode, ...(notes ? { notes } : {}), ...(incident ? { incident_at: incident } : {}), ...(confirmedBy ? { confirmed_by: confirmedBy } : {}), ...(evidenceRef ? { evidence_ref: evidenceRef } : {}) };
}

function toLookup(h, extra = {}) {
  return {
    phoneLast4: h.phone_last4 ?? null,
    phoneSha256: h.phone_sha256 ?? null,
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
   * hashNumbers: send the SHA-256 of each number instead of the number, so OpenTrust never receives it. A hash can in principle be
   * reversed by brute force, so this limits what is sent; it does not make a number anonymous.
   * @param {{ apiKey?: string, baseUrl?: string, timeoutMs?: number, fetch?: typeof fetch, hashNumbers?: boolean }} [options]
   */
  constructor({ apiKey = globalThis.process?.env?.OPENTRUST_API_KEY, baseUrl = globalThis.process?.env?.OPENTRUST_BASE_URL ?? DEFAULT_BASE_URL, timeoutMs = 5000, fetch: fetchImpl = globalThis.fetch, hashNumbers = false } = {}) {
    if (!apiKey) throw new TypeError("apiKey is required (or set OPENTRUST_API_KEY)");
    this.apiKey = apiKey;
    this.baseUrl = baseUrl.replace(/\/$/, "");
    this.timeoutMs = timeoutMs;
    this.fetch = fetchImpl;
    this.hashNumbers = hashNumbers === true;
  }

  /** Check one number. Uses one check from your allowance. */
  async lookup(phone) {
    return toLookup(await this.#request("POST", "/lookups", numberFields(phone, this.hashNumbers)));
  }

  /** Check up to 100 numbers. All or nothing: if you don't have enough checks, none are used. */
  async lookupMany(phones) {
    const payload = this.hashNumbers ? { phone_sha256s: phones.map(hashPhone), phone_length: phones.length ? hashedLength(phones[0]) : 13 } : { phones };
    const body = await this.#request("POST", "/lookups/batch", payload);
    return body.results.map((r) => toLookup(r, { notice: body.notice, checksRemaining: body.checks_remaining }));
  }

  /**
   * Share an experience with a number. Optional, and doesn't change your allowance.
   * incidentAt: when it happened (a Date or an ISO 8601 string); can't be in the future.
   */
  async report(report) {
    const body = await this.#request("POST", "/reports", toPayload(report, this.hashNumbers));
    return { id: body.id, phoneLast4: body.phone_last4 };
  }

  /**
   * Share up to 100 experiences at once. Each is handled on its own, so one bad row never stops the rest.
   * Resolves to one result per report, in order: status is "recorded", "duplicate" (already shared; treat as done) or "invalid".
   */
  async reportMany(reports) {
    if (!Array.isArray(reports) || reports.length < 1 || reports.length > 100) throw new RangeError("reportMany takes 1 to 100 reports");
    const body = await this.#request("POST", "/reports/batch", { reports: reports.map((r) => toPayload(r, this.hashNumbers)) });
    return body.results.map((r) => ({
      index: r.index, status: r.status, id: r.id ?? null, phoneLast4: r.phone_last4 ?? null,
      errorCode: r.error?.code ?? null, errorMessage: r.error?.message ?? null,
    }));
  }

  /** Withdraw your own report for a number. Rejects with NotFoundError if you have no active report for it. */
  async withdrawReport(phone) {
    const body = await this.#request("DELETE", "/reports", numberFields(phone, this.hashNumbers));
    return { phoneLast4: body.phone_last4, status: body.status };
  }

  /** The reason codes with their labels and descriptions. */
  async reasonCodes() {
    const body = await this.#request("GET", "/reason_codes");
    return body.reason_codes.map((c) => ({ code: c.code, group: c.group, label: c.label, description: c.description, useWhen: c.use_when, notWhen: c.not_when }));
  }

  /**
   * A development aid: asks OpenTrust whether it computes the same SHA-256 as this library for a number. Use a test number, not a
   * customer's: it sends the number. Resolves with `match` (true or false). It costs no checks.
   */
  async verifyHashing(testPhone) {
    return this.#request("POST", "/phone_hash/check", { phone: testPhone, phone_sha256: hashPhone(testPhone) });
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
