/** Readable text for whatever was thrown. Shopify's client throws a Response (not an Error) on HTTP failures. */
export function describeError(e: unknown): string {
  if (e instanceof Error) return e.message || e.name;
  if (typeof Response !== "undefined" && e instanceof Response) return `HTTP ${e.status}${e.statusText ? ` ${e.statusText}` : ""}`;
  if (typeof e === "string") return e;
  try {
    return JSON.stringify(e) ?? String(e);
  } catch {
    return String(e);
  }
}
