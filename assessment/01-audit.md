# 01 — Platform Audit

> **Status: working draft.** Findings are added as they are confirmed. Ranking, the systemic pattern, and the ship / do-not-ship line are written once the audit is complete.

## Ship / do-not-ship

_To be written at the end of the audit._

## How to read this

**Severity** (apply top to bottom, stop at the first match):

- P0 Blocker : The objective cannot be achieved at all, no workaround. The main function is broken.

- P1 Major : Looks like it works, but the data or logic is wrong underneath; or the objective is reachable only with a manual workaround. Any data-integrity issue is at least P1.

- P2 Minor : Works and the data is correct, but there is a limited, non-blocking issue.

- P3 Cosmetic : Purely visual or copy. No function or data impact.

**Type**

- **Missing spec**: the behavior was never defined, so nobody can say whether the build is correct.
- **Built wrong**: the behavior was defined, and the build does not match it.

**Status**: `Open`, `Fixed (<commit>)`, or `Accepted risk (<owner>)`.

## Findings

- ID : F-01
- Sev : P2
- Finding : API process crashes on boot from a fresh checkout when started with Puma directly
- Type : Built wrong (setup)
- Impact : Engineers and CI starting the API from a clean checkout get a crash; production image is unaffected
- Status : Fixed (e33f81d)

### F-01: API crashes on boot from a fresh checkout (Puma pidfile directory missing)

**Severity:** 
P2. The product works in production, and there is a manual workaround. It blocks a clean-checkout start, which is exactly what CI does.

**Type:** 
Built wrong (setup / repo hygiene).

**Impact:** 
Anyone who starts the API with the `Procfile` web command (`bundle exec puma -C config/puma.rb`) from a fresh checkout gets a crash, and so does any CI job that does the same.

**Evidence / repro:**
1. Fresh checkout of the repo (no `api/tmp/` directory exists).
2. Install gems, create, migrate, and seed the database (all succeed).
3. Run `bundle exec puma -C config/puma.rb` from `api/`.
4. Puma logs `Listening on http://0.0.0.0:3001`, then exits with:
`Errno::ENOENT: No such file or directory @ rb_sysopen - tmp/pids/server.pid`

**Root cause:** 
`config/puma.rb` writes its pidfile to `tmp/pids/server.pid`, and Puma does not create the directory. `api/.gitignore` tries to keep `tmp/pids/.keep`, but the root `.gitignore` ignores `**/tmp/` entirely, so the placeholder never reaches the repo. The production `Dockerfile` masks this with `mkdir -p tmp/pids`.

**Not verified:** 
whether `bundle exec rails server` (the README path) is affected. Rails normally creates `tmp/pids` itself, so this path may work.

**Why it matters beyond itself:** no automated job boots the API from a clean checkout, so setup regressions like this go unnoticed. See the related leads below.

---

- ID : F-02
- Sev : P0
- Finding : Any admin user can obtain a valid token for any organization by choosing it in a request header at login
- Type : Missing spec (multi-tenancy and login are undefined) + Built wrong (authorization trusts client input)
- Impact : Any admin of one client can enter any other client's organization and read or change its vacancies, assessments, interview sessions, and candidate data
- Status : Open

### F-02: Login lets the client choose its own organization (cross-tenant access)

**Severity:** 
P0. Each client's core expectation is that its candidates' data is private to it. That guarantee does not hold, and there is no workaround: tenant filtering on every query is only as trustworthy as the token, and the token's organization is chosen by the caller. Even read as a data-integrity issue it is at least P1.

**Type:** 
Missing spec: neither PRD defines multi-tenancy, user-to-organization membership, or how login decides the organization. Built wrong: the endpoint signs a client-supplied header into the token and treats it as authorization.

**Impact:** 
Any user with an admin login can mint a token for any organization and then use every assessor endpoint inside it: list and edit vacancies, list assessments and sessions, read transcripts and portfolios. In a multi-client deployment, one client's admin can read every other client's candidates.

**Evidence / repro:** 
Setup: two organizations (`test-corp`, `other-corp`), one admin user (`admin@example.com`), one vacancy owned by `test-corp`.
1. `POST /api/v1/auth/login` with header `X-Tenant-Scheme: test-corp` and the admin credentials → `200`, token whose `scheme` claim is `test-corp`.
2. Same request, same user, with `X-Tenant-Scheme: other-corp` → `200`, token whose `scheme` claim is `other-corp`.
3. `GET /api/v1/vacancies` with the `test-corp` token → returns the `test-corp` vacancy.
4. `GET /api/v1/vacancies` with the `other-corp` token → `{"vacancies": [], ...}`.

Steps 3 and 4 show that vacancy filtering by organization works. The hole is step 2: the same user gets into either organization just by changing one header.

**Root cause:** 
The `users` table has no link to an organization, so the API cannot know which organization a user belongs to. `AuthenticationController#resolve_scheme` takes the organization from the `X-Tenant-Scheme` request header and signs it into the token. Without the header, it falls back to `SELECT scheme FROM organizations LIMIT 1`, an arbitrary organization.

**Not verified:** 
Comments in the code say tokens and organizations normally come from an external system that is not in this repo. This audit can only judge this repo, where the login endpoint is exposed and working as described.

## Leads to verify

Observed while reading config. These are not confirmed findings yet.

- `ALLOWED_ORIGINS` is read with `ENV.fetch` and no default, so the API fails to boot if it is unset. The sample config sets it to `"*"` (any origin).

- The README and `application.yml.sample` disagree on variable names (`GEMINI_ANALYSIS_MODEL` vs `GEMINI_FLASH_MODEL`).

- The README's frontend step points to `../ai-interview-web`; the folder is `web/`.

- JWT signing depends on `SECRET_KEY_BASE` matching an external service, and organizations are expected to come from an external shared database. The platform's auth and tenancy depend on a system that is not in this repo.

**Fix:** 
`config/puma.rb` now creates the pidfile directory before Puma writes to it (`FileUtils.mkdir_p`). This works for every start path (Procfile, Docker, CI) and for a custom `PIDFILE`. The `.gitignore` conflict is left as is; startup no longer depends on it.

**Red → green:** 
- Red: `3e6454a` added the API boot check; it failed on the pidfile crash. <link to failed run>
- Green: `e33f81d` fixed `puma.rb`; the same unchanged check passed. <link to passing run>

## Systemic pattern

_To be written once enough findings are in._

## Coverage of this audit

_What was examined deeply, what was skimmed, and what was not examined. To be written at the end._

