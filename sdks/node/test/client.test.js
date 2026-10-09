import test from "node:test";
import assert from "node:assert/strict";
import { OpenTrust, NoChecksError, AuthenticationError, DuplicateReportError, ConnectionError, OpenTrustError } from "../src/index.js";

const respond = (status, body) => async () => new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
const make = (fetch) => new OpenTrust({ apiKey: "ot_live_test", fetch });

test("lookup maps a result with reports", async () => {
  let seen;
  const fetch = async (url, init) => { seen = { url, init }; return respond(200, {
    phone_last4: "3210", reported: true, report_count: 1, notice: "Unverified…", checks_remaining: 99,
    reports: [{ reason_code: "cod_refusal", reason: "Refused a cash-on-delivery order", notes: "Refused 3 COD orders", reported_at: "2026-10-01", reporter_verified: true }] })(); };
  const r = await make(fetch).lookup("98765 43210");
  assert.equal(r.reported, true);
  assert.equal(r.reports[0].reasonCode, "cod_refusal");
  assert.equal(r.checksRemaining, 99);
  assert.equal(seen.url, "https://opentrust.in/api/v1/lookups");
  assert.equal(seen.init.headers.Authorization, "Bearer ot_live_test");
  assert.deepEqual(JSON.parse(seen.init.body), { phone: "98765 43210" });
});

test("lookup with no reports", async () => {
  const r = await make(respond(200, { phone_last4: "0001", report_count: 0, reports: [] })).lookup("9000000001");
  assert.equal(r.reported, false);
  assert.deepEqual(r.reports, []);
});

test("lookupMany shares notice and balance", async () => {
  const body = { results: [{ phone_last4: "1", report_count: 0, reports: [] }, { phone_last4: "2", report_count: 2, reports: [] }], notice: "N", checks_remaining: 5 };
  const rs = await make(respond(200, body)).lookupMany(["9000000001", "9000000002"]);
  assert.deepEqual(rs.map((r) => r.reported), [false, true]);
  assert.deepEqual(rs.map((r) => r.notice), ["N", "N"]);
});

test("report sends snake_case and omits empty notes", async () => {
  let sent;
  const fetch = async (_u, init) => { sent = JSON.parse(init.body); return respond(201, { id: 7, phone_last4: "3210" })(); };
  const r = await make(fetch).report({ phone: "9876543210", reasonCode: "cod_refusal" });
  assert.equal(r.id, 7);
  assert.deepEqual(sent, { phone: "9876543210", reason_code: "cod_refusal" });
});

test("errors are typed", async () => {
  const err = (status, Klass) => assert.rejects(make(respond(status, { error: { code: "x", message: "boom" } })).lookup("9876543210"),
    (e) => e instanceof Klass && e instanceof OpenTrustError && e.status === status && e.message === "boom");
  await err(401, AuthenticationError);
  await err(402, NoChecksError);
  await err(409, DuplicateReportError);
});

test("network failures become ConnectionError", async () => {
  await assert.rejects(make(async () => { throw new Error("ECONNREFUSED"); }).lookup("9876543210"), ConnectionError);
});

test("requires an api key", () => {
  assert.throws(() => new OpenTrust({ apiKey: "" }), TypeError);
});
