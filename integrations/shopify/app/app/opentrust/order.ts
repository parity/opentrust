// Reading what we need from a Shopify order payload (the orders/create webhook shape).

export interface OrderPayload {
  id?: number | string;
  admin_graphql_api_id?: string;
  phone?: string | null;
  gateway?: string | null;
  payment_gateway_names?: string[];
  billing_address?: { phone?: string | null } | null;
  shipping_address?: { phone?: string | null } | null;
  customer?: { phone?: string | null; default_address?: { phone?: string | null } | null } | null;
}

/** The best phone number on the order, or null. Billing first, then the order, shipping, customer. */
export function extractPhone(order: OrderPayload): string | null {
  const candidates = [
    order?.billing_address?.phone,
    order?.phone,
    order?.shipping_address?.phone,
    order?.customer?.phone,
    order?.customer?.default_address?.phone,
  ];
  return candidates.map((p) => (p ?? "").toString().trim()).find((p) => p !== "") ?? null;
}

/** Shopify has no built-in COD flag. Stores use a manual payment method, usually named like "Cash on Delivery (COD)". */
export function isCashOnDelivery(order: OrderPayload): boolean {
  const names = [...(order?.payment_gateway_names ?? []), order?.gateway].filter(Boolean) as string[];
  return names.some((n) => /\bcod\b|cash\s*on\s*delivery|cash_on_delivery/i.test(String(n)));
}

export function orderGid(order: OrderPayload): string | null {
  return order?.admin_graphql_api_id ?? (order?.id ? `gid://shopify/Order/${order.id}` : null);
}

export function digitsOnly(phone: unknown): string {
  return String(phone ?? "").replace(/\D+/g, "");
}
