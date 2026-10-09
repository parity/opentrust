import { createCipheriv, createDecipheriv, randomBytes } from "node:crypto";

// Encrypts a merchant's OpenTrust API key before it is stored. `secret` is a 32-byte key (64 hex characters, or base64)
// kept in the ENCRYPTION_KEY environment variable, never in the database or the repo.

function key(secret: string): Buffer {
  const buf = /^[0-9a-f]{64}$/i.test(secret) ? Buffer.from(secret, "hex") : Buffer.from(secret, "base64");
  if (buf.length !== 32) throw new Error("ENCRYPTION_KEY must be 32 bytes (64 hex characters or base64)");
  return buf;
}

export function encryptSecret(plain: string, secret: string): string {
  const iv = randomBytes(12);
  const cipher = createCipheriv("aes-256-gcm", key(secret), iv);
  const enc = Buffer.concat([cipher.update(String(plain), "utf8"), cipher.final()]);
  return [iv, cipher.getAuthTag(), enc].map((b) => b.toString("base64")).join(".");
}

export function decryptSecret(token: string, secret: string): string {
  const [iv, tag, enc] = String(token).split(".").map((p) => Buffer.from(p, "base64"));
  const decipher = createDecipheriv("aes-256-gcm", key(secret), iv);
  decipher.setAuthTag(tag);
  return Buffer.concat([decipher.update(enc), decipher.final()]).toString("utf8");
}
