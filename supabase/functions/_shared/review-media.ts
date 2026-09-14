export function screeningMediaLocation(
  value: unknown,
  job: { subject_kind: string; subject_id: string; owner_id: string },
  baseURL: string,
): { bucket: string; path: string } | null {
  if (typeof value !== "string") return null;
  try {
    const url = new URL(value), base = new URL(baseURL);
    if (url.username || url.password || url.search || url.hash) return null;
    let bucket: string, path: string;
    if (
      url.protocol === "mugshot-storage:" &&
      url.hostname === "visit-photos-private"
    ) {
      bucket = url.hostname;
      path = decodeURIComponent(url.pathname.slice(1));
    } else {
      if (url.protocol !== "https:" || url.origin !== base.origin) return null;
      const match = url.pathname.match(
        /^\/storage\/v1\/object\/public\/(profile-media|visit-photos)\/(.+)$/,
      );
      if (!match) return null;
      bucket = match[1];
      path = decodeURIComponent(match[2]);
    }
    const segments = path.split("/");
    if (
      segments.some((part) =>
        !part || part === "." || part === ".." || /[\\\u0000-\u001f]/.test(part)
      ) || segments[0].toLowerCase() !== job.owner_id.toLowerCase()
    ) return null;
    // Historical uploads used owner/file.jpg and owner/folder/file.jpg.
    // The caller accepts references only from a authorized server review payload.
    if (job.subject_kind === "user") {
      if (bucket !== "profile-media") return null;
    } else if (job.subject_kind === "visit") {
      if (
        bucket === "visit-photos-private" &&
        (segments.length < 3 ||
          segments[1].toLowerCase() !== job.subject_id.toLowerCase())
      ) return null;
    } else return null;
    return { bucket, path };
  } catch {
    return null;
  }
}

