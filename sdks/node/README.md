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
result.reports.forEach((r) => console.log(r.reasonCode, r.notes));
result.notice;          // keep this in front of anyone who sees the result
result.checksRemaining;

await ot.lookupMany(["9876543210", "9000000001"]); // up to 100, all or nothing
await ot.report({ phone: "9876543210", reasonCode: "cod_refusal", notes: "Refused 3 COD orders in March" });
await ot.me();
```

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

Errors (all extend `OpenTrustError`, with `status` and `code`): `AuthenticationError` 401, `NoChecksError` 402 (write to us and we'll raise your limit), `NotApprovedError` 403, `DuplicateReportError` 409, `InvalidRequestError` 422, `RateLimitError` 429, `ServerError` 5xx, `ConnectionError` network/timeout. Timeout defaults to 5s (`timeoutMs`). Docs: https://opentrust.in/docs

---

Part of [OpenTrust](https://opentrust.in), sponsored by [ParityCube](https://www.paritycube.com/). Source: [github.com/parity/opentrust](https://github.com/parity/opentrust).
