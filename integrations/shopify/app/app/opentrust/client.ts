// A small OpenTrust API client for this app (the same calls as the `opentrust` npm package, which isn't published yet).
// When the package is on npm, replace this file with `import { OpenTrust } from "opentrust"`.

const DEFAULT_BASE_URL = "https://opentrust.in/api/v1";

export interface ReportSummary {
  reasonCode: string;
  reason?: string;
  notes?: string | null;
  reportedAt?: string;
}

export interface LookupResult {
  reported: boolean;
  reportCount: number;
  reports: ReportSummary[];
  notice?: string;
  checksRemaining?: number;
}

export interface MeResult {
  merchant: string;
  checksRemaining: number;
}

/** What the rest of the app needs from a client, so tests can pass a fake. */
export interface OpenTrustClient {
  lookup(phone: string): Promise<LookupResult>;
  me(): Promise<MeResult>;
}

export class OpenTrustError extends Error {
  status?: number;
  code?: string;
  constructor(message: string, opts: { status?: number; code?: string; name?: string } = {}) {
    super(message);
    this.name = opts.name ?? "OpenTrustError";
    this.status = opts.status;
    this.code = opts.code;
  }
}

const NAMES: Record<number, string> = {
  401: "AuthenticationError",
  402: "NoChecksError",
  403: "NotApprovedError",
  409: "DuplicateReportError",
  422: "InvalidRequestError",
  429: "RateLimitError",
};

export function createClient(
  apiKey: string,
  opts: { baseUrl?: string; timeoutMs?: number; fetch?: typeof fetch } = {},
): OpenTrustClient {
  const base = (opts.baseUrl ?? process.env.OPENTRUST_BASE_URL ?? DEFAULT_BASE_URL).replace(/\/$/, "");
  const doFetch = opts.fetch ?? fetch;
  const timeoutMs = opts.timeoutMs ?? 5000;

  async function request(method: "GET" | "POST", path: string, payload?: unknown) {
    let res: Response;
    try {
      res = await doFetch(`${base}${path}`, {
        method,
        headers: {
          Authorization: `Bearer ${apiKey}`,
          Accept: "application/json",
          "User-Agent": "opentrust-shopify/0.1.0",
          ...(payload ? { "Content-Type": "application/json" } : {}),
        },
        body: payload ? JSON.stringify(payload) : undefined,
        signal: AbortSignal.timeout(timeoutMs),
      });
    } catch (e) {
      const err = e as Error;
      throw new OpenTrustError(`could not reach OpenTrust: ${err.name}: ${err.message}`, { name: "ConnectionError" });
    }
    const body = (await res.json().catch(() => ({}))) as Record<string, any>;
    if (!res.ok) {
      const e = body?.error ?? {};
      throw new OpenTrustError(e.message ?? `OpenTrust returned HTTP ${res.status}`, {
        status: res.status,
        code: e.code,
        name: NAMES[res.status] ?? (res.status >= 500 ? "ServerError" : "OpenTrustError"),
      });
    }
    return body;
  }

  return {
    async lookup(phone) {
      const b = await request("POST", "/lookups", { phone });
      return {
        reported: (b.report_count ?? 0) > 0,
        reportCount: b.report_count ?? 0,
        reports: (b.reports ?? []).map((r: any) => ({
          reasonCode: r.reason_code,
          reason: r.reason,
          notes: r.notes ?? null,
          reportedAt: r.reported_at,
        })),
        notice: b.notice,
        checksRemaining: b.checks_remaining,
      };
    },
    async me() {
      const b = await request("GET", "/me");
      return { merchant: b.merchant, checksRemaining: b.checks_remaining };
    },
  };
}
