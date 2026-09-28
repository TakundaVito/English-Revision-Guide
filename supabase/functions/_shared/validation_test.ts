import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import {
  MAX_MESSAGE_LENGTH,
  normalizeMessage,
  requireRateLimitSalt,
  sanitizeStudentName,
  validatedImageDataUrls,
} from "./validation.ts";

Deno.test("rate-limit salt must be explicitly and strongly configured", () => {
  assertThrows(() => requireRateLimitSalt(undefined), Error, "RATE_LIMIT_SALT");
  assertThrows(() => requireRateLimitSalt("short"), Error, "RATE_LIMIT_SALT");
  assertEquals(
    requireRateLimitSalt("a-secure-random-salt"),
    "a-secure-random-salt",
  );
});

Deno.test("student name is sanitized and length-limited", () => {
  assertEquals(sanitizeStudentName("  Tendai <script>  "), "Tendai script");
  assertEquals(sanitizeStudentName("   "), "Student");
  assertEquals(sanitizeStudentName("x".repeat(100)).length, 60);
});

Deno.test("messages are trimmed and capped", () => {
  assertEquals(normalizeMessage("  hello  "), "hello");
  assertEquals(normalizeMessage("x".repeat(5_000)).length, MAX_MESSAGE_LENGTH);
});

Deno.test("image validation accepts supported data URLs only", () => {
  assertEquals(
    validatedImageDataUrls([
      "data:image/jpeg;base64,abc",
      "data:text/plain;base64,bad",
      42,
      "data:image/png;base64,def",
    ]),
    ["data:image/jpeg;base64,abc", "data:image/png;base64,def"],
  );
});
