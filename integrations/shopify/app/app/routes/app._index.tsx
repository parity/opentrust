import { useEffect, useState } from "react";
import type { ActionFunctionArgs, HeadersFunction, LoaderFunctionArgs } from "react-router";
import { useFetcher, useLoaderData } from "react-router";
import { useAppBridge } from "@shopify/app-bridge-react";
import { boundary } from "@shopify/shopify-app-react-router/server";
import { authenticate } from "../shopify.server";
import { createClient, loadStatus, saveSettings } from "../opentrust";
import { encryptionKey } from "../opentrust/env.server";
import { store } from "../opentrust/store.server";

export const loader = async ({ request }: LoaderFunctionArgs) => {
  const { session } = await authenticate.admin(request);
  return loadStatus({ shop: session.shop, store, createClient, encryptionKey: encryptionKey() });
};

export const action = async ({ request }: ActionFunctionArgs) => {
  const { session } = await authenticate.admin(request);
  const form = await request.formData();
  return saveSettings({
    shop: session.shop,
    apiKey: String(form.get("apiKey") ?? ""),
    onlyCod: form.get("onlyCod") === "true",
    store,
    createClient,
    encryptionKey: encryptionKey(),
  });
};

export default function Settings() {
  const status = useLoaderData<typeof loader>();
  const fetcher = useFetcher<typeof action>();
  const shopify = useAppBridge();

  const [apiKey, setApiKey] = useState("");
  const [onlyCod, setOnlyCod] = useState(status.onlyCod);
  const saving = ["loading", "submitting"].includes(fetcher.state);
  const result = fetcher.data;

  useEffect(() => {
    if (result?.ok) {
      shopify.toast.show("OpenTrust settings saved");
      setApiKey("");
    }
  }, [result, shopify]);

  const save = () => fetcher.submit({ apiKey, onlyCod: String(onlyCod) }, { method: "POST" });

  return (
    <s-page heading="OpenTrust">
      <s-button slot="primary-action" onClick={save} {...(saving ? { loading: true } : {})}>
        Save
      </s-button>

      {result && !result.ok && (
        <s-banner tone="critical" heading="Could not save">
          {result.error}
        </s-banner>
      )}
      {!status.configured && !result && (
        <s-banner tone="info" heading="Add your OpenTrust API key to start checking orders">
          Paste the key below. Don't have one yet? Registering at opentrust.in is free.
        </s-banner>
      )}
      {status.configured && status.connected && (
        <s-banner tone="success" heading={`Connected as ${status.merchant}`}>
          {status.checksRemaining?.toLocaleString("en-IN")} checks left.
        </s-banner>
      )}
      {status.configured && status.connected === false && (
        <s-banner tone="warning" heading="Can't reach OpenTrust with the saved key">
          {status.error}. New orders are not being checked until this is fixed.
        </s-banner>
      )}

      <s-section heading="Connect your OpenTrust account">
        <s-stack direction="block" gap="base">
          <s-password-field
            label="OpenTrust API key"
            name="apiKey"
            value={apiKey}
            details={status.configured ? "A key is saved. Leave this empty to keep it." : "Create one in your OpenTrust dashboard."}
            onInput={(e) => setApiKey(e.currentTarget.value)}
          />
          <s-link href="https://opentrust.in/portal/api_keys" target="_blank">
            Open my OpenTrust dashboard
          </s-link>
          <s-checkbox
            label="Only check cash-on-delivery orders"
            details="Saves your checks. COD is where most problems happen. Turn this off to check every order with a phone number."
            checked={onlyCod}
            onChange={(e) => setOnlyCod(e.currentTarget.checked)}
          />
        </s-stack>
      </s-section>

      <s-section heading="What it does">
        <s-paragraph>
          When a new order comes in, OpenTrust checks its phone number in the background. If other merchants have noted
          experiences with that number, the order is tagged <s-text type="strong">opentrust-reported</s-text> and a note
          listing what was reported is added to the order timeline notes.
        </s-paragraph>
        <s-paragraph>
          It never cancels, holds or blocks an order, and if OpenTrust can't be reached the order carries on as normal.
          Reports are unverified observations from individual merchants, not a finding about the customer, so please
          review the order yourself.
        </s-paragraph>
      </s-section>

      <s-section slot="aside" heading="What gets sent">
        <s-paragraph>
          Only the order's phone number is sent to opentrust.in over HTTPS. No names, addresses or order details. Please
          mention this in your store's privacy policy.
        </s-paragraph>
        <s-paragraph>
          <s-link href="https://opentrust.in/privacy" target="_blank">Privacy Policy</s-link>
          {" · "}
          <s-link href="https://opentrust.in/terms" target="_blank">Terms</s-link>
        </s-paragraph>
      </s-section>

      <s-section slot="aside" heading="Need more checks?">
        <s-paragraph>
          Every approved merchant starts with 1,00,000 free checks. Running low? Write to feedback@opentrust.in.
        </s-paragraph>
      </s-section>
    </s-page>
  );
}

export const headers: HeadersFunction = (headersArgs) => {
  return boundary.headers(headersArgs);
};
