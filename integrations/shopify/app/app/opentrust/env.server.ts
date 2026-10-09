/** The key that encrypts stored OpenTrust API keys. Refuse to run without it rather than store keys unprotected. */
export function encryptionKey(): string {
  const k = process.env.ENCRYPTION_KEY;
  if (!k) throw new Error("ENCRYPTION_KEY is not set (32 random bytes as 64 hex characters)");
  return k;
}
