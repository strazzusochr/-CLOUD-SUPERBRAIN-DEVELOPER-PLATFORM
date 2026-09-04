import { authSessionContract } from "../../../../../../lib/authSession";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export async function GET(): Promise<Response> {
  return Response.json(authSessionContract(), {
    headers: { "cache-control": "no-store", "x-superbrain-source": "auth-session-integrity" },
  });
}
