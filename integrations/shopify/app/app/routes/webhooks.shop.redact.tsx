import type { ActionFunctionArgs } from "react-router";
import { authenticate } from "../shopify.server";
import db from "../db.server";
import { deleteShopData } from "../opentrust";
import { store } from "../opentrust/store.server";

// Mandatory privacy webhook, sent 48 hours after uninstall: remove everything we hold for the shop.
export const action = async ({ request }: ActionFunctionArgs) => {
  const { shop, topic } = await authenticate.webhook(request);
  console.log(`${topic} for ${shop}: deleting shop data`);
  await deleteShopData({ shop, store });
  await db.session.deleteMany({ where: { shop } });
  return new Response();
};
