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
const THREE_GLOBAL_USE = /\b(?:new\s+)?THREE\s*\./;
const THREE_LOCAL_DEFINITION = /\b(?:const|let|var)\s+THREE\b|\b(?:window|globalThis)\.THREE\s*=/;
const THREE_NAMESPACE_IMPORT = /\bimport\s+\*\s+as\s+THREE\s+from\s*(?:"([^"]+)"|'([^']+)')/;
const THREE_CLASSIC_CORE = /(?:\/three(?:@[^/]*)?\/build\/three(?:\.min)?\.js|\/three(?:\.min)?\.js)(?:[?#]|$)/i;
const THREE_MODULE_CORE = /(?:\/three(?:@[^/]*)?\/build\/three\.module(?:\.min)?\.js|\/three\.module(?:\.min)?\.js)(?:[?#]|$)/i;
const PINNED_THREE_CLASSIC = '<script src="https://unpkg.com/three@0.160.0/build/three.min.js"></script>';

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

function attributeValue(attributes: string, pattern: RegExp): string {
  const match = attributes.match(pattern);
  return match?.[1] ?? match?.[2] ?? match?.[3] ?? "";
}

function hasThreeImportMap(executableMarkup: string): boolean {
  return [...executableMarkup.matchAll(SCRIPT_BLOCK)].some(([, attributes, body]) => {
    if (attributeValue(attributes, TYPE_ATTR).toLowerCase() !== "importmap") return false;
    try {
      const parsed = JSON.parse(body) as { imports?: Record<string, unknown> };
      return typeof parsed.imports?.three === "string" && parsed.imports.three.trim().length > 0;
    } catch {
      return false;
    }
  });
}

function hasRunnableThreeBinding(attributes: string, body: string, importMapPresent: boolean): boolean {
  if (THREE_LOCAL_DEFINITION.test(body)) return true;
  if (attributeValue(attributes, TYPE_ATTR).toLowerCase() !== "module") return false;
  const match = body.match(THREE_NAMESPACE_IMPORT);
  const specifier = match?.[1] ?? match?.[2] ?? "";
  if (!specifier) return false;
  return specifier === "three" ? importMapPresent : THREE_MODULE_CORE.test(specifier);
}

function missingThreeGlobalDependency(executableMarkup: string, importMapPresent: boolean): boolean {
  let threeUsed = false;
  let threeProvided = false;
  for (const [, attributes, body] of executableMarkup.matchAll(SCRIPT_BLOCK)) {
    const scriptType = attributeValue(attributes, TYPE_ATTR).toLowerCase();
    const src = attributeValue(attributes, SRC_ATTR);
    if (src && scriptType !== "module" && THREE_CLASSIC_CORE.test(src)) threeProvided = true;
    if (scriptType === "importmap" || !THREE_GLOBAL_USE.test(body)) continue;
    threeUsed = true;
    if (hasRunnableThreeBinding(attributes, body, importMapPresent)) threeProvided = true;
  }
  return threeUsed && !threeProvided;
}

/**
 * Returns one human-readable reason per script reference that cannot load or execute.
 * An empty array means nothing known-dead was referenced.
 */
export function findUnrunnableReferences(html: string): string[] {
  const reasons: string[] = [];
  const executableMarkup = html.replace(HTML_COMMENT, "");
  const importMapPresent = hasThreeImportMap(executableMarkup);
  for (const [, attributes] of executableMarkup.matchAll(SCRIPT_TAG)) {
    const scriptType = attributeValue(attributes, TYPE_ATTR).toLowerCase();
    const isModule = scriptType === "module";
    const src = attributeValue(attributes, SRC_ATTR);
    if (!src) continue;
    for (const dead of DEAD_REFERENCES) {
      const allowedModule = isModule && importMapPresent && dead.moduleAllowedWithImportMap;
      if (dead.test(src) && !allowedModule) reasons.push(dead.describe(src));
    }
  }
  if (missingThreeGlobalDependency(executableMarkup, importMapPresent)) {
    reasons.push("THREE is referenced but no compatible three.js core dependency is loaded");
  }
  return reasons;
}

/**
 * Repairs the single deterministic dependency omission observed in live generation. Persistence
 * boundaries still reject the raw broken form; only the trusted generation boundary calls this
 * helper before its fail-closed verdict.
 */
export function ensureGeneratedHtmlDependencies(html: string): string {
  const executableMarkup = html.replace(HTML_COMMENT, "");
  const importMapPresent = hasThreeImportMap(executableMarkup);
  if (!missingThreeGlobalDependency(executableMarkup, importMapPresent)) return html;
  for (const match of html.matchAll(SCRIPT_BLOCK)) {
    const attributes = match[1];
    const body = match[2];
    if (attributeValue(attributes, TYPE_ATTR).toLowerCase() === "importmap") continue;
    if (!THREE_GLOBAL_USE.test(body) || THREE_NAMESPACE_IMPORT.test(body)) continue;
    const index = match.index ?? -1;
    if (index >= 0) return `${html.slice(0, index)}${PINNED_THREE_CLASSIC}${html.slice(index)}`;
  }
  return html;
}

/** True when the document references nothing that provably cannot load. */
export function isRunnableGeneratedHtml(html: string): boolean {
  return findUnrunnableReferences(html).length === 0;
}
