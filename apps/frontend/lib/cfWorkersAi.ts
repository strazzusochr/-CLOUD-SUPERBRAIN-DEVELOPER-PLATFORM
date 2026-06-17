// Real free LLM provider: Cloudflare Workers AI.
//
// Translates an OpenAI-style chat/completions request into a Workers AI run and
// back, so the existing `/llm/v1/chat/completions` button calls become genuinely
// live the moment a Workers-AI-scoped token + account id are in the environment
// (CF_WORKERS_AI_TOKEN | CLOUDFLARE_API_TOKEN, CLOUDFLARE_ACCOUNT_ID). No key →
// caller returns honest no_live_backend. Never fabricates a completion.

const DEFAULT_MODEL = "@cf/meta/llama-3.1-8b-instruct";

export function cfConfigured(): boolean {
  const tok = process.env.CF_WORKERS_AI_TOKEN || process.env.CLOUDFLARE_API_TOKEN;
  return !!(tok && process.env.CLOUDFLARE_ACCOUNT_ID);
}

type ChatMessage = { role: string; content: string };

function mapModel(model: unknown): string {
  const m = typeof model === "string" ? model.trim() : "";
  if (!m || m === "default") return DEFAULT_MODEL;
  // Already a CF model id
  if (m.startsWith("@cf/")) return m;
  // Common OpenAI-style aliases → CF equivalents
  const lower = m.toLowerCase();
  if (lower.includes("llama")) return "@cf/meta/llama-3.1-8b-instruct";
  if (lower.includes("qwen")) return "@cf/qwen/qwen1.5-14b-chat-awq";
  if (lower.includes("mistral")) return "@cf/mistral/mistral-7b-instruct-v0.2";
  return DEFAULT_MODEL;
}

/** Real free embedding via Cloudflare Workers AI (bge-base-en-v1.5, 768-dim). */
export async function cfEmbed(text: string): Promise<number[]> {
  const token = process.env.CF_WORKERS_AI_TOKEN || process.env.CLOUDFLARE_API_TOKEN;
  const account = process.env.CLOUDFLARE_ACCOUNT_ID?.replace(/^["']|["']$/g, "");
  if (!token || !account) throw new Error("CF Workers AI not configured");
  const res = await fetch(`https://api.cloudflare.com/client/v4/accounts/${account}/ai/run/@cf/baai/bge-base-en-v1.5`, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "content-type": "application/json" },
    body: JSON.stringify({ text: [text] }),
    signal: AbortSignal.timeout(20000),
  });
  const data = (await res.json()) as { success?: boolean; result?: { data?: number[][] }; errors?: Array<{ message?: string }> };
  if (!res.ok || !data.success || !data.result?.data?.[0]) {
    throw new Error(`CF embedding error: ${data.errors?.map((e) => e.message).join("; ") || res.status}`);
  }
  return data.result.data[0];
}

/** Returns an OpenAI-shaped chat completion, or throws with a clear message. */
export async function cfChatCompletion(payload: {
  model?: unknown;
  messages?: ChatMessage[];
  max_tokens?: number;
  temperature?: number;
  stream?: boolean;
}): Promise<Record<string, unknown>> {
  const token = process.env.CF_WORKERS_AI_TOKEN || process.env.CLOUDFLARE_API_TOKEN;
  const account = process.env.CLOUDFLARE_ACCOUNT_ID?.replace(/^["']|["']$/g, "");
  if (!token || !account) throw new Error("CF Workers AI not configured");

  const model = mapModel(payload.model);
  const messages = Array.isArray(payload.messages) ? payload.messages : [];
  const body: Record<string, unknown> = { messages };
  if (typeof payload.max_tokens === "number") body.max_tokens = payload.max_tokens;
  if (typeof payload.temperature === "number") body.temperature = payload.temperature;

  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), 30000);
  try {
    const res = await fetch(
      `https://api.cloudflare.com/client/v4/accounts/${account}/ai/run/${model}`,
      {
        method: "POST",
        headers: { Authorization: `Bearer ${token}`, "content-type": "application/json" },
        body: JSON.stringify(body),
        signal: ctrl.signal,
      },
    );
    const data = (await res.json()) as {
      success?: boolean;
      result?: { response?: string; choices?: Array<{ message?: { content?: string } }> };
      errors?: Array<{ message?: string }>;
    };
    if (!res.ok || !data.success) {
      const msg = data.errors?.map((e) => e.message).join("; ") || `HTTP ${res.status}`;
      throw new Error(`Cloudflare Workers AI error: ${msg}`);
    }
    // Newer Workers AI returns OpenAI-shaped result.choices[]; older returns result.response.
    const content = data.result?.choices?.[0]?.message?.content ?? data.result?.response ?? "";
    const now = Math.floor(Date.now() / 1000);
    return {
      id: `cf-${now}`,
      object: "chat.completion",
      created: now,
      model,
      provider: "cloudflare_workers_ai",
      choices: [{ index: 0, message: { role: "assistant", content }, finish_reason: "stop" }],
      usage: { prompt_tokens: null, completion_tokens: null, total_tokens: null },
    };
  } finally {
    clearTimeout(timer);
  }
}
