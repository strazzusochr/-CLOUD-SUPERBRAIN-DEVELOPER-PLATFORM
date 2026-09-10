export const dynamic = "force-dynamic";

export async function GET(request: Request): Promise<Response> {
  return Response.redirect(new URL(`/api/v1/workspace/artifacts${new URL(request.url).search}`, request.url), 307);
}
