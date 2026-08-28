// Runnability guard for AI-generated single-file web apps.
//
// The workbench persists whatever the model returns. A document can be syntactically complete —
// correct doctype, closing </html>, under the size cap — and still be dead on arrival because it
// loads a script URL that no longer exists. That is not a hypothetical: three.js removed the
// examples/js directory in r150, and a model trained on older tutorials keeps emitting those
// paths against a pinned modern version. The tags 404, the classes stay undefined, and the first
// call throws before any geometry is built.
//
// So structural completeness is not enough. This module answers a narrower question: does the
// document reference something that provably cannot load or execute as written?

/** Every opening `<script …>` tag; its attributes are inspected separately. */
const HTML_COMMENT = /<!--[\s\S]*?-->/g;
const SCRIPT_TAG = /<script\b([^>]*)>/gi;
const SCRIPT_BLOCK = /<script\b([^>]*)>([\s\S]*?)<\/script>/gi;
const SRC_ATTR = /\bsrc\s*=\s*(?:"([^"]+)"|'([^']+)'|([^\s"'=<>`]+))/i;
const TYPE_ATTR = /\btype\s*=\s*(?:"([^"]+)"|'([^']+)'|([^\s"'=<>`]+))/i;

type DeadReference = {
  /** Matches the resolved script URL. */
  test: (url: string) => boolean;
  /** Whether a module script may execute this path when a three import map is present. */
  moduleAllowedWithImportMap: boolean;
  /** Explains why it cannot run, for the build boundary's rejection message. */
  describe: (url: string) => string;
};

const DEAD_REFERENCES: DeadReference[] = [
  {
    // Removed from the three.js package in r150. Every file under it answers 404.
    test: (url) => /\/three(?:@[^/]*)?\/examples\/js\//i.test(url),
    moduleAllowedWithImportMap: false,
    describe: (url) =>
      `three.js examples/js was removed in r150 and this URL returns 404: ${lastSegment(url)}`,
  },
  {
    // examples/jsm is ES modules. A classic script tag cannot execute an ES module, so the
    // expected global is never defined and the document fails exactly like examples/js did.
    test: (url) => /\/three(?:@[^/]*)?\/examples\/jsm\//i.test(url),
    moduleAllowedWithImportMap: true,
    describe: (url) =>
      `three.js examples/jsm requires type=module plus a three import map: ${lastSegment(url)}`,
  },
];

function lastSegment(url: string): string {
  const clean = url.split(/[?#]/)[0];
  return clean.slice(clean.lastIndexOf("/") + 1) || clean;
}

/**
 * Returns one human-readable reason per script reference that cannot load or execute.
 * An empty array means nothing known-dead was referenced.
 */
export function findUnrunnableReferences(html: string): string[] {
  const reasons: string[] = [];
  const executableMarkup = html.replace(HTML_COMMENT, "");
  const hasThreeImportMap = [...executableMarkup.matchAll(SCRIPT_BLOCK)].some(([, attributes, body]) => {
    const typeMatch = attributes.match(TYPE_ATTR);
    const scriptType = (typeMatch?.[1] ?? typeMatch?.[2] ?? typeMatch?.[3] ?? "").toLowerCase();
    if (scriptType !== "importmap") return false;
    try {
      const parsed = JSON.parse(body) as { imports?: Record<string, unknown> };
      return typeof parsed.imports?.three === "string" && parsed.imports.three.trim().length > 0;
    } catch {
      return false;
    }
  });
  for (const [, attributes] of executableMarkup.matchAll(SCRIPT_TAG)) {
    const typeMatch = attributes.match(TYPE_ATTR);
    const scriptType = (typeMatch?.[1] ?? typeMatch?.[2] ?? typeMatch?.[3] ?? "").toLowerCase();
    const isModule = scriptType === "module";
    const srcMatch = attributes.match(SRC_ATTR);
    const src = srcMatch?.[1] ?? srcMatch?.[2] ?? srcMatch?.[3];
    if (!src) continue;
    for (const dead of DEAD_REFERENCES) {
      const allowedModule = isModule && hasThreeImportMap && dead.moduleAllowedWithImportMap;
      if (dead.test(src) && !allowedModule) reasons.push(dead.describe(src));
    }
  }
  return reasons;
}

/** True when the document references nothing that provably cannot load. */
export function isRunnableGeneratedHtml(html: string): boolean {
  return findUnrunnableReferences(html).length === 0;
}
