import { ImageResponse } from "npm:@vercel/og@^0.8.5";
import React from "npm:react@^19";

export const mugshotOGWidth = 1200;
export const mugshotOGHeight = 630;
export const mugshotOGTitle = "Mugshot: Capture Every Sip";

export type MugshotOGInput = {
  authorName: string;
  drinkName: string;
  contextName: string;
  coverPhotoURL: string | null;
  appIconURL: string;
};

export function mugshotOGDescription(input: MugshotOGInput): string {
  return `${input.authorName} shared ${input.drinkName} at ${input.contextName}.`;
}

export function mugshotOGAlt(input: MugshotOGInput): string {
  return `Mugshot post for ${input.drinkName} at ${input.contextName}`;
}

export function mugshotOGImageResponse(input: MugshotOGInput): Response {
  const hasPhoto = Boolean(input.coverPhotoURL);
  const response = new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          position: "relative",
          overflow: "hidden",
          background: "#f8f3ea",
          color: "#16221b",
          fontFamily: "Arial, sans-serif",
        }}
      >
        <div
          style={{
            width: hasPhoto ? "61%" : "100%",
            height: "100%",
            display: "flex",
            flexDirection: "column",
            padding: "54px 60px 52px 64px",
            position: "relative",
          }}
        >
          <div style={{ display: "flex", alignItems: "center", gap: 22 }}>
            {/* deno-lint-ignore jsx-img */}
            <img
              src={input.appIconURL}
              alt=""
              width={82}
              height={82}
              style={{ borderRadius: 19 }}
            />
            <div
              style={{
                display: "flex",
                color: "#143d31",
                fontSize: 30,
                fontWeight: 800,
                letterSpacing: 9,
              }}
            >
              MUGSHOT
            </div>
          </div>
          <div
            style={{
              display: "flex",
              flexDirection: "column",
              marginTop: 48,
            }}
          >
            <div
              style={{
                display: "flex",
                color: "#315f4d",
                fontSize: 21,
                fontWeight: 800,
                letterSpacing: 2.6,
              }}
            >
              CAPTURE EVERY SIP
            </div>
            <div
              style={{
                display: "flex",
                marginTop: 18,
                fontFamily: "Georgia, serif",
                fontSize: 70,
                lineHeight: 0.98,
                letterSpacing: -2.2,
                maxWidth: 640,
              }}
            >
              {input.drinkName}
            </div>
            <div
              style={{
                display: "flex",
                marginTop: 24,
                color: "#315f4d",
                fontSize: 27,
                fontWeight: 650,
              }}
            >
              {input.contextName}
            </div>
            <div
              style={{
                display: "flex",
                marginTop: 12,
                color: "#5d6a62",
                fontSize: 20,
              }}
            >
              Shared by {input.authorName}
            </div>
          </div>
          <div
            style={{
              display: "flex",
              alignItems: "center",
              gap: 16,
              marginTop: "auto",
              color: "#143d31",
              fontSize: 18,
              fontWeight: 700,
            }}
          >
            <div
              style={{
                display: "flex",
                width: 10,
                height: 10,
                borderRadius: 999,
                background: "#a6ccb7",
              }}
            />
            Remember the sip, not just the place.
          </div>
        </div>
        {hasPhoto
          ? (
            <div
              style={{
                width: "39%",
                height: "100%",
                display: "flex",
                position: "relative",
                background: "#143d31",
              }}
            >
              {/* deno-lint-ignore jsx-img */}
              <img
                src={input.coverPhotoURL!}
                alt=""
                width={468}
                height={630}
                style={{ width: "100%", height: "100%", objectFit: "cover" }}
              />
              <div
                style={{
                  position: "absolute",
                  inset: 0,
                  background:
                    "linear-gradient(90deg, rgba(248,243,234,.34), transparent 30%)",
                }}
              />
            </div>
          )
          : (
            <div
              style={{
                position: "absolute",
                right: -80,
                bottom: -120,
                width: 410,
                height: 410,
                display: "flex",
                border: "3px solid #c98432",
                borderRadius: 999,
                opacity: 0.46,
              }}
            />
          )}
      </div>
    ),
    {
      width: mugshotOGWidth,
      height: mugshotOGHeight,
      headers: {
        "Cache-Control": "private, no-store",
        "X-Content-Type-Options": "nosniff",
        "X-Robots-Tag": "noindex, nofollow, noarchive",
        "Referrer-Policy": "no-referrer",
      },
    },
  );
  return new Response(response.body, {
    status: response.status,
    headers: {
      "Content-Type": "image/png",
      "Cache-Control": "private, no-store",
      "X-Content-Type-Options": "nosniff",
      "X-Robots-Tag": "noindex, nofollow, noarchive",
      "Referrer-Policy": "no-referrer",
    },
  });
}
