import {
  body,
  expiresAt,
  isCampaignOpen,
  isEligible,
  payload,
  type RegisteredDevice,
  startsAt,
} from "./campaign.ts";

function assert(value: boolean, message: string): void {
  if (!value) throw new Error(message);
}

Deno.test("the approved greeting is open only on September 29 Eastern time", () => {
  assert(!isCampaignOpen(startsAt - 1), "opened early");
  assert(isCampaignOpen(startsAt), "did not open");
  assert(isCampaignOpen(expiresAt - 1), "closed early");
  assert(!isCampaignOpen(expiresAt), "did not expire");
  const alert =
    (payload().aps as { alert: { title: string; body: string } }).alert;
  assert(alert.title === "Happy National Coffee Day ☕", "title drifted");
  assert(alert.body === body, "body drifted");
});

Deno.test("only active production iOS devices with push enabled qualify", () => {
  const device: RegisteredDevice = {
    id: crypto.randomUUID(),
    user_id: crypto.randomUUID(),
    push_token: "a".repeat(64),
    platform: "ios",
    environment: "production",
    disabled_at: null,
  };
  assert(isEligible(device, true), "valid device excluded");
  assert(!isEligible(device, false), "push opt-out included");
  assert(!isEligible(device, undefined), "missing preference included");
  assert(
    !isEligible({ ...device, environment: "sandbox" }, true),
    "sandbox included",
  );
  assert(
    !isEligible({ ...device, disabled_at: new Date().toISOString() }, true),
    "disabled included",
  );
  assert(
    !isEligible({ ...device, platform: "android" }, true),
    "other platform included",
  );
  assert(
    !isEligible({ ...device, push_token: "bad" }, true),
    "invalid token included",
  );
});
