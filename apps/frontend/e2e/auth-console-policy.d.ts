export type BrowserResourceError = {
  status: number;
  url: string;
  resourceType: string;
};

export type AnonymousAuthConsoleProbe = {
  baseUrl: string;
  pageId: string;
  text: string;
  locationUrl: string;
  resourceErrors: BrowserResourceError[];
};

export function isCorrelatedAnonymousAuthConsoleError(probe: AnonymousAuthConsoleProbe): boolean;
