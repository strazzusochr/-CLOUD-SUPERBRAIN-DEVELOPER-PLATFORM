import { referenceDesignContract } from "../../../../../lib/referenceDesign";

export const dynamic = "force-static";

/** GET /api/v1/design/reference-contract — static reference-design contract. */
export function GET() {
  return Response.json(referenceDesignContract());
}
