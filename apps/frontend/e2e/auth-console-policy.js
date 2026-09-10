const EXPECTED_ANONYMOUS_AUTH_PATHS = new Set([
  "/api/v1/auth/me",
  "/api/v1/auth/refresh",
]);

export function isCorrelatedAnonymousAuthConsoleError({
  baseUrl,
  pageId,
  text,
  locationUrl,
  resourceErrors,
}) {
  if (pageId !== "login") return false;
  if (!/^Failed to load resource: the server responded with a status of 401 \(Unauthorized\)$/.test(text)) return false;

  let consoleUrl;
  let baseOrigin;
  try {
    consoleUrl = new URL(locationUrl);
    baseOrigin = new URL(baseUrl).origin;
  } catch {
    return false;
  }
  if (consoleUrl.origin !== baseOrigin || !EXPECTED_ANONYMOUS_AUTH_PATHS.has(consoleUrl.pathname)) return false;

  return resourceErrors.some((resource) => {
    if (resource.status !== 401 || resource.resourceType !== "fetch") return false;
    try {
      const resourceUrl = new URL(resource.url);
      return resourceUrl.origin === baseOrigin && resourceUrl.pathname === consoleUrl.pathname;
    } catch {
      return false;
    }
  });
}
