export function GET() {
  return Response.json({
    status: "healthy",
    service: "frontend",
    time: new Date().toISOString(),
  });
}
