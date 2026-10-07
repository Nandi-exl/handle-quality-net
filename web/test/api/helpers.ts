// Shared helpers for black-box API tests.
// The tests talk to a running API over HTTP, exactly like the web app does.
// Test data comes from api/db/ci_fixtures.rb.

export const API_URL = process.env.API_URL ?? "http://localhost:3001";

export const ADMIN = {
  email: process.env.TEST_ADMIN_EMAIL ?? "admin@example.com",
  password: process.env.TEST_ADMIN_PASSWORD ?? "password123",
};

// Admin of the second organization. Used to attempt cross-organization access.
export const OTHER_ADMIN = {
  email: process.env.TEST_OTHER_ADMIN_EMAIL ?? "other-admin@example.com",
  password: process.env.TEST_OTHER_ADMIN_PASSWORD ?? "password123",
};

// Two organizations, so cross-tenant behaviour can be tested.
export const ORG_A = "test-corp";
export const ORG_B = "other-corp";

export interface LoginResult {
  status: number;
  token?: string;
}

// POST /api/v1/auth/login, optionally asking for an organization via the
// X-Tenant-Scheme header (the header the web app's login does not need to send).
export async function loginAs(
  user: { email: string; password: string },
  scheme?: string,
): Promise<LoginResult> {
  const headers: Record<string, string> = { "Content-Type": "application/json" };
  if (scheme) headers["X-Tenant-Scheme"] = scheme;

  const res = await fetch(`${API_URL}/api/v1/auth/login`, {
    method: "POST",
    headers,
    body: JSON.stringify(user),
  });
  const body = await res.json().catch(() => null);

  return { status: res.status, token: body?.token };
}

export async function login(scheme?: string): Promise<LoginResult> {
  return loginAs(ADMIN, scheme);
}

// Reads the organization ("scheme" claim) out of a JWT without verifying it.
export function tokenScheme(token: string): string | undefined {
  const payload = token.split(".")[1].replace(/-/g, "+").replace(/_/g, "/");
  return JSON.parse(atob(payload)).scheme;
}
