// Retired endpoint: old schedules/clients cannot submit content to a provider.
Deno.serve(() => new Response(JSON.stringify({ error: "screening_retired", moderation: "local_text_and_reports" }), {
  status: 410, headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
}));
