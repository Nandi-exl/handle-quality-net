// F-03 (assessment/01-audit.md): portfolio reads and skill overrides ignore
// the organization.
//
// Required behaviour: a portfolio can only be read or changed by the
// organization that owns its session. Looking it up by id from another
// organization must be the same as it not existing.
//
// These assertions describe behaviour, not a specific fix, so they stay valid
// whichever way the fix is implemented.
//
// The first test is the positive control. Without it, a missing fixture would
// return 404 and the other two tests would pass without the record existing.

import { beforeAll, describe, expect, it } from "vitest";
import { API_URL, login, loginAs, OTHER_ADMIN } from "./helpers";

let portfolioId: number;
let skillId: number;

beforeAll(async () => {
  const { status, token } = await login();
  expect(status, "owning admin could not log in").toBe(200);

  const ids = await probeIds(token!);
  portfolioId = ids.portfolioId;
  skillId = ids.skillId;
});

describe("F-03: a portfolio stays inside its organization", () => {
  it("the owning organization can export its portfolio", async () => {
    const { token } = await login();
    const { status, body } = await authed("GET", `/api/v1/portfolios/${portfolioId}/export`, token!);

    expect(status).toBe(200);
    expect(JSON.stringify(body)).toContain("Ruby");
  });

  it("another organization cannot export that portfolio", async () => {
    const { token } = await loginAs(OTHER_ADMIN);
    const { status } = await authed("GET", `/api/v1/portfolios/${portfolioId}/export`, token!);

    expect(status).toBe(404);
  });

  it("another organization cannot override that portfolio's skill level", async () => {
    const { token } = await loginAs(OTHER_ADMIN);
    const { status } = await authed(
      "POST",
      `/api/v1/portfolio_skills/${skillId}/override`,
      token!,
      { override: { override_level: 5 } },
    );

    expect(status).toBe(404);
  });
});

// Finds the fixture portfolio through the owning organization's own endpoints.
async function probeIds(token: string): Promise<{ portfolioId: number; skillId: number }> {
  const headers = { Authorization: `Bearer ${token}` };

  const assessmentsRes = await fetch(`${API_URL}/api/v1/assessments`, { headers });
  const assessments = await assessmentsRes.json();
  const probe = assessments.assessments?.find((a: { name: string }) => a.name === "F-03 probe");
  if (!probe) throw new Error("F-03 probe assessment is missing. Run api/db/ci_fixtures.rb.");

  const sessionsRes = await fetch(`${API_URL}/api/v1/assessments/${probe.id}/sessions`, { headers });
  const sessions = await sessionsRes.json();
  const session = sessions.sessions?.[0];
  if (!session) throw new Error("F-03 probe assessment has no session.");

  const portfolioRes = await fetch(`${API_URL}/api/v1/sessions/${session.id}/portfolio`, { headers });
  if (portfolioRes.status !== 200) {
    throw new Error(`owning organization cannot read its portfolio (status ${portfolioRes.status}).`);
  }

  const portfolio = (await portfolioRes.json()).portfolio;
  const skill = portfolio?.skills?.[0];
  if (!portfolio?.id || !skill?.id) throw new Error("F-03 probe portfolio has no skill.");

  return { portfolioId: portfolio.id, skillId: skill.id };
}

async function authed(
  method: string,
  path: string,
  token: string,
  jsonBody?: unknown,
): Promise<{ status: number; body: unknown }> {
  const res = await fetch(`${API_URL}${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      ...(jsonBody ? { "Content-Type": "application/json" } : {}),
    },
    body: jsonBody ? JSON.stringify(jsonBody) : undefined,
  });
  const body = await res.json().catch(() => null);
  return { status: res.status, body };
}
