import type { ActionFunctionArgs } from "react-router";
import { authenticate } from "../shopify.server";

// Mandatory privacy webhook. We store no customer data (only each shop's settings), so there is nothing to erase.
export const action = async ({ request }: ActionFunctionArgs) => {
  const { shop, topic } = await authenticate.webhook(request);
  console.log(`${topic} for ${shop}: no customer data held`);
  return new Response();
};
