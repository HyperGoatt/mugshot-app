import { retiredNotificationResponse } from "./handler.ts";

Deno.test("retired notification endpoint returns no delivery or user data", async () => {
  const response = retiredNotificationResponse();
  if (
    response.status !== 410 ||
    response.headers.get("Cache-Control") !== "no-store"
  ) {
    throw new Error("retirement response contract changed");
  }
  if (await response.text() !== '{"error":"endpoint_retired"}') {
    throw new Error(
      "retirement response must contain no user or delivery data",
    );
  }
});
