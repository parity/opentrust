import test from "node:test";
import assert from "node:assert/strict";
import { OpenTrust, NoChecksError, AuthenticationError, DuplicateReportError, NotFoundError, ConnectionError, OpenTrustError } from "../src/index.js";

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

test("lookup reads ownReport and the incident date", async () => {
  const r = await make(respond(200, { phone_last4: "3210", report_count: 1, own_report: true, reports: [{ reason_code: "chargeback", incident_at: "2026-08-14", reported_at: "2026-10-01" }] })).lookup("9876543210");
  assert.equal(r.ownReport, true);
  assert.equal(r.reports[0].incidentAt, "2026-08-14");
  const none = await make(respond(200, { report_count: 0, reports: [] })).lookup("9000000001");
  assert.equal(none.ownReport, false);
});

test("report sends incidentAt as a date string", async () => {
  let sent;
  const fetch = async (_u, init) => { sent = JSON.parse(init.body); return respond(201, { id: 1, phone_last4: "3210" })(); };
  await make(fetch).report({ phone: "9876543210", reasonCode: "chargeback", incidentAt: new Date("2026-08-14T10:00:00Z") });
  assert.equal(sent.incident_at, "2026-08-14");
  await make(fetch).report({ phone: "9876543210", reasonCode: "chargeback", incidentAt: "2026-08-15" });
  assert.equal(sent.incident_at, "2026-08-15");
});

test("report sends confirmedBy and evidenceRef, and lookups return confirmedBy", async () => {
  let sent;
  const fetch = async (_u, init) => { sent = JSON.parse(init.body); return respond(201, { id: 1, phone_last4: "3210" })(); };
  await make(fetch).report({ phone: "9876543210", reasonCode: "chargeback", confirmedBy: "payment_gateway", evidenceRef: "GW-1" });
  assert.deepEqual(sent, { phone: "9876543210", reason_code: "chargeback", confirmed_by: "payment_gateway", evidence_ref: "GW-1" });
  const r = await make(respond(200, { report_count: 1, reports: [{ reason_code: "chargeback", confirmed_by: "bank" }, { reason_code: "fake_order" }] })).lookup("9876543210");
  assert.deepEqual(r.reports.map((x) => x.confirmedBy), ["bank", null]);
});

test("reportMany maps each result and checks the size", async () => {
  let seen;
  const body = { results: [{ index: 0, status: "recorded", id: 5, phone_last4: "3210" }, { index: 1, status: "duplicate", error: { code: "duplicate_report", message: "dup" } }, { index: 2, status: "invalid", error: { code: "invalid_phone", message: "bad" } }] };
  const fetch = async (url, init) => { seen = { url, method: init.method, body: JSON.parse(init.body) }; return respond(200, body)(); };
  const rs = await make(fetch).reportMany([{ phone: "9876543210", reasonCode: "chargeback", incidentAt: "2026-08-14" }, { phone: "9812345678", reasonCode: "fake_order" }, { phone: "1", reasonCode: "x" }]);
  assert.equal(seen.url, "https://opentrust.in/api/v1/reports/batch");
  assert.equal(seen.method, "POST");
  assert.deepEqual(seen.body.reports[0], { phone: "9876543210", reason_code: "chargeback", incident_at: "2026-08-14" });
  assert.deepEqual(rs.map((r) => r.status), ["recorded", "duplicate", "invalid"]);
  assert.equal(rs[2].errorCode, "invalid_phone");
  assert.equal(rs[0].id, 5);
  await assert.rejects(make(fetch).reportMany([]), RangeError);
  await assert.rejects(make(fetch).reportMany(Array.from({ length: 101 }, () => ({ phone: "9876543210", reasonCode: "chargeback" }))), RangeError);
});

test("withdrawReport sends DELETE and a missing report is NotFoundError", async () => {
  let seen;
  const fetch = async (url, init) => { seen = { url, method: init.method, body: JSON.parse(init.body) }; return respond(200, { phone_last4: "3210", status: "withdrawn" })(); };
  const w = await make(fetch).withdrawReport("9876543210");
  assert.equal(seen.method, "DELETE");
  assert.equal(seen.url, "https://opentrust.in/api/v1/reports");
  assert.deepEqual(seen.body, { phone: "9876543210" });
  assert.equal(w.status, "withdrawn");
  await assert.rejects(make(respond(404, { error: { code: "report_not_found", message: "none" } })).withdrawReport("9876543210"), (e) => e instanceof NotFoundError && e.code === "report_not_found");
});

test("reasonCodes", async () => {
  const codes = await make(respond(200, { reason_codes: [{ code: "chargeback", group: "Orders and payments", label: "L", description: "D.", use_when: "U", not_when: "N" }] })).reasonCodes();
  assert.deepEqual(codes, [{ code: "chargeback", group: "Orders and payments", label: "L", description: "D.", useWhen: "U", notWhen: "N" }]);
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
