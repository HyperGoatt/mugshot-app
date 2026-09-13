// This module never logs requests, provider response bodies, or credentials.
// The caller must load a current revision through the private screening queue.
export type ScreeningInput = {
  audience: "private" | "shared";
  text: string;
  images: { mime: "image/jpeg" | "image/png"; bytes: Uint8Array }[];
};
export type ScreeningResult =
  | { state: "excluded" }
  | {
    state: "approved";
    model: string;
    categories: Record<string, boolean>;
    scores: Record<string, number>;
  }
  | {
    state: "needs_review";
    reason:
      | "provider_flag"
      | "spam_signal"
      | "invalid_input"
      | "provider_configuration"
      | "invalid_response";
    model?: string;
    categories?: Record<string, boolean>;
    scores?: Record<string, number>;
  }
  | {
    state: "retry";
    reason: "provider_unavailable";
    retryAfterSeconds: number;
  };

const categories = [
  "sexual",
  "sexual/minors",
  "harassment",
  "harassment/threatening",
  "hate",
  "hate/threatening",
  "illicit",
  "illicit/violent",
  "self-harm",
  "self-harm/intent",
  "self-harm/instructions",
  "violence",
  "violence/graphic",
] as const;

// Keep only image structure and pixels. Drop EXIF, XMP, comments and trailing
// bytes; unsupported or malformed containers go to review without transmission.
export function stripImageMetadata(
  bytes: Uint8Array,
  mime: string,
): Uint8Array {
  const chunks: Uint8Array[] = [];
  if (mime === "image/png") {
    const signature = [137, 80, 78, 71, 13, 10, 26, 10];
    if (!signature.every((value, index) => bytes[index] === value)) {
      throw new Error("invalid_image");
    }
    chunks.push(bytes.slice(0, 8));
    let offset = 8, hasHeader = false, hasPixels = false, ended = false;
    while (offset + 12 <= bytes.length) {
      const length = new DataView(bytes.buffer, bytes.byteOffset + offset, 4)
        .getUint32(0);
      if (length > bytes.length - offset - 12) throw new Error("invalid_image");
      const type = String.fromCharCode(...bytes.slice(offset + 4, offset + 8));
      if (!hasHeader && type !== "IHDR") throw new Error("invalid_image");
      if (type === "IHDR") {
        if (hasHeader || length !== 13) throw new Error("invalid_image");
        hasHeader = true;
      }
      if (type === "IDAT") hasPixels = true;
      if (["IHDR", "PLTE", "tRNS", "IDAT", "IEND"].includes(type)) {
        chunks.push(bytes.slice(offset, offset + length + 12));
      } else if (!/^[a-z]/.test(type)) throw new Error("unsupported_image");
      offset += length + 12;
      if (type === "IEND") {
        if (length !== 0) throw new Error("invalid_image");
        ended = true;
        break;
      }
    }
    if (!hasHeader || !hasPixels || !ended) throw new Error("invalid_image");
  } else if (mime === "image/jpeg") {
    if (bytes[0] !== 255 || bytes[1] !== 216) throw new Error("invalid_image");
    chunks.push(bytes.slice(0, 2));
    let offset = 2, hasScan = false, ended = false;
    while (offset < bytes.length) {
      const start = offset;
      if (bytes[offset++] !== 255) throw new Error("invalid_image");
      while (bytes[offset] === 255) offset++;
      const marker = bytes[offset++];
      if (marker === 217) {
        chunks.push(new Uint8Array([255, 217]));
        ended = true;
        break;
      }
      if (
        marker === undefined || marker === 0 || marker === 216 ||
        (marker >= 208 && marker <= 215)
      ) throw new Error("invalid_image");
      const length = (bytes[offset] << 8) | bytes[offset + 1];
      if (length < 2 || offset + length > bytes.length) {
        throw new Error("invalid_image");
      }
      if (!(marker >= 224 && marker <= 239) && marker !== 254) {
        chunks.push(bytes.slice(start, offset + length));
      }
      offset += length;
      if (marker === 218) {
        hasScan = true;
        const scanStart = offset;
        while (offset < bytes.length) {
          if (bytes[offset] !== 255) {
            offset++;
            continue;
          }
          let next = offset + 1;
          while (bytes[next] === 255) next++;
          if (bytes[next] === 0 || (bytes[next] >= 208 && bytes[next] <= 215)) {
            offset = next + 1;
            continue;
          }
          break;
        }
        chunks.push(bytes.slice(scanStart, offset));
      }
    }
    if (!hasScan || !ended) throw new Error("invalid_image");
  } else throw new Error("unsupported_image");
  const result = new Uint8Array(
    chunks.reduce((sum, chunk) => sum + chunk.length, 0),
  );
  let offset = 0;
  for (const chunk of chunks) {
    result.set(chunk, offset);
    offset += chunk.length;
  }
  return result;
}

function imageDataURL(image: ScreeningInput["images"][number]): string {
  const clean = stripImageMetadata(image.bytes, image.mime);
  let binary = "";
  for (let offset = 0; offset < clean.length; offset += 8192) {
    binary += String.fromCharCode(...clean.subarray(offset, offset + 8192));
  }
  return `data:${image.mime};base64,${btoa(binary)}`;
}

export async function screenContent(
  input: ScreeningInput,
  configuration: { apiKey: string; noTrainingControlsVerified: boolean },
  request: typeof fetch = fetch,
): Promise<ScreeningResult> {
  if (input.audience === "private") return { state: "excluded" };
  if (
    input.audience !== "shared" || typeof input.text !== "string" ||
    input.text.length > 16000 || !Array.isArray(input.images) ||
    input.images.length > 12 ||
    input.images.some((image) =>
      !(image.bytes instanceof Uint8Array) ||
      image.bytes.length > 8 * 1024 * 1024
    ) ||
    input.images.reduce((sum, image) => sum + image.bytes.length, 0) >
      16 * 1024 * 1024
  ) return { state: "needs_review", reason: "invalid_input" };
  if (!configuration.apiKey || !configuration.noTrainingControlsVerified) {
    return { state: "needs_review", reason: "provider_configuration" };
  }
  if (
    (input.text.match(/https?:\/\//gi)?.length ?? 0) > 3 ||
    /(.)\1{24,}/u.test(input.text)
  ) return { state: "needs_review", reason: "spam_signal" };
  const parts: ({ type: "text"; text: string } | {
    type: "image_url";
    image_url: { url: string };
  })[] = [];
  if (input.text.trim()) parts.push({ type: "text", text: input.text });
  try {
    for (const image of input.images) {
      parts.push({
        type: "image_url",
        image_url: { url: imageDataURL(image) },
      });
    }
  } catch {
    return { state: "needs_review", reason: "invalid_input" };
  }
  if (!parts.length) return { state: "needs_review", reason: "invalid_input" };
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 15000);
  try {
    const response = await request("https://api.openai.com/v1/moderations", {
      method: "POST",
      redirect: "error",
      signal: controller.signal,
      headers: {
        Authorization: `Bearer ${configuration.apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ model: "omni-moderation-latest", input: parts }),
    });
    if (response.status === 429 || response.status >= 500) {
      const delay = Number(response.headers.get("retry-after"));
      return {
        state: "retry",
        reason: "provider_unavailable",
        retryAfterSeconds: Number.isFinite(delay) && delay > 0
          ? Math.min(3600, Math.max(60, delay))
          : 60,
      };
    }
    if (!response.ok) {
      return { state: "needs_review", reason: "provider_configuration" };
    }
    const payload = await response.json();
    const result = payload?.results?.[0];
    if (
      !Array.isArray(payload?.results) || payload.results.length !== 1 ||
      typeof payload.model !== "string" || payload.model.length > 120 ||
      typeof result?.flagged !== "boolean" || !categories.every((category) =>
        typeof result?.categories?.[category] === "boolean" &&
        typeof result?.category_scores?.[category] === "number" &&
        Number.isFinite(result.category_scores[category]) &&
        result.category_scores[category] >= 0 &&
        result.category_scores[category] <= 1
      )
    ) {
      return { state: "needs_review", reason: "invalid_response" };
    }
    const flags = Object.fromEntries(
      categories.map((category) => [category, result.categories[category]]),
    );
    const scores = Object.fromEntries(
      categories.map(
        (category) => [category, result.category_scores[category]],
      ),
    );
    if (result.flagged || Object.values(flags).some(Boolean)) {
      return {
        state: "needs_review",
        reason: "provider_flag",
        model: payload.model,
        categories: flags,
        scores,
      };
    }
    return {
      state: "approved",
      model: payload.model,
      categories: flags,
      scores,
    };
  } catch {
    return {
      state: "retry",
      reason: "provider_unavailable",
      retryAfterSeconds: 60,
    };
  } finally {
    clearTimeout(timer);
  }
}
