// F-02 (assessment/01-audit.md): login lets the client choose its organization.
//
// Required behaviour: a user only gets tokens for the organization they belong
// to. The organization must never come from client input.
//
// These assertions describe behaviour, not a specific fix, so they stay valid
// whichever way the fix is implemented.

import { describe, expect, it } from "vitest";
import { login, ORG_A, ORG_B, tokenScheme } from "./helpers";

describe("F-02: login must not let the client choose its organization", () => {
  // Positive control: stops a "fix" that simply breaks login from turning this green.
  it("the admin can still log in", async () => {
    const results = await Promise.all([login(ORG_A), login(ORG_B)]);

    expect(
      results.some((r) => r.status === 200 && r.token),
      `no successful login; statuses: ${results.map((r) => r.status).join(", ")}`,
    ).toBe(true);
  });

  it("the same credentials cannot obtain tokens for two different organizations", async () => {
    const results = await Promise.all([login(ORG_A), login(ORG_B)]);
    const schemes = new Set(
      results.filter((r) => r.token).map((r) => tokenScheme(r.token!)),
    );

    expect(
      schemes.size,
      `one user received tokens for: ${[...schemes].join(", ")}`,
    ).toBeLessThanOrEqual(1);
  });

  it("asking for another organization via X-Tenant-Scheme is not honoured", async () => {
    const { status, token } = await login(ORG_B);

    if (token) {
      expect(tokenScheme(token), "token was issued for the requested organization").not.toBe(ORG_B);
    } else {
      expect([401, 403]).toContain(status);
    }
  });
});
