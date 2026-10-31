export const campaignID = "national-coffee-day-2026";
export const title = "Happy National Coffee Day ☕";
export const body =
  "Mugsy says today’s cup deserves a moment. Open Mugshot and publish a Sip.";
export const startsAt = Date.parse("2026-09-29T04:00:00Z");
export const expiresAt = Date.parse("2026-09-30T04:00:00Z");

export interface RegisteredDevice {
  id: string;
  user_id: string;
  push_token: string;
  platform: string;
  environment: string | null;
  disabled_at: string | null;
}

export function isCampaignOpen(now = Date.now()): boolean {
  return now >= startsAt && now < expiresAt;
}

export function isEligible(
  device: RegisteredDevice,
  pushEnabled: boolean | undefined,
): boolean {
  return device.platform === "ios" &&
    device.environment === "production" &&
    device.disabled_at === null &&
    pushEnabled === true &&
    /^[a-f0-9]{64,200}$/u.test(device.push_token);
}

export function payload(): Record<string, unknown> {
  return { aps: { alert: { title, body }, sound: "default" } };
}
