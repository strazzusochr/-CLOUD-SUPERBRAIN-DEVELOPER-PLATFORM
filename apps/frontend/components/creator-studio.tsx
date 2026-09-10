"use client";

import { useEffect, useRef, useState } from "react";

// Real, free, client-side executable actions — no backend, no LLM, no network.
// Three genuine generators that produce real downloadable artifacts:
//   • Doc:   Markdown → live HTML preview → download .md / .html
//   • Music: Web Audio generative synth → play/stop → record to a real audio file
//   • Video: animated canvas → MediaRecorder → download a real .webm clip
// Each is feature-detected and degrades honestly if the browser lacks the API.

type Tab = "doc" | "music" | "video";

function download(filename: string, blob: Blob) {
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 2000);
}

// Minimal, safe Markdown → HTML (headings, bold, italic, code, lists, paragraphs).
function mdToHtml(md: string): string {
  const esc = (s: string) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
  const lines = md.split("\n");
  const out: string[] = [];
  let inList = false;
  for (const raw of lines) {
    let line = esc(raw);
    line = line.replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>").replace(/\*(.+?)\*/g, "<em>$1</em>").replace(/`(.+?)`/g, "<code>$1</code>");
    const h = raw.match(/^(#{1,4})\s+(.*)$/);
    if (h) { if (inList) { out.push("</ul>"); inList = false; } out.push(`<h${h[1].length}>${esc(h[2])}</h${h[1].length}>`); continue; }
    if (/^\s*[-*]\s+/.test(raw)) { if (!inList) { out.push("<ul>"); inList = true; } out.push(`<li>${line.replace(/^\s*[-*]\s+/, "")}</li>`); continue; }
    if (inList) { out.push("</ul>"); inList = false; }
    if (raw.trim() === "") out.push(""); else out.push(`<p>${line}</p>`);
  }
  if (inList) out.push("</ul>");
  return out.join("\n");
}

function DocTool() {
  const [title, setTitle] = useState("Superbrain Spec");
  const [md, setMd] = useState(
    "# Superbrain Spec\n\nEin **echtes** Dokument, im Browser generiert.\n\n- Punkt eins\n- Punkt zwei\n\nInline `code` und *kursiv*.",
  );
  const html = mdToHtml(md);
  const htmlDoc = `<!doctype html><html lang="de"><head><meta charset="utf-8"><title>${title}</title><meta name="viewport" content="width=device-width,initial-scale=1"><style>body{font:16px/1.6 system-ui,sans-serif;max-width:760px;margin:40px auto;padding:0 20px;color:#1a2230}code{background:#eef;padding:1px 5px;border-radius:4px}h1,h2,h3{line-height:1.25}</style></head><body>\n${html}\n</body></html>`;
  const slug = title.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "") || "dokument";
  return (
    <div className="cs-tool" data-testid="cs-doc">
      <input className="cs-input" value={title} onChange={(e) => setTitle(e.target.value)} aria-label="Titel" />
      <textarea className="cs-textarea mono" value={md} onChange={(e) => setMd(e.target.value)} rows={8} aria-label="Markdown" />
      <div className="cs-row">
        <button type="button" className="btn btn-sm btn-primary" data-testid="cs-doc-md" onClick={() => download(`${slug}.md`, new Blob([md], { type: "text/markdown" }))}>↓ Markdown</button>
        <button type="button" className="btn btn-sm" data-testid="cs-doc-html" onClick={() => download(`${slug}.html`, new Blob([htmlDoc], { type: "text/html" }))}>↓ HTML</button>
        <span className="text-12 text-mut">{md.length} Zeichen · {md.split(/\n/).length} Zeilen</span>
      </div>
      <div className="cs-preview" dangerouslySetInnerHTML={{ __html: html }} />
    </div>
  );
}

function MusicTool() {
  const [playing, setPlaying] = useState(false);
  const [recording, setRecording] = useState(false);
  const [supported, setSupported] = useState(true);
  const ctxRef = useRef<AudioContext | null>(null);
  const stopRef = useRef<(() => void) | null>(null);
  const recRef = useRef<MediaRecorder | null>(null);

  useEffect(() => {
    queueMicrotask(() => setSupported(typeof window !== "undefined" && !!(window.AudioContext || (window as unknown as { webkitAudioContext?: unknown }).webkitAudioContext)));
    return () => { stopRef.current?.(); ctxRef.current?.close().catch(() => {}); };
  }, []);

  const ensureCtx = () => {
    if (!ctxRef.current) {
      const AC = window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
      ctxRef.current = new AC();
    }
    return ctxRef.current;
  };

  // Generative pentatonic arpeggio over a soft pad. Returns a stop fn + a destination stream for recording.
  const startEngine = (ctx: AudioContext) => {
    const master = ctx.createGain();
    master.gain.value = 0.18;
    const dest = ctx.createMediaStreamDestination();
    master.connect(ctx.destination);
    master.connect(dest);
    const scale = [0, 3, 5, 7, 10, 12, 15];
    const base = 220;
    let step = 0;
    const interval = setInterval(() => {
      const semi = scale[Math.floor(Math.random() * scale.length)] + (Math.random() < 0.3 ? 12 : 0);
      const freq = base * Math.pow(2, semi / 12);
      const osc = ctx.createOscillator();
      const g = ctx.createGain();
      osc.type = step % 4 === 0 ? "triangle" : "sine";
      osc.frequency.value = freq;
      const t = ctx.currentTime;
      g.gain.setValueAtTime(0, t);
      g.gain.linearRampToValueAtTime(0.9, t + 0.02);
      g.gain.exponentialRampToValueAtTime(0.001, t + 0.5);
      osc.connect(g); g.connect(master);
      osc.start(t); osc.stop(t + 0.55);
      step++;
    }, 240);
    const stop = () => { clearInterval(interval); master.disconnect(); };
    return { stop, stream: dest.stream };
  };

  const toggle = async () => {
    if (playing) { stopRef.current?.(); stopRef.current = null; setPlaying(false); return; }
    const ctx = ensureCtx();
    if (ctx.state === "suspended") await ctx.resume();
    const { stop } = startEngine(ctx);
    stopRef.current = stop;
    setPlaying(true);
  };

  const record = async () => {
    if (recording) return;
    const ctx = ensureCtx();
    if (ctx.state === "suspended") await ctx.resume();
    const { stop, stream } = startEngine(ctx);
    stopRef.current = stop; setPlaying(true);
    const mime = MediaRecorder.isTypeSupported("audio/webm") ? "audio/webm" : "audio/ogg";
    const rec = new MediaRecorder(stream, { mimeType: mime });
    const chunks: BlobPart[] = [];
    rec.ondataavailable = (e) => { if (e.data.size) chunks.push(e.data); };
    rec.onstop = () => { download(`superbrain-track.${mime.includes("ogg") ? "ogg" : "webm"}`, new Blob(chunks, { type: mime })); };
    recRef.current = rec; rec.start();
    setRecording(true);
    setTimeout(() => { rec.stop(); recRef.current = null; setRecording(false); stop(); stopRef.current = null; setPlaying(false); }, 6000);
  };

  if (!supported) return <div className="note blocked">Web Audio wird von diesem Browser nicht unterstützt.</div>;
  return (
    <div className="cs-tool" data-testid="cs-music">
      <p className="text-13 text-mut">Generativer Web-Audio-Synth (pentatonisch). Echte Audioausgabe, 6 s Aufnahme als Datei.</p>
      <div className="cs-row">
        <button type="button" className="btn btn-sm btn-primary" data-testid="cs-music-play" onClick={toggle}>{playing ? "■ Stoppen" : "▶ Abspielen"}</button>
        <button type="button" className="btn btn-sm" data-testid="cs-music-rec" onClick={record} disabled={recording}>{recording ? "● nimmt auf… (6s)" : "● 6s aufnehmen + ↓"}</button>
      </div>
    </div>
  );
}

function VideoTool() {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const [recording, setRecording] = useState(false);
  const [supported, setSupported] = useState(true);
  const rafRef = useRef(0);

  useEffect(() => {
    const c = canvasRef.current;
    if (!c) return;
    queueMicrotask(() => setSupported(typeof MediaRecorder !== "undefined" && typeof c.captureStream === "function"));
    const ctx = c.getContext("2d");
    if (!ctx) return;
    let t = 0;
    const draw = () => {
      rafRef.current = requestAnimationFrame(draw);
      t += 0.016;
      ctx.fillStyle = "#05060f"; ctx.fillRect(0, 0, c.width, c.height);
      for (let i = 0; i < 60; i++) {
        const a = (i / 60) * Math.PI * 2 + t;
        const r = 70 + Math.sin(t * 1.5 + i) * 40;
        const x = c.width / 2 + Math.cos(a) * r;
        const y = c.height / 2 + Math.sin(a) * r;
        ctx.beginPath();
        ctx.arc(x, y, 3 + Math.sin(t * 3 + i) * 2, 0, Math.PI * 2);
        ctx.fillStyle = `hsl(${(i * 6 + t * 60) % 360} 90% 60%)`;
        ctx.fill();
      }
      ctx.fillStyle = "rgba(255,255,255,0.9)";
      ctx.font = "16px system-ui"; ctx.fillText("● superbrain-render", 14, 26);
    };
    draw();
    return () => cancelAnimationFrame(rafRef.current);
  }, []);

  const record = () => {
    const c = canvasRef.current;
    if (!c || recording) return;
    const stream = c.captureStream(30);
    const mime = MediaRecorder.isTypeSupported("video/webm;codecs=vp9") ? "video/webm;codecs=vp9" : "video/webm";
    const rec = new MediaRecorder(stream, { mimeType: mime });
    const chunks: BlobPart[] = [];
    rec.ondataavailable = (e) => { if (e.data.size) chunks.push(e.data); };
    rec.onstop = () => { download("superbrain-clip.webm", new Blob(chunks, { type: "video/webm" })); setRecording(false); };
    rec.start(); setRecording(true);
    setTimeout(() => rec.stop(), 5000);
  };

  return (
    <div className="cs-tool" data-testid="cs-video">
      <canvas ref={canvasRef} width={480} height={270} className="cs-canvas" />
      <div className="cs-row">
        <button type="button" className="btn btn-sm btn-primary" data-testid="cs-video-rec" onClick={record} disabled={recording || !supported}>{recording ? "● rendert… (5s)" : "● 5s Clip aufnehmen + ↓"}</button>
        {!supported ? <span className="text-12 text-mut">MediaRecorder/captureStream nicht verfügbar.</span> : null}
      </div>
    </div>
  );
}

export function CreatorStudio({ only, tabs: tabsProp }: { only?: Tab; tabs?: Tab[] }) {
  const tabs: Tab[] = only ? [only] : (tabsProp && tabsProp.length ? tabsProp : ["doc", "music", "video"]);
  const [tab, setTab] = useState<Tab>(tabs[0]);
  const labels: Record<Tab, string> = { doc: "Dokument", music: "Musik", video: "Video" };
  return (
    <div className="creator-studio" data-testid="creator-studio">
      {only ? null : (
        <div className="cs-tabs">
          {tabs.map((t) => (
            <button key={t} type="button" className={`btn btn-sm ${tab === t ? "btn-primary" : "btn-ghost"}`} onClick={() => setTab(t)} data-testid={`cs-tab-${t}`}>{labels[t]}</button>
          ))}
        </div>
      )}
      {tab === "doc" ? <DocTool /> : null}
      {tab === "music" ? <MusicTool /> : null}
      {tab === "video" ? <VideoTool /> : null}
    </div>
  );
}
