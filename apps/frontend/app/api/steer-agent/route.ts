import { projectedDefault, genericDefault } from "../../../lib/endpointDefaults";

export const dynamic = "force-dynamic";

export async function POST(req: Request): Promise<Response> {
  const body = await req.text();
  const projected = projectedDefault("/api/steer-agent", "POST", body);
  const payload = projected?.payload ?? genericDefault("/api/steer-agent", "POST");
  return Response.json(payload, {
    status: projected?.status ?? 200,
    headers: { "x-superbrain-source": "frontend-projection", "cache-control": "no-store" },
  });
}
