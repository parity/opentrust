import type { LoaderFunctionArgs } from "react-router";

import { login } from "../../shopify.server";

// Installation always starts from a Shopify-owned surface (the App Store or the merchant's admin), so this page never asks
// for a shop domain. A request that arrives with a valid ?shop= is handed to Shopify's login, which redirects.
export const loader = async ({ request }: LoaderFunctionArgs) => {
  if (new URL(request.url).searchParams.get("shop")) await login(request);
  return null;
};

export default function Auth() {
  return (
    <>
      <script src="https://cdn.shopify.com/shopifycloud/polaris.js" />
      <s-page>
        <s-section heading="Open OpenTrust from your Shopify admin">
          <s-paragraph>Install the app from Shopify, then open it under Apps in your admin.</s-paragraph>
        </s-section>
      </s-page>
    </>
  );
}
