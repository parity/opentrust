import { addTag, appendNote, type GraphQL } from "./admin";
import type { OpenTrustClient } from "./client";
import { buildNote } from "./note";
import { describeError } from "./describe-error";
import { digitsOnly, extractPhone, isCashOnDelivery, orderGid, type OrderPayload } from "./order";

export const TAG_REPORTED = "opentrust-reported";

export type Outcome =
  | { outcome: "skipped"; reason: string }
  | { outcome: "clean"; reportCount: 0 }
  | { outcome: "reported"; reportCount: number }
  | { outcome: "error"; reason: string; reportCount?: number };

/**
 * Check an order's phone number and annotate the order. It never throws for OpenTrust problems and never blocks
 * anything: it returns what happened so the caller can log it.
 */
export async function processOrder(args: {
  order: OrderPayload;
  settings?: { onlyCod?: boolean };
  client: Pick<OpenTrustClient, "lookup">;
  graphql: GraphQL;
}): Promise<Outcome> {
  const { order, settings = {}, client, graphql } = args;
  const { onlyCod = false } = settings;

  const phone = extractPhone(order);
  if (!phone || digitsOnly(phone).length < 10) return { outcome: "skipped", reason: "no usable phone number" };
  if (onlyCod && !isCashOnDelivery(order)) return { outcome: "skipped", reason: "not a cash-on-delivery order" };

  let result;
  try {
    result = await client.lookup(phone);
  } catch (e) {
    // Fail open: an outage, rate limit or empty allowance must never affect the order.
    const name = e instanceof Error ? e.name : "Error";
    return { outcome: "error", reason: `${name}: ${describeError(e)}` };
  }
  if (!result.reported) return { outcome: "clean", reportCount: 0 };

  const id = orderGid(order);
  if (!id) return { outcome: "error", reason: "order has no id", reportCount: result.reportCount };
  try {
    await addTag(graphql, id, TAG_REPORTED);
    await appendNote(graphql, id, buildNote(result));
  } catch (e) {
    return { outcome: "error", reason: `could not update order: ${describeError(e)}`, reportCount: result.reportCount };
  }
  return { outcome: "reported", reportCount: result.reportCount };
}
