import { promises as fs } from "node:fs";
import path from "node:path";
import { NextResponse } from "next/server";

export const dynamic = "force-dynamic";
export const revalidate = 0;

type ExportRequest = {
  format?: "md" | "pdf";
  title?: string;
  content?: string;
  projectId?: string;
  sessionId?: string | null;
};

function tempExportDir() {
  const base = process.env.EVIDENCE_DIR?.trim() || "/tmp";
  return path.join(base, "F9", "docs-export");
}

function sanitizeName(value: string) {
  const cleaned = value
    .normalize("NFKD")
    .replace(/[^\x20-\x7E]/g, "")
    .replace(/[^a-zA-Z0-9._ -]+/g, "-")
    .trim()
    .replace(/\s+/g, "-")
    .replace(/-+/g, "-")
    .slice(0, 80);
  return cleaned || "document-export";
}

function asciiPdfText(value: string) {
  return value
    .normalize("NFKD")
    .replace(/[^\x20-\x7E\n]/g, "")
    .replace(/\\/g, "\\\\")
    .replace(/\(/g, "\\(")
    .replace(/\)/g, "\\)");
}

function wrapPdfLines(value: string, width = 92) {
  const blocks = value.replace(/\r\n/g, "\n").split("\n");
  const lines: string[] = [];
  for (const block of blocks) {
    const trimmed = block.trimEnd();
    if (!trimmed) {
      lines.push("");
      continue;
    }
    const words = trimmed.split(/\s+/);
    let current = "";
    for (const word of words) {
      const next = current ? `${current} ${word}` : word;
      if (next.length > width && current) {
        lines.push(current);
        current = word;
      } else {
        current = next;
      }
    }
    if (current) lines.push(current);
  }
  return lines;
}

function buildPlainTextPdf(title: string, content: string) {
  const lines = wrapPdfLines(`Title: ${title}\n\n${content}`);
  const pageHeight = 792;
  const marginTop = 54;
  const lineHeight = 14;
  const linesPerPage = 46;
  const pages: string[][] = [];
  for (let i = 0; i < lines.length; i += linesPerPage) {
    pages.push(lines.slice(i, i + linesPerPage));
  }
  if (!pages.length) pages.push([""]);

  const objects: string[] = [];
  objects[1] = "";
  objects[2] = "";
  objects[3] = "<< /Type /Font /Subtype /Type1 /BaseFont /Courier >>";

  const pageRefs: string[] = [];
  pages.forEach((pageLines, index) => {
    const pageObjectId = 4 + index * 2;
    const contentObjectId = pageObjectId + 1;
    pageRefs.push(`${pageObjectId} 0 R`);
    const contentStream = pageLines.map((line, lineIndex) => {
      const y = pageHeight - marginTop - lineIndex * lineHeight;
      return `BT /F1 11 Tf 54 ${y} Td (${asciiPdfText(line)}) Tj ET`;
    }).join("\n");
    objects[pageObjectId] = `<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 ${pageHeight}] /Resources << /Font << /F1 3 0 R >> >> /Contents ${contentObjectId} 0 R >>`;
    objects[contentObjectId] = `<< /Length ${Buffer.byteLength(contentStream, "utf8")} >>\nstream\n${contentStream}\nendstream`;
  });

  objects[2] = `<< /Type /Pages /Count ${pages.length} /Kids [${pageRefs.join(" ")}] >>`;
  objects[1] = "<< /Type /Catalog /Pages 2 0 R >>";

  let pdf = "%PDF-1.4\n";
  const offsets: number[] = [0];
  for (let i = 1; i < objects.length; i += 1) {
    offsets[i] = Buffer.byteLength(pdf, "utf8");
    pdf += `${i} 0 obj\n${objects[i]}\nendobj\n`;
  }
  const xrefStart = Buffer.byteLength(pdf, "utf8");
  pdf += `xref\n0 ${objects.length}\n`;
  pdf += "0000000000 65535 f \n";
  for (let i = 1; i < objects.length; i += 1) {
    pdf += `${String(offsets[i]).padStart(10, "0")} 00000 n \n`;
  }
  pdf += `trailer\n<< /Size ${objects.length} /Root 1 0 R >>\nstartxref\n${xrefStart}\n%%EOF`;
  return Buffer.from(pdf, "utf8");
}

async function writeExportFile(request: ExportRequest) {
  const format = request.format === "pdf" ? "pdf" : "md";
  const now = new Date().toISOString().replace(/[:.]/g, "-");
  const title = (request.title || "Cloud Superbrain Export").trim();
  const content = (request.content || "").trim() || "No session output available for export.";
  const baseName = `${sanitizeName(title)}-${now}`;
  const fileName = `${baseName}.${format}`;
  const dir = tempExportDir();
  await fs.mkdir(dir, { recursive: true });
  const filePath = path.join(dir, fileName);
  const buffer = format === "pdf"
    ? buildPlainTextPdf(title, content)
    : Buffer.from(`# ${title}\n\n${content}\n`, "utf8");
  await fs.writeFile(filePath, buffer);
  const meta = {
    created_at: new Date().toISOString(),
    title,
    format,
    bytes: buffer.byteLength,
    file_name: fileName,
    runtime_store: filePath,
    project_id: request.projectId || "goal-b-local",
    session_id: request.sessionId || null,
    source: (request.content || "").trim() ? "page_selection" : "fallback_message",
  };
  await fs.writeFile(path.join(dir, `${baseName}.json`), JSON.stringify(meta, null, 2), "utf8");
  await fs.writeFile(path.join(dir, "latest.json"), JSON.stringify(meta, null, 2), "utf8");
  return meta;
}

export async function POST(request: Request) {
  const body = await request.json() as ExportRequest;
  const meta = await writeExportFile(body);
  return NextResponse.json({
    ok: true,
    ...meta,
    download_url: `/exports/docs?file=${encodeURIComponent(meta.file_name)}`,
  });
}

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const fileName = path.basename(searchParams.get("file") || "");
  if (!fileName) {
    return NextResponse.json({ detail: "file query parameter required" }, { status: 400 });
  }
  const filePath = path.join(tempExportDir(), fileName);
  try {
    const data = await fs.readFile(filePath);
    const contentType = fileName.endsWith(".pdf") ? "application/pdf" : "text/markdown; charset=utf-8";
    return new NextResponse(data, {
      headers: {
        "content-type": contentType,
        "content-disposition": `attachment; filename="${fileName}"`,
        "cache-control": "no-store",
      },
    });
  } catch {
    return NextResponse.json({ detail: "export file not found" }, { status: 404 });
  }
}
