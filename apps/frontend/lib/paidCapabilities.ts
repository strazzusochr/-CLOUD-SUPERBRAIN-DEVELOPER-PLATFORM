type SearchParamValue = string | string[] | undefined;
type SearchParams = Record<string, SearchParamValue>;

const PAID_SELECTION_IDS = new Set([
  "live_llm",
  "paid_llm",
  "openai",
  "anthropic",
  "azure_openai",
  "cloudflare_ai_gateway",
  "e2b_mcp",
  "cloud_browser",
  "cloud_render_worker",
]);

const PAID_OPTION_ENV_KEYS = [
  "PAID_CAPABILITIES_ENABLED",
  "PAID_LLM_ENABLED",
  "ENABLE_PAID_TOOL_OPTIONS",
  "LIVE_LLM_TEST_CALL_APPROVED",
];

function firstValue(value: SearchParamValue): string {
  if (Array.isArray(value)) return String(value[0] ?? "");
  return String(value ?? "");
}

function envEnabled(key: string): boolean {
  const value = process.env[key];
  if (!value) return false;
  return !/^(0|false|no|off|disabled)$/i.test(value.trim());
}

export function paidCapabilityVisible(searchParams: SearchParams = {}): boolean {
  const selected = [
    firstValue(searchParams.capability),
    firstValue(searchParams.tool),
    firstValue(searchParams.model),
    firstValue(searchParams.provider),
    firstValue(searchParams.billing),
  ]
    .map((value) => value.trim().toLowerCase().replace(/[\s-]+/g, "_"))
    .filter(Boolean);

  const selectedPaidCapability = selected.some((value) => (
    value === "paid"
    || value === "paid_option"
    || value === "costed"
    || PAID_SELECTION_IDS.has(value)
  ));

  const gatewayMode = (process.env.LLM_GATEWAY_MODE || "").trim().toLowerCase();
  const paidGatewayMode = Boolean(gatewayMode && !/^(deterministic_dry_run|dry_run|mock|local)$/i.test(gatewayMode));
  const paidOptionConfigured = PAID_OPTION_ENV_KEYS.some(envEnabled) || paidGatewayMode;

  return selectedPaidCapability || paidOptionConfigured;
}
