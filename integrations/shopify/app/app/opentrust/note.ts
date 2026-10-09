import type { LookupResult } from "./client";

export const DISCLAIMER =
  "These are unverified observations from individual merchants, not a finding about the customer. Please review the order yourself before deciding anything.";

const strip = (s: unknown) => String(s ?? "").replace(/<[^>]*>/g, "").trim();

/** Plain-text note for an order whose number has reports. */
export function buildNote(lookup: Pick<LookupResult, "reportCount" | "reports">): string {
  const n = lookup.reportCount;
  const lines = [`OpenTrust: ${n} ${n === 1 ? "merchant has" : "merchants have"} noted experiences with this number.`];
  for (const r of lookup.reports ?? []) {
    let line = `• ${strip(r.reason || r.reasonCode)}`;
    if (r.notes) line += `: "${strip(r.notes)}"`;
    if (r.reportedAt) line += ` (${strip(r.reportedAt)})`;
    lines.push(line);
  }
  lines.push(DISCLAIMER);
  return lines.join("\n");
}
