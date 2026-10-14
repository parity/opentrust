# opentrust (Node.js)

Check mobile numbers against experiences shared by other Indian merchants, and share your own. No dependencies, Node 18+, TypeScript types included.

```sh
npm install opentrust
```

```js
import { OpenTrust } from "opentrust";

const ot = new OpenTrust({ apiKey: process.env.OPENTRUST_API_KEY }); // or just set OPENTRUST_API_KEY

const result = await ot.lookup("98765 43210"); // uses 1 check
result.reported;        // true / false
result.reportCount;     // 2
result.reports.forEach((r) => console.log(r.reasonCode, r.incidentAt, r.notes)); // other merchants' reports only
result.ownReport;        // true if you have shared this number yourself
result.notice;          // keep this in front of anyone who sees the result
result.checksRemaining;

await ot.lookupMany(["9876543210", "9000000001"]); // up to 100, all or nothing
await ot.report({ phone: "9876543210", reasonCode: "chargeback", notes: "Disputed 3 card payments in March", incidentAt: "2026-03-14",
  confirmedBy: "bank", evidenceRef: "your-ticket-123" }); // optional: who confirmed it (shown to others), and a private reference

// up to 100 at once; one bad row never stops the rest
const results = await ot.reportMany([{ phone: "9876543210", reasonCode: "chargeback", incidentAt: "2026-08-14" }, { phone: "9812345678", reasonCode: "fake_order" }]);
results.filter((r) => r.status === "invalid").forEach((r) => console.warn(r.index, r.errorCode));

await ot.withdrawReport("9876543210"); // take your own report back (rejects with NotFoundError if there is none)
await ot.reasonCodes();                // the codes with labels and descriptions
await ot.me();
```

## Send hashes instead of phone numbers

Pass `hashNumbers: true` and the library sends the SHA-256 of each number instead of the number, so OpenTrust never receives it. It also sends `phone_length`, the length of the text it hashed (always 13), which OpenTrust checks to catch a hash of a differently written number. A report also sends the last four digits, so merchants and admins have something to recognise it by.

```js
import { OpenTrust, hashPhone } from "opentrust";

const ot = new OpenTrust({ hashNumbers: true });
await ot.lookup("98765 43210");        // sends only the hash and its length (always 13)
hashPhone("98765 43210");              // "f3a47ce5ce3d4ca8ad15225a245b2759022f79489f5c62719b8c9490f7aab90e"
await ot.verifyHashing("98765 43210"); // development aid: asks OpenTrust to compare (sends the number: use a test number)
```

The format is exact, and a hash computed from a differently written number just finds nothing, so use the helper instead of hashing by hand. It is tested against the shared [test vectors](https://github.com/parity/opentrust/blob/main/sdks/phone-hash-vectors.json). A hash of a phone number can in principle be reversed by trying every possible number: this limits what is sent and stored, it does not make a number anonymous.

## Please don't block checkout on OpenTrust

Results are unverified observations from individual merchants. Use them as one input, have a person review decisions that matter, and fail open if OpenTrust is unreachable:

```js
try {
  const result = await ot.lookup(order.phone);
  if (result.reported) flagForReview(order);
} catch (e) {
  if (!(e instanceof OpenTrustError)) throw e;
  console.warn("OpenTrust unavailable:", e.message); // carry on
}
```

Errors (all extend `OpenTrustError`, with `status` and `code`): `AuthenticationError` 401, `NoChecksError` 402 (write to us and we'll raise your limit), `NotApprovedError` 403, `NotFoundError` 404 (withdrawing a report you don't have), `DuplicateReportError` 409, `InvalidRequestError` 422, `RateLimitError` 429, `ServerError` 5xx, `ConnectionError` network/timeout. Timeout defaults to 5s (`timeoutMs`). Docs: https://opentrust.in/docs

---

Part of [OpenTrust](https://opentrust.in), sponsored by [ParityCube](https://www.paritycube.com/). Source: [github.com/parity/opentrust](https://github.com/parity/opentrust).
