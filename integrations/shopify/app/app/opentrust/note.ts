import type { LookupResult } from "./client";

export const DISCLAIMER =
  "These are unverified observations from individual merchants, not a finding about the customer. Please review the order yourself before deciding anything.";

const strip = (s: unknown) => String(s ?? "").replace(/<[^>]*>/g, "").trim();

const CONFIRMED_BY: Record<string, string> = { bank: "a bank", payment_gateway: "a payment gateway", law_enforcement: "law enforcement" };

/** Plain-text note for an order whose number has reports. */
export function buildNote(lookup: Pick<LookupResult, "reportCount" | "reports">): string {
  const n = lookup.reportCount;
  const lines = [`OpenTrust: ${n} ${n === 1 ? "merchant has" : "merchants have"} noted experiences with this number.`];
  for (const r of lookup.reports ?? []) {
    let line = `• ${strip(r.reason || r.reasonCode)}`;
    if (r.notes) line += `: "${strip(r.notes)}"`;
    const when: string[] = [];
    if (r.incidentAt) when.push(`happened ${strip(r.incidentAt)}`);
    if (r.reportedAt) when.push(`reported ${strip(r.reportedAt)}`);
    if (r.confirmedBy && CONFIRMED_BY[r.confirmedBy]) when.push(`the reporter says it was confirmed by ${CONFIRMED_BY[r.confirmedBy]}`);
    if (when.length) line += ` (${when.join("; ")})`;
    // Shopify's timeline shows a note as one paragraph, so each line ends with a full stop to keep it readable.
    lines.push(`${line.replace(/[.\s]+$/, "")}.`);
  }
  lines.push(DISCLAIMER);
  return lines.join("\n");
}
