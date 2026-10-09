import prisma from "../db.server";
import type { SettingsStore } from "./handlers";

/** Settings (the encrypted OpenTrust API key and one switch) per shop, in the app's own database. */
export const store: SettingsStore = {
  async get(shop) {
    const row = await prisma.openTrustSettings.findUnique({ where: { shop } });
    return row ? { apiKeyEnc: row.apiKeyEnc, onlyCod: row.onlyCod } : null;
  },
  async set(shop, { apiKeyEnc, onlyCod }) {
    await prisma.openTrustSettings.upsert({
      where: { shop },
      create: { shop, apiKeyEnc, onlyCod },
      update: { apiKeyEnc, onlyCod },
    });
  },
  async delete(shop) {
    await prisma.openTrustSettings.deleteMany({ where: { shop } });
  },
};
