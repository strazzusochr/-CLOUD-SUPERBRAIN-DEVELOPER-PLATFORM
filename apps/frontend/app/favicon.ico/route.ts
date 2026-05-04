export const dynamic = "force-static";

export function GET() {
  const svg = [
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">',
    '<rect width="64" height="64" rx="12" fill="#08111f"/>',
    '<path d="M16 38h32v8H16zM16 18h8v20h-8zM28 14h8v24h-8zM40 24h8v14h-8z" fill="#67e8f9"/>',
    '<path d="M14 48h36" stroke="#2dd4bf" stroke-width="4" stroke-linecap="round"/>',
    "</svg>",
  ].join("");

  return new Response(svg, {
    headers: {
      "content-type": "image/svg+xml; charset=utf-8",
      "cache-control": "public, max-age=86400",
    },
  });
}
