import type { GraphQL } from "./admin";
import type { OpenTrustClient } from "./client";
import { decryptSecret, encryptSecret } from "./crypto.server";
import { describeError } from "./describe-error";
import type { OrderPayload } from "./order";
import { processOrder, type Outcome } from "./process-order";

// Framework-free handlers. The routes are thin wrappers that pass in the store, a client factory, the shop's Admin
// GraphQL caller and the encryption key, which keeps all the behaviour here, where it is easy to test.

export interface SettingsRow {
  apiKeyEnc: string;
  onlyCod: boolean;
}

export interface SettingsStore {
  get(shop: string): Promise<SettingsRow | null | undefined>;
  set(shop: string, row: SettingsRow): Promise<void>;
  delete(shop: string): Promise<void>;
}

export type CreateClient = (apiKey: string) => OpenTrustClient;

/** orders/create webhook. Always safe to call: it never throws for OpenTrust problems. */
export async function handleOrdersCreate(args: {
  shop: string;
  payload: OrderPayload;
  store: SettingsStore;
  createClient: CreateClient;
  graphql: GraphQL;
  encryptionKey: string;
}): Promise<Outcome> {
  const { shop, payload, store, createClient, graphql, encryptionKey } = args;
  const row = await store.get(shop);
  if (!row?.apiKeyEnc) return { outcome: "skipped", reason: "OpenTrust is not set up for this shop" };
  let client: OpenTrustClient;
  try {
    client = createClient(decryptSecret(row.apiKeyEnc, encryptionKey));
  } catch (e) {
    return { outcome: "error", reason: `could not read the stored API key: ${describeError(e)}` };
  }
  return processOrder({ order: payload, settings: { onlyCod: row.onlyCod === true }, client, graphql });
}

export type SaveResult =
  | { ok: true; merchant: string; checksRemaining: number }
  | { ok: false; error: string };

/** Settings form. Verifies the key with OpenTrust before saving it (encrypted). */
export async function saveSettings(args: {
  shop: string;
  apiKey?: string | null;
  onlyCod?: boolean;
  store: SettingsStore;
  createClient: CreateClient;
  encryptionKey: string;
}): Promise<SaveResult> {
  const { shop, onlyCod = false, store, createClient, encryptionKey } = args;
  const existing = await store.get(shop);
  let key = String(args.apiKey ?? "").trim();

  // Leaving the key box empty keeps the saved key, so toggling the checkbox doesn't force re-entering it.
  if (!key && existing?.apiKeyEnc) {
    try {
      key = decryptSecret(existing.apiKeyEnc, encryptionKey);
    } catch {
      return { ok: false, error: "The saved key can't be read. Please enter your OpenTrust API key again." };
    }
  }
  if (!key) return { ok: false, error: "Enter your OpenTrust API key." };

  try {
    const me = await createClient(key).me();
    await store.set(shop, { apiKeyEnc: encryptSecret(key, encryptionKey), onlyCod: Boolean(onlyCod) });
    return { ok: true, merchant: me.merchant, checksRemaining: me.checksRemaining };
  } catch (e) {
    return { ok: false, error: `OpenTrust did not accept that key (${describeError(e)}).` };
  }
}

export interface Status {
  configured: boolean;
  onlyCod: boolean;
  connected?: boolean;
  merchant?: string;
  checksRemaining?: number;
  error?: string;
}

/** What the settings page may show. Never includes the key itself. */
export async function loadStatus(args: {
  shop: string;
  store: SettingsStore;
  createClient: CreateClient;
  encryptionKey: string;
}): Promise<Status> {
  const { shop, store, createClient, encryptionKey } = args;
  const row = await store.get(shop);
  if (!row?.apiKeyEnc) return { configured: false, onlyCod: false };
  const base: Status = { configured: true, onlyCod: row.onlyCod === true };
  try {
    const me = await createClient(decryptSecret(row.apiKeyEnc, encryptionKey)).me();
    return { ...base, connected: true, merchant: me.merchant, checksRemaining: me.checksRemaining };
  } catch (e) {
    return { ...base, connected: false, error: describeError(e) };
  }
}

/** For the uninstall and shop/redact webhooks. We keep no customer data, only the shop's settings. */
export async function deleteShopData(args: { shop: string; store: SettingsStore }): Promise<void> {
  await args.store.delete(args.shop);
}
