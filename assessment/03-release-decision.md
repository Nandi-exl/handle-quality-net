# 03 — Release decision (v1.0.0)

> Fill the run URL after the **Release** workflow on tag `v1.0.0` finishes.

## Recommendation

**Releasable** for the paths this net covers, with the remaining risks below named and accepted.

There is no open P0 or P1 from the audit. F-02 and F-03 (P0) and F-04 (P1) are fixed. F-01 (P2) is fixed. Shipping is not “all green everywhere”; it is “the gated claims hold, and what we did not gate is written down.”

## What the gate checked

On tag `v1.0.0`, workflow **Release**:

- API boot — clean checkout, migrate, seed, `/health` (F-01)
- API tests — F-02 login tenancy, F-03 portfolio tenancy, F-04 skill levels (RSpec + black-box)
- Release status — prints **releasable** or **blocked** and fails the job if either check failed

Gate run: <link to the Release workflow run on v1.0.0>

## What the gate found

_To be copied from that run: releasable or blocked, and which job if blocked._

## Remaining risk (not P0/P1 in this audit)

| Risk | Why it does not block this tag | Owner |
|---|---|---|
| Web app defaults to port 3000; API listens on 3001 | Workaround: set `VITE_API_BASE_URL` as in `web/README.md`. First-time `npm run dev` without `.env` will not talk to the API. | Release owner (you) |
| Eager load fails on `AudioWebSocketMiddleware` | Live API still boots via `require_relative`. Test eager load stays off. Not a client-facing outage. | Release owner (you) |
| Live interview, audio, Gemini | Not in the net. Do not claim interview quality. | Release owner (you) |

If a later finding is P0 or P1 and still open, this recommendation becomes **blocked**.

## Who owns the risk if it ships

You (the candidate / release owner). There is no separate on-call on this repo.
