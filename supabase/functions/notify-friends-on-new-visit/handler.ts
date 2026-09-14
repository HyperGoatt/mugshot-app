/** Retired webhook. All notification eligibility and delivery now belong to
 * the durable activity pipeline. Never parse caller data or contact a service. */
export function retiredNotificationResponse(): Response {
  return new Response(JSON.stringify({ error: "endpoint_retired" }), {
    status: 410,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
  });
}
