// Classification of a cloud provider's inventory status for display.
//
// The inventory distinguishes states that a substring match cannot: a provider
// reported as `historical_read_verified` is retired — the contract labels it
// `historical_only ... not an active runtime target` — yet the string contains
// "verified". Matching on the substring painted that retired provider the same
// green as the genuinely live runtime, which is a live claim the evidence does
// not support. Classification is therefore exact, not substring-based.

export type ProviderTone = "green" | "amber" | "violet";

/** Statuses that genuinely mean "verified right now". */
const VERIFIED_NOW = new Set(["live_verified", "verified"]);

/** Statuses that mean "known and configured, but not currently verified". */
const KNOWN_NOT_VERIFIED = new Set([
  "partial",
  "configured",
  "metadata_only",
  "action_required",
  "api_error",
  "historical_read_verified",
  "historical_only",
]);

/**
 * Returns the display tone for a provider status. Only a currently verified
 * provider reads green; a retired provider never does, however its status is
 * spelled.
 */
export function providerStatusTone(status: string): ProviderTone {
  const normalized = (status ?? "").trim().toLowerCase();
  if (VERIFIED_NOW.has(normalized)) return "green";
  if (KNOWN_NOT_VERIFIED.has(normalized)) return "amber";
  return "violet";
}
