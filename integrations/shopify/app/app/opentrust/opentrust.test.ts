import { describe, expect, it } from "vitest";
import {
  addTag, appendNote, buildNote, createClient, deleteShopData, describeError, extractPhone, handleOrdersCreate, isCashOnDelivery,
  loadStatus, processOrder, saveSettings, TAG_REPORTED, type GraphQL, type LookupResult, type SettingsRow, type SettingsStore,
} from "./index";
import { decryptSecret, encryptSecret } from "./crypto.server";

const KEY = "ab".repeat(32);
const reported: LookupResult = {
  reported: true, reportCount: 2, checksRemaining: 9, notice: "n",
  reports: [
    { reasonCode: "cod_refusal", reason: "Refused a cash-on-delivery order", notes: "Refused 3 COD <b>orders</b>", reportedAt: "2026-10-01" },
    { reasonCode: "otp_fraud", reason: "Asked someone for an OTP", notes: null, reportedAt: "2026-09-20" },
  ],
};
const clean: LookupResult = { reported: false, reportCount: 0, reports: [] };
const codOrder = (extra: object = {}) => ({
  id: 42, admin_graphql_api_id: "gid://shopify/Order/42", payment_gateway_names: ["Cash on Delivery (COD)"],
  billing_address: { phone: "+91 98765 43210" }, ...extra,
});

function fakeGraphql(existingNote = "") {
  const calls: { query: string; variables?: Record<string, unknown> }[] = [];
  const fn: GraphQL = async (query, variables) => {
    calls.push({ query, variables });
    if (query.includes("orderNote")) return { data: { order: { note: existingNote } } };
    if (query.includes("tagsAdd")) return { data: { tagsAdd: { userErrors: [] } } };
    return { data: { orderUpdate: { userErrors: [] } } };
  };
  return Object.assign(fn, { calls });
}
const lookupClient = (r: LookupResult) => {
  const calls: string[] = [];
  return { calls, async lookup(p: string) { calls.push(p); return r; }, async me() { return { merchant: "Demo Shop", checksRemaining: 99 }; } };
};
function memoryStore() {
  const m = new Map<string, SettingsRow>();
  const store: SettingsStore = { get: async (s) => m.get(s), set: async (s, r) => void m.set(s, r), delete: async (s) => void m.delete(s) };
  return { m, store };
}

describe("order helpers", () => {
  it("extractPhone prefers billing, then order, shipping, customer", () => {
    expect(extractPhone({ billing_address: { phone: "111" }, phone: "222" })).toBe("111");
    expect(extractPhone({ billing_address: { phone: " " }, phone: "222" })).toBe("222");
    expect(extractPhone({ shipping_address: { phone: "333" } })).toBe("333");
    expect(extractPhone({ customer: { phone: "444" } })).toBe("444");
    expect(extractPhone({})).toBeNull();
  });
  it("recognises common COD payment names", () => {
    for (const n of ["Cash on Delivery (COD)", "COD", "cash_on_delivery", "Pay by Cash On Delivery"]) expect(isCashOnDelivery({ payment_gateway_names: [n] })).toBe(true);
    for (const n of ["razorpay", "Shopify Payments", "bogus"]) expect(isCashOnDelivery({ payment_gateway_names: [n] })).toBe(false);
    expect(isCashOnDelivery({ gateway: "Cash on Delivery" })).toBe(true);
  });
  it("buildNote handles singular and plural, strips markup, carries the disclaimer", () => {
    expect(buildNote({ reportCount: 1, reports: [] })).toMatch(/1 merchant has noted/);
    expect(buildNote({ reportCount: 3, reports: [] })).toMatch(/3 merchants have noted/);
    const n = buildNote(reported);
    expect(n).not.toContain("<b>");
    expect(n).toMatch(/unverified observations/);
  });
});

describe("processOrder", () => {
  it("tags a reported order and appends to its existing note", async () => {
    const client = lookupClient(reported), graphql = fakeGraphql("Customer asked for evening delivery");
    const out = await processOrder({ order: codOrder(), settings: { onlyCod: true }, client, graphql });
    expect(out).toEqual({ outcome: "reported", reportCount: 2 });
    expect(client.calls).toEqual(["+91 98765 43210"]);
    expect(graphql.calls.find((c) => c.query.includes("tagsAdd"))!.variables).toEqual({ id: "gid://shopify/Order/42", tags: [TAG_REPORTED] });
    const note = (graphql.calls.find((c) => c.query.includes("orderUpdate"))!.variables as any).input.note as string;
    expect(note).toMatch(/^Customer asked for evening delivery\n\nOpenTrust: 2 merchants have noted/);
  });
  it("leaves a clean order alone", async () => {
    const graphql = fakeGraphql();
    expect((await processOrder({ order: codOrder(), client: lookupClient(clean), graphql })).outcome).toBe("clean");
    expect(graphql.calls).toHaveLength(0);
  });
  it("skips non-COD orders and orders with no phone without spending a check", async () => {
    const client = lookupClient(reported);
    expect((await processOrder({ order: codOrder({ payment_gateway_names: ["razorpay"] }), settings: { onlyCod: true }, client, graphql: fakeGraphql() })).outcome).toBe("skipped");
    expect((await processOrder({ order: codOrder({ billing_address: {} }), client, graphql: fakeGraphql() })).outcome).toBe("skipped");
    expect((await processOrder({ order: codOrder({ payment_gateway_names: ["razorpay"] }), settings: { onlyCod: false }, client: lookupClient(clean), graphql: fakeGraphql() })).outcome).toBe("clean");
    expect(client.calls).toHaveLength(0);
  });
  it("fails open when OpenTrust errors, and never touches the order", async () => {
    const graphql = fakeGraphql();
    const client = { async lookup(): Promise<LookupResult> { const e = new Error("no checks left"); e.name = "NoChecksError"; throw e; } };
    const out = await processOrder({ order: codOrder(), client, graphql });
    expect(out.outcome).toBe("error");
    expect((out as { reason: string }).reason).toMatch(/NoChecksError/);
    expect(graphql.calls).toHaveLength(0);
  });
  it("reports Shopify failures instead of throwing", async () => {
    const graphql: GraphQL = async () => ({ errors: [{ message: "Access denied" }] });
    const out = await processOrder({ order: codOrder(), client: lookupClient(reported), graphql });
    expect(out.outcome).toBe("error");
    expect((out as { reason: string }).reason).toMatch(/could not update order/);
  });
  it("describes a thrown Response (how Shopify's client fails) instead of 'undefined'", async () => {
    const graphql: GraphQL = async () => { throw new Response("nope", { status: 401, statusText: "Unauthorized" }); };
    const out = await processOrder({ order: codOrder(), client: lookupClient(reported), graphql });
    expect(out).toMatchObject({ outcome: "error", reason: "could not update order: HTTP 401 Unauthorized" });
    expect(describeError("plain")).toBe("plain");
    expect(describeError({ a: 1 })).toBe('{"a":1}');
    expect(describeError(new Error(""))).toBe("Error");
  });
  it("appendNote and addTag raise on userErrors", async () => {
    const bad: GraphQL = async (q) => (q.includes("orderNote") ? { data: { order: { note: "" } } } : { data: { orderUpdate: { userErrors: [{ message: "bad" }] }, tagsAdd: { userErrors: [{ message: "nope" }] } } });
    await expect(appendNote(bad, "gid://shopify/Order/1", "x")).rejects.toThrow(/bad/);
    await expect(addTag(bad, "gid://shopify/Order/1", "t")).rejects.toThrow(/nope/);
  });
});

describe("encryption", () => {
  it("round-trips, uses a fresh IV, and rejects tampering or the wrong key", () => {
    const a = encryptSecret("ot_live_abc", KEY), b = encryptSecret("ot_live_abc", KEY);
    expect(a).not.toBe(b);
    expect(decryptSecret(a, KEY)).toBe("ot_live_abc");
    expect(() => decryptSecret(a, "11".repeat(32))).toThrow();
    const [iv, tag] = a.split(".");
    expect(() => decryptSecret([iv, tag, Buffer.from("tampered").toString("base64")].join("."), KEY)).toThrow();
    expect(() => encryptSecret("x", "short")).toThrow(/32 bytes/);
  });
});

describe("settings and webhook handlers", () => {
  it("saveSettings verifies the key, stores it encrypted, never plain", async () => {
    const { m, store } = memoryStore();
    const used: string[] = [];
    const createClient = (k: string) => { used.push(k); return lookupClient(clean); };
    const out = await saveSettings({ shop: "a.myshopify.com", apiKey: " ot_live_abc ", onlyCod: true, store, createClient, encryptionKey: KEY });
    expect(out).toEqual({ ok: true, merchant: "Demo Shop", checksRemaining: 99 });
    expect(used).toEqual(["ot_live_abc"]);
    const row = m.get("a.myshopify.com")!;
    expect(JSON.stringify(row)).not.toContain("ot_live_abc");
    expect(decryptSecret(row.apiKeyEnc, KEY)).toBe("ot_live_abc");
  });
  it("saveSettings rejects a bad key and stores nothing", async () => {
    const { m, store } = memoryStore();
    const createClient = () => ({ ...lookupClient(clean), me: async () => { throw new Error("invalid key"); } });
    expect((await saveSettings({ shop: "a", apiKey: "nope", store, createClient, encryptionKey: KEY })).ok).toBe(false);
    expect(m.size).toBe(0);
    expect((await saveSettings({ shop: "a", apiKey: "  ", store, createClient, encryptionKey: KEY })).ok).toBe(false);
  });
  it("an empty key box keeps the saved key while changing the COD switch", async () => {
    const { m, store } = memoryStore();
    const createClient = () => lookupClient(clean);
    await saveSettings({ shop: "a", apiKey: "ot_live_keep", onlyCod: true, store, createClient, encryptionKey: KEY });
    const out = await saveSettings({ shop: "a", apiKey: "", onlyCod: false, store, createClient, encryptionKey: KEY });
    expect(out.ok).toBe(true);
    expect(m.get("a")!.onlyCod).toBe(false);
    expect(decryptSecret(m.get("a")!.apiKeyEnc, KEY)).toBe("ot_live_keep");
  });
  it("orders/create uses the shop's own key and annotates a reported order", async () => {
    const { store } = memoryStore();
    await saveSettings({ shop: "a", apiKey: "ot_live_a", store, createClient: () => lookupClient(clean), encryptionKey: KEY });
    let keyUsed = "";
    const createClient = (k: string) => { keyUsed = k; return lookupClient(reported); };
    const out = await handleOrdersCreate({ shop: "a", payload: codOrder(), store, createClient, graphql: fakeGraphql(), encryptionKey: KEY });
    expect(out.outcome).toBe("reported");
    expect(keyUsed).toBe("ot_live_a");
  });
  it("does nothing for shops that haven't set up OpenTrust, and reports a corrupted stored key", async () => {
    const { store } = memoryStore();
    const boom = () => { throw new Error("must not be called"); };
    expect((await handleOrdersCreate({ shop: "unknown", payload: codOrder(), store, createClient: boom, graphql: fakeGraphql(), encryptionKey: KEY })).outcome).toBe("skipped");
    await store.set("a", { apiKeyEnc: "garbage", onlyCod: true });
    expect((await handleOrdersCreate({ shop: "a", payload: codOrder(), store, createClient: () => lookupClient(clean), graphql: fakeGraphql(), encryptionKey: KEY })).outcome).toBe("error");
  });
  it("loadStatus never exposes the key and shows connection state", async () => {
    const { store } = memoryStore();
    expect(await loadStatus({ shop: "a", store, createClient: () => lookupClient(clean), encryptionKey: KEY })).toEqual({ configured: false, onlyCod: true });
    await saveSettings({ shop: "a", apiKey: "ot_live_a", onlyCod: false, store, createClient: () => lookupClient(clean), encryptionKey: KEY });
    const ok = await loadStatus({ shop: "a", store, createClient: () => lookupClient(clean), encryptionKey: KEY });
    expect(ok).toEqual({ configured: true, onlyCod: false, connected: true, merchant: "Demo Shop", checksRemaining: 99 });
    const down = await loadStatus({ shop: "a", store, createClient: () => ({ ...lookupClient(clean), me: async () => { throw new Error("down"); } }), encryptionKey: KEY });
    expect(down).toMatchObject({ configured: true, connected: false, error: "down" });
    expect(JSON.stringify(ok)).not.toContain("ot_live_a");
  });
  it("deleteShopData removes the shop's settings", async () => {
    const { m, store } = memoryStore();
    await store.set("a", { apiKeyEnc: "x.y.z", onlyCod: true });
    await deleteShopData({ shop: "a", store });
    expect(m.size).toBe(0);
  });
});

describe("OpenTrust client", () => {
  const respond = (status: number, body: unknown) => (async () => new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } })) as unknown as typeof fetch;

  it("sends the key and phone, and maps the response", async () => {
    let seen: { url: string; init: RequestInit } | undefined;
    const f = (async (url: string, init: RequestInit) => {
      seen = { url, init };
      return new Response(JSON.stringify({ report_count: 1, checks_remaining: 7, notice: "n", reports: [{ reason_code: "cod_refusal", reason: "Refused", notes: "x", reported_at: "2026-10-01" }] }), { status: 200 });
    }) as unknown as typeof fetch;
    const r = await createClient("ot_live_k", { baseUrl: "https://example.test/api/v1/", fetch: f }).lookup("98765 43210");
    expect(r).toMatchObject({ reported: true, reportCount: 1, checksRemaining: 7 });
    expect(r.reports[0]).toMatchObject({ reasonCode: "cod_refusal", reason: "Refused" });
    expect(seen!.url).toBe("https://example.test/api/v1/lookups");
    expect((seen!.init.headers as Record<string, string>).Authorization).toBe("Bearer ot_live_k");
    expect(JSON.parse(seen!.init.body as string)).toEqual({ phone: "98765 43210" });
  });
  it("maps me()", async () => {
    expect(await createClient("k", { fetch: respond(200, { merchant: "Demo", checks_remaining: 5 }) }).me()).toEqual({ merchant: "Demo", checksRemaining: 5 });
  });
  it("turns error statuses into named errors, and network failures into ConnectionError", async () => {
    for (const [status, name] of [[401, "AuthenticationError"], [402, "NoChecksError"], [403, "NotApprovedError"], [429, "RateLimitError"], [503, "ServerError"]] as const) {
      await expect(createClient("k", { fetch: respond(status, { error: { code: "x", message: "boom" } }) }).lookup("9876543210")).rejects.toMatchObject({ name, status, message: "boom" });
    }
    const down = (async () => { throw new Error("ECONNREFUSED"); }) as unknown as typeof fetch;
    await expect(createClient("k", { fetch: down }).lookup("9876543210")).rejects.toMatchObject({ name: "ConnectionError" });
  });
});
