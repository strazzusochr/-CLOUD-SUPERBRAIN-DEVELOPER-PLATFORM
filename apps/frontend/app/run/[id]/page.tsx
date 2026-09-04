import { RunBuild } from "../../../components/run-build";

export const dynamic = "force-dynamic";

function safeId(value: string): string {
  return /^[A-Za-z0-9_-]{1,64}$/.test(value) ? value : "";
}

export default async function RunPage({ params }: { params: Promise<{ id: string }> }) {
  const clean = safeId((await params).id);
  return <RunBuild id={clean} />;
}
