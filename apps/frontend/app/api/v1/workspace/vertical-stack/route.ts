import { workspaceVerticalStackContract } from "../../../../../lib/workspaceVerticalStack";

export const dynamic = "force-static";

export function GET() {
  return Response.json(workspaceVerticalStackContract());
}
