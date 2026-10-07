# Release notes — v1.0.0

What this tag claims to deliver. It is not a changelog of every commit.

## Claims

- The API starts from a clean checkout (F-01).
- Login issues a token only for the user's own organization (F-02).
- A portfolio can only be read or changed by the organization that owns its session (F-03).
- An invalid or missing AI skill level is not stored as a real L1–L5 score (F-04).
- A pull request cannot proceed without a spec, acceptance criteria, a design plan, and a test or an N/A reason (G2).

## What this version does not claim

- Live interview quality, audio, or real Gemini output. Those paths are not in the net.
- A first-time web checkout with no `.env` (the client still defaults to port 3000; the API listens on 3001).
- Full eager-load of the API in test. That hits a pre-existing `AudioWebSocketMiddleware` name mismatch. The live API still boots.
- Every other organization-scoped table. Only the paths we checked (login, vacancies as control, portfolio export and override) are gated.

## Gate

On this tag, the **Release** workflow runs API boot and API tests (including F-04 unit tests). The last job prints **releasable** or **blocked**. See `assessment/03-release-decision.md` for the ship call.
