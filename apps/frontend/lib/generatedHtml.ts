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
const SIMPLE_KEYS_DECLARATION = /^[ \t]*(?:const|let)\s+keys\s*=\s*\{\s*\}\s*;[ \t]*$/m;
const FUNCTION_DECLARATION = /\bfunction\s+([A-Za-z_$][\w$]*)\s*\([^)]*\)\s*\{/g;
const SIMPLE_BOUNDING_SPHERE_RADIUS = /(?<![.\w$])([A-Za-z_$][\w$]*(?:\s*\.\s*[A-Za-z_$][\w$]*)*)\s*\.\s*geometry\s*\.\s*boundingSphere\s*\.\s*radius\b/g;
const BOUNDING_SPHERE_RADIUS_HELPER = `
function __superbrainBoundingSphereRadius(object) {
  const geometry = object && object.geometry;
  if (!geometry || typeof geometry.computeBoundingSphere !== "function") {
    throw new Error("Three.js object has no computable geometry bounding sphere");
  }
  if (geometry.boundingSphere === null || typeof geometry.boundingSphere === "undefined") {
    geometry.computeBoundingSphere();
  }
  const sphere = geometry.boundingSphere;
  if (!sphere) throw new Error("Three.js geometry bounding sphere is unavailable");
  return sphere.radius;
}
`;

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

type EarlyKeyboardStartup = {
  entryPoint: string;
  callIndex: number;
  callText: string;
  indentation: string;
};

function matchingBlockEnd(source: string, openingBrace: number): number {
  let depth = 0;
  let quote = "";
  let escaped = false;
  let lineComment = false;
  let blockComment = false;
  let regularExpression = false;
  let regularExpressionClass = false;
  let previousSignificant = "";

  for (let index = openingBrace; index < source.length; index += 1) {
    const current = source[index];
    const next = source[index + 1] ?? "";
    if (lineComment) {
      if (current === "\n") lineComment = false;
      continue;
    }
    if (blockComment) {
      if (current === "*" && next === "/") {
        blockComment = false;
        index += 1;
      }
      continue;
    }
    if (quote) {
      if (escaped) escaped = false;
      else if (current === "\\") escaped = true;
      else if (current === quote) quote = "";
      continue;
    }
    if (regularExpression) {
      if (escaped) escaped = false;
      else if (current === "\\") escaped = true;
      else if (current === "[") regularExpressionClass = true;
      else if (current === "]") regularExpressionClass = false;
      else if (current === "/" && !regularExpressionClass) regularExpression = false;
      continue;
    }
    if (current === "/" && next === "/") {
      lineComment = true;
      index += 1;
      continue;
    }
    if (current === "/" && next === "*") {
      blockComment = true;
      index += 1;
      continue;
    }
    if (current === "'" || current === '"' || current === "`") {
      quote = current;
      continue;
    }
    if (current === "/" && (!previousSignificant || /[([{,:;=!?&|+*%~^-]/.test(previousSignificant))) {
      regularExpression = true;
      regularExpressionClass = false;
      continue;
    }
    if (current === "{") depth += 1;
    else if (current === "}") {
      depth -= 1;
      if (depth === 0) return index;
    }
    if (!/\s/.test(current)) previousSignificant = current;
  }
  return -1;
}

/**
 * Produces a same-length view where JavaScript comments and literals are replaced with spaces.
 * Narrow source repairs can then use offsets from this view without rewriting examples, labels,
 * or regular expressions that merely contain code-looking text.
 */
function maskJavaScriptNonCode(source: string): string {
  const masked = source.split("");
  let quote = "";
  let escaped = false;
  let lineComment = false;
  let blockComment = false;
  let regularExpression = false;
  let regularExpressionClass = false;
  let previousSignificant = "";

  const hide = (index: number): void => {
    if (masked[index] !== "\n" && masked[index] !== "\r") masked[index] = " ";
  };

  for (let index = 0; index < source.length; index += 1) {
    const current = source[index];
    const next = source[index + 1] ?? "";
    if (lineComment) {
      hide(index);
      if (current === "\n") lineComment = false;
      continue;
    }
    if (blockComment) {
      hide(index);
      if (current === "*" && next === "/") {
        hide(index + 1);
        blockComment = false;
        index += 1;
      }
      continue;
    }
    if (quote) {
      hide(index);
      if (escaped) escaped = false;
      else if (current === "\\") escaped = true;
      else if (current === quote) quote = "";
      continue;
    }
    if (regularExpression) {
      hide(index);
      if (escaped) escaped = false;
      else if (current === "\\") escaped = true;
      else if (current === "[") regularExpressionClass = true;
      else if (current === "]") regularExpressionClass = false;
      else if (current === "/" && !regularExpressionClass) regularExpression = false;
      continue;
    }
    if (current === "/" && next === "/") {
      hide(index);
      hide(index + 1);
      lineComment = true;
      index += 1;
      continue;
    }
    if (current === "/" && next === "*") {
      hide(index);
      hide(index + 1);
      blockComment = true;
      index += 1;
      continue;
    }
    if (current === "'" || current === '"' || current === "`") {
      hide(index);
      quote = current;
      continue;
    }
    if (current === "/" && (!previousSignificant || /[([{,:;=!?&|+*%~^-]/.test(previousSignificant))) {
      hide(index);
      regularExpression = true;
      regularExpressionClass = false;
      continue;
    }
    if (!/\s/.test(current)) previousSignificant = current;
  }
  return masked.join("");
}

function repairBoundingSphereRadiusReads(scriptBody: string): string {
  const code = maskJavaScriptNonCode(scriptBody);
  const matches = [...code.matchAll(SIMPLE_BOUNDING_SPHERE_RADIUS)];
  if (matches.length === 0) return scriptBody;
  let repaired = scriptBody;
  for (const match of matches.reverse()) {
    const index = match.index ?? -1;
    if (index < 0) continue;
    const object = match[1];
    repaired = `${repaired.slice(0, index)}__superbrainBoundingSphereRadius(${object})${repaired.slice(index + match[0].length)}`;
  }
  return repaired.includes("function __superbrainBoundingSphereRadius(object)")
    ? repaired
    : `${BOUNDING_SPHERE_RADIUS_HELPER}${repaired}`;
}

function findEarlyKeyboardStartup(scriptBody: string): EarlyKeyboardStartup | null {
  const keysDeclaration = scriptBody.match(SIMPLE_KEYS_DECLARATION);
  const keysIndex = keysDeclaration?.index ?? -1;
  if (keysIndex < 0) return null;

  for (const declaration of scriptBody.matchAll(FUNCTION_DECLARATION)) {
    const entryPoint = declaration[1];
    const functionIndex = declaration.index ?? -1;
    if (functionIndex < 0 || functionIndex >= keysIndex) continue;
    const openingBrace = functionIndex + declaration[0].lastIndexOf("{");
    const closingBrace = matchingBlockEnd(scriptBody, openingBrace);
    if (closingBrace < openingBrace || closingBrace >= keysIndex) continue;
    if (!/\bkeys\s*\[/.test(scriptBody.slice(openingBrace + 1, closingBrace))) continue;
    const escapedEntryPoint = entryPoint.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    const afterFunction = scriptBody.slice(closingBrace + 1, keysIndex);
    const directCall = new RegExp(`^([ \\t]*)${escapedEntryPoint}\\(\\);[ \\t]*$`, "m").exec(afterFunction);
    const callIndex = directCall?.index === undefined ? -1 : closingBrace + 1 + directCall.index;
    if (callIndex <= closingBrace || callIndex >= keysIndex) continue;
    return {
      entryPoint,
      callIndex,
      callText: directCall?.[0] ?? `${entryPoint}();`,
      indentation: directCall?.[1] ?? "",
    };
  }
  return null;
}

function findEarlyKeyboardStateReferences(executableMarkup: string): string[] {
  const reasons: string[] = [];
  for (const [, attributes, body] of executableMarkup.matchAll(SCRIPT_BLOCK)) {
    if (attributeValue(attributes, SRC_ATTR)) continue;
    const startup = findEarlyKeyboardStartup(body);
    if (startup) {
      reasons.push(`${startup.entryPoint}() starts before lexical keyboard state 'keys' is initialized`);
    }
  }
  return reasons;
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
  reasons.push(...findEarlyKeyboardStateReferences(executableMarkup));
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

/**
 * Repairs the narrow live-provider ordering defect where a declared animation function is started
 * before its simple lexical `keys` state exists. Moving the direct start call after the declaration
 * preserves the generated program while preventing a deterministic temporal-dead-zone exception.
 */
export function ensureGeneratedHtmlRuntimeOrder(html: string): string {
  return html.replace(SCRIPT_BLOCK, (script, attributes: string, body: string) => {
    if (attributeValue(attributes, SRC_ATTR)) return script;
    const startup = findEarlyKeyboardStartup(body);
    if (!startup) return script;
    const withoutEarlyCall = `${body.slice(0, startup.callIndex)}${body.slice(startup.callIndex + startup.callText.length)}`;
    const keysDeclaration = withoutEarlyCall.match(SIMPLE_KEYS_DECLARATION);
    if (keysDeclaration?.index === undefined) return script;
    const insertAt = keysDeclaration.index + keysDeclaration[0].length;
    const repairedBody = `${withoutEarlyCall.slice(0, insertAt)}\n${startup.indentation}${startup.entryPoint}();${withoutEarlyCall.slice(insertAt)}`;
    const bodyStart = script.indexOf(">") + 1;
    return `${script.slice(0, bodyStart)}${repairedBody}${script.slice(bodyStart + body.length)}`;
  });
}

/**
 * Three.js computes geometry bounding spheres lazily. Models frequently read
 * `mesh.geometry.boundingSphere.radius` before the first computation, which throws on the first
 * animation frame and leaves an otherwise valid game frozen. Replace only simple executable
 * radius reads with a fail-closed helper; strings, comments, external scripts, and optional-safe
 * reads are left byte-identical.
 */
export function ensureGeneratedHtmlBoundingSpheres(html: string): string {
  return html.replace(SCRIPT_BLOCK, (script, attributes: string, body: string) => {
    if (attributeValue(attributes, SRC_ATTR)) return script;
    const repairedBody = repairBoundingSphereRadiusReads(body);
    if (repairedBody === body) return script;
    const bodyStart = script.indexOf(">") + 1;
    return `${script.slice(0, bodyStart)}${repairedBody}${script.slice(bodyStart + body.length)}`;
  });
}

/** True when the document references nothing that provably cannot load. */
export function isRunnableGeneratedHtml(html: string): boolean {
  return findUnrunnableReferences(html).length === 0;
}
