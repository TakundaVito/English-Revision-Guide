export const MAX_MESSAGE_LENGTH = 4_000;
export const MAX_IMAGES = 3;
export const MAX_IMAGE_DATA_URL_LENGTH = 6_000_000;

export function requireRateLimitSalt(value: string | undefined): string {
  const salt = value?.trim() ?? "";
  if (salt.length < 16) {
    throw new Error(
      "RATE_LIMIT_SALT must be configured with at least 16 characters",
    );
  }
  return salt;
}

export function sanitizeStudentName(value: unknown): string {
  return String(value ?? "Student")
    .replace(/[^\p{L}\p{N} .'-]/gu, "")
    .trim()
    .slice(0, 60) || "Student";
}

export function normalizeMessage(value: unknown): string {
  return String(value ?? "").trim().slice(0, MAX_MESSAGE_LENGTH);
}

export function validatedImageDataUrls(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  const images = value
    .filter((item): item is string =>
      typeof item === "string" &&
      /^data:image\/(jpeg|png|webp);base64,/i.test(item)
    )
    .slice(0, MAX_IMAGES);
  if (images.some((image) => image.length > MAX_IMAGE_DATA_URL_LENGTH)) {
    throw new RangeError("An attachment is too large");
  }
  return images;
}
