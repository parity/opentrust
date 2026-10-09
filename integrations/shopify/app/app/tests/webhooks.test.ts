import { beforeEach, describe, expect, it, vi } from "vitest";

// The routes are thin wrappers, so we fake Shopify's login layer and the database, and check what each route does.
const authenticateWebhook = vi.fn();
vi.mock("../shopify.server", () => ({ authenticate: { webhook: (...a: unknown[]) => authenticateWebhook(...a) } }));
const sessionDelete = vi.fn(async (_args?: unknown) => ({ count: 1 }));
vi.mock("../db.server", () => ({ default: { session: { deleteMany: (args: unknown) => sessionDelete(args) } } }));
const rows = new Map<string, { apiKeyEnc: string; onlyCod: boolean }>();
vi.mock("../opentrust/store.server", () => ({
  store: { get: async (s: string) => rows.get(s) ?? null, set: async (s: string, r: any) => void rows.set(s, r), delete: async (s: string) => void rows.delete(s) },
}));
const lookup = vi.fn();
vi.mock("../opentrust/client", async (orig) => ({ ...(await orig<typeof import("../opentrust/client")>()), createClient: () => ({ lookup, me: async () => ({ merchant: "M", checksRemaining: 1 }) }) }));

import { encryptSecret } from "../opentrust/crypto.server";
import { action as ordersCreate } from "../routes/webhooks.orders.create";
import { action as dataRequest } from "../routes/webhooks.customers.data_request";
import { action as customersRedact } from "../routes/webhooks.customers.redact";
import { action as shopRedact } from "../routes/webhooks.shop.redact";
import { action as uninstalled } from "../routes/webhooks.app.uninstalled";

const KEY = "cd".repeat(32);
const req = () => new Request("https://app.test/webhooks", { method: "POST" });
const order = { id: 7, admin_graphql_api_id: "gid://shopify/Order/7", payment_gateway_names: ["Cash on Delivery (COD)"], billing_address: { phone: "9876543210" } };
const graphqlOk = vi.fn(async (query: string) => ({
  json: async () => (query.includes("orderNote") ? { data: { order: { note: "" } } } : { data: { tagsAdd: { userErrors: [] }, orderUpdate: { userErrors: [] } } }),
}));

beforeEach(() => {
  process.env.ENCRYPTION_KEY = KEY;
  rows.clear(); lookup.mockReset(); sessionDelete.mockClear(); graphqlOk.mockClear(); authenticateWebhook.mockReset();
  vi.spyOn(console, "log").mockImplementation(() => {});
  vi.spyOn(console, "error").mockImplementation(() => {});
});

describe("orders/create webhook", () => {
  it("tags and annotates a reported COD order, and answers 200", async () => {
    rows.set("a.myshopify.com", { apiKeyEnc: encryptSecret("ot_live_a", KEY), onlyCod: true });
    lookup.mockResolvedValue({ reported: true, reportCount: 1, reports: [{ reasonCode: "cod_refusal", reason: "Refused a cash-on-delivery order" }] });
    authenticateWebhook.mockResolvedValue({ shop: "a.myshopify.com", topic: "ORDERS_CREATE", payload: order, admin: { graphql: graphqlOk } });
    const res = await ordersCreate({ request: req(), params: {}, context: {} } as never);
    expect(res.status).toBe(200);
    expect(lookup).toHaveBeenCalledWith("9876543210");
    const queries = graphqlOk.mock.calls.map((c) => c[0] as string);
    expect(queries.some((q) => q.includes("tagsAdd"))).toBe(true);
    expect(queries.some((q) => q.includes("orderUpdate"))).toBe(true);
  });
  it("answers 200 and does nothing when the shop hasn't set up OpenTrust", async () => {
    authenticateWebhook.mockResolvedValue({ shop: "b.myshopify.com", topic: "ORDERS_CREATE", payload: order, admin: { graphql: graphqlOk } });
    expect((await ordersCreate({ request: req(), params: {}, context: {} } as never)).status).toBe(200);
    expect(lookup).not.toHaveBeenCalled();
    expect(graphqlOk).not.toHaveBeenCalled();
  });
  it("answers 200 when the app was uninstalled (no admin session)", async () => {
    authenticateWebhook.mockResolvedValue({ shop: "a.myshopify.com", topic: "ORDERS_CREATE", payload: order, admin: undefined });
    expect((await ordersCreate({ request: req(), params: {}, context: {} } as never)).status).toBe(200);
  });
  it("still answers 200 when something unexpected breaks, so Shopify doesn't keep retrying", async () => {
    delete process.env.ENCRYPTION_KEY;
    authenticateWebhook.mockResolvedValue({ shop: "a.myshopify.com", topic: "ORDERS_CREATE", payload: order, admin: { graphql: graphqlOk } });
    expect((await ordersCreate({ request: req(), params: {}, context: {} } as never)).status).toBe(200);
  });
  it("lets an invalid signature through as the 401 Shopify's auth throws", async () => {
    authenticateWebhook.mockRejectedValue(new Response("Unauthorized", { status: 401 }));
    await expect(ordersCreate({ request: req(), params: {}, context: {} } as never)).rejects.toMatchObject({ status: 401 });
    expect(lookup).not.toHaveBeenCalled();
  });
});

describe("privacy and uninstall webhooks", () => {
  it("customers/data_request and customers/redact answer 200 (no customer data is held)", async () => {
    authenticateWebhook.mockResolvedValue({ shop: "a.myshopify.com", topic: "CUSTOMERS_DATA_REQUEST" });
    expect((await dataRequest({ request: req(), params: {}, context: {} } as never)).status).toBe(200);
    expect((await customersRedact({ request: req(), params: {}, context: {} } as never)).status).toBe(200);
  });
  it("shop/redact deletes the shop's settings and sessions", async () => {
    rows.set("a.myshopify.com", { apiKeyEnc: "x.y.z", onlyCod: true });
    authenticateWebhook.mockResolvedValue({ shop: "a.myshopify.com", topic: "SHOP_REDACT" });
    expect((await shopRedact({ request: req(), params: {}, context: {} } as never)).status).toBe(200);
    expect(rows.size).toBe(0);
    expect(sessionDelete).toHaveBeenCalledWith({ where: { shop: "a.myshopify.com" } });
  });
  it("app/uninstalled deletes the saved OpenTrust key even if the session is already gone", async () => {
    rows.set("a.myshopify.com", { apiKeyEnc: "x.y.z", onlyCod: true });
    authenticateWebhook.mockResolvedValue({ shop: "a.myshopify.com", topic: "APP_UNINSTALLED", session: undefined });
    expect((await uninstalled({ request: req(), params: {}, context: {} } as never)).status).toBe(200);
    expect(rows.size).toBe(0);
    expect(sessionDelete).not.toHaveBeenCalled();
  });
});
