-- New installs check every order; "only cash-on-delivery" is an opt-in. Existing rows keep what they saved.
ALTER TABLE "OpenTrustSettings" ALTER COLUMN "onlyCod" SET DEFAULT false;
