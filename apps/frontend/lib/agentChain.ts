// Real multi-agent deep-research pipeline — server-side, free.
//   Planner   → live LLM (Cloudflare Workers AI) breaks the goal into sub-questions
//   Researcher→ real Wikipedia REST fetches (no API key) gather factual sources
//   Writer    → live LLM synthesizes a cited answer from the sources
// No fabricated steps: every role output is a genuine model reply or a real fetch.

import { cfConfigured, cfChatCompletion } from "./cfWorkersAi";

export type Source = { title: string; url: string; extract: string };
export type AgentStep = { role: string; label: string; content: string; ms: number };
export type AgentRun = {
  goal: string;
  provider: string;
  steps: AgentStep[];
  sources: Source[];
  answer: string;
};

async function llm(system: string, user: string, maxTokens: number): Promise<string> {
  const out = await cfChatCompletion({
    model: "default",
    messages: [
      { role: "system", content: system },
      { role: "user", content: user },
    ],
    max_tokens: maxTokens,
    temperature: 0.4,
  });
  const choices = out.choices as Array<{ message?: { content?: string } }> | undefined;
  return choices?.[0]?.message?.content?.trim() ?? "";
}

async function wikiResearch(goal: string, lang = "de"): Promise<Source[]> {
  const sources: Source[] = [];
  try {
    const searchUrl = `https://${lang}.wikipedia.org/w/api.php?action=query&list=search&srsearch=${encodeURIComponent(goal)}&srlimit=3&format=json`;
    const res = await fetch(searchUrl, { headers: { "user-agent": "cloud-superbrain/1.0 (research)" }, signal: AbortSignal.timeout(8000) });
    const data = (await res.json()) as { query?: { search?: Array<{ title: string }> } };
    const titles = (data.query?.search ?? []).slice(0, 3).map((s) => s.title);
    for (const title of titles) {
      try {
        const sum = await fetch(`https://${lang}.wikipedia.org/api/rest_v1/page/summary/${encodeURIComponent(title)}`, {
          headers: { "user-agent": "cloud-superbrain/1.0 (research)" },
          signal: AbortSignal.timeout(8000),
        });
        if (!sum.ok) continue;
        const s = (await sum.json()) as { title?: string; extract?: string; content_urls?: { desktop?: { page?: string } } };
        if (s.extract) {
          sources.push({
            title: s.title ?? title,
            url: s.content_urls?.desktop?.page ?? `https://${lang}.wikipedia.org/wiki/${encodeURIComponent(title)}`,
            extract: s.extract,
          });
        }
      } catch {
        /* skip this source */
      }
    }
  } catch {
    /* research degrades to LLM-only if Wikipedia is unreachable */
  }
  return sources;
}

export async function runDeepResearch(goal: string): Promise<AgentRun> {
  if (!cfConfigured()) throw new Error("LLM provider not configured (CF_WORKERS_AI_TOKEN + CLOUDFLARE_ACCOUNT_ID)");
  const steps: AgentStep[] = [];

  // 1) Planner
  let t = Date.now();
  const plan = await llm(
    "Du bist der Planner-Agent. Zerlege das Ziel in 3 prägnante Rechercheteilfragen. Nur die Fragen, nummeriert.",
    `Ziel: ${goal}`,
    180,
  );
  steps.push({ role: "planner", label: "Planner (LLM)", content: plan, ms: Date.now() - t });

  // 2) Researcher — real web sources (German first, English fallback)
  t = Date.now();
  let sources = await wikiResearch(goal, "de");
  if (!sources.length) sources = await wikiResearch(goal, "en");
  steps.push({
    role: "researcher",
    label: "Researcher (Wikipedia, echt)",
    content: sources.length ? sources.map((s) => `• ${s.title} — ${s.url}`).join("\n") : "Keine Wikipedia-Quelle gefunden; Writer arbeitet LLM-only.",
    ms: Date.now() - t,
  });

  // 3) Writer — synthesize with sources
  t = Date.now();
  const ctx = sources.map((s, i) => `[${i + 1}] ${s.title}: ${s.extract}`).join("\n\n").slice(0, 4000);
  const answer = await llm(
    "Du bist der Writer-Agent. Schreibe eine fundierte, strukturierte Antwort auf das Ziel. Nutze die Quellen und zitiere mit [1],[2],[3]. Wenn Quellen fehlen, kennzeichne Unsicherheit.",
    `Ziel: ${goal}\n\nPlan:\n${plan}\n\nQuellen:\n${ctx || "(keine)"}`,
    420,
  );
  steps.push({ role: "writer", label: "Writer (LLM)", content: answer, ms: Date.now() - t });

  return { goal, provider: "cloudflare_workers_ai", steps, sources, answer };
}
