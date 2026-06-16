import { gatewayHandle } from "../../../lib/gatewayProxy";

export const dynamic = "force-dynamic";

type Ctx = { params: Promise<{ slug: string[] }> };

export async function GET(req: Request, ctx: Ctx): Promise<Response> {
  return gatewayHandle(req, (await ctx.params).slug, "/mcp", "MCP_GATEWAY_BASE_URL");
}

export async function POST(req: Request, ctx: Ctx): Promise<Response> {
  return gatewayHandle(req, (await ctx.params).slug, "/mcp", "MCP_GATEWAY_BASE_URL");
}
