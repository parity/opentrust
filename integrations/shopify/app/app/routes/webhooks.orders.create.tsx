import type { ActionFunctionArgs } from "react-router";
import { authenticate } from "../shopify.server";
import { createClient, describeError, handleOrdersCreate } from "../opentrust";
import { encryptionKey } from "../opentrust/env.server";
import { store } from "../opentrust/store.server";

// New order: check its phone number with OpenTrust and, if other merchants have noted experiences with it, tag and
// annotate the order. This never changes the order's status and never fails the webhook for OpenTrust problems
// (Shopify would retry a non-2xx response). We log the shop and the outcome, never the phone number.
export const action = async ({ request }: ActionFunctionArgs) => {
  const { shop, topic, payload, admin } = await authenticate.webhook(request);

  if (!admin) {
    // The shop uninstalled the app, so there is no session to write with.
    console.log(`${topic} for ${shop}: no session, skipped`);
    return new Response();
  }

  try {
    const graphql = async (query: string, variables?: Record<string, unknown>) =>
      (await admin.graphql(query, { variables })).json();
    const result = await handleOrdersCreate({
      shop,
      payload: payload as never,
      store,
      createClient,
      graphql,
      encryptionKey: encryptionKey(),
    });
    console.log(`${topic} for ${shop}: ${result.outcome}${"reason" in result ? ` (${result.reason})` : ""}`);
  } catch (e) {
    console.error(`${topic} for ${shop} failed: ${describeError(e)}`);
  }
  return new Response();
};
