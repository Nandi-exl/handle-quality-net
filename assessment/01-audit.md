# 01 — Platform Audit

> **Status: complete for the paths we gated.** F-01–F-04 are fixed. `v1.0.0` is releasable for those paths. Remaining leads are named, not silent.

## Ship / do-not-ship

**Ship `v1.0.0` for the gated paths. Do not claim the rest.**

Ship means: login cannot pick another organization (F-02), a portfolio cannot be read or changed across organizations (F-03), an invalid AI skill level is not stored as a real score (F-04), and the API starts from a clean checkout (F-01). The **Release** workflow on tag `v1.0.0` was releasable: https://github.com/Nandi-exl/handle-quality-net/actions/runs/37594382378

Do not ship if you need any of these to be true, because they are not gated:

- A first-time web checkout talks to the API with no `.env` (client defaults to port 3000; API is 3001).
- Live interview quality, audio, or real Gemini output.
- Eager-load of the whole API in test (pre-existing `AudioWebSocketMiddleware` name mismatch). The live API still boots.

If a new P0 or P1 is found and still open, the call becomes **do not ship** until it is fixed or explicitly accepted with a named owner. See `assessment/03-release-decision.md`.


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

**Fix:** 
`config/puma.rb` now creates the pidfile directory before Puma writes to it (`FileUtils.mkdir_p`). This works for every start path (Procfile, Docker, CI) and for a custom `PIDFILE`. The `.gitignore` conflict is left as is; startup no longer depends on it.

**Red → green:** 
- Red: `3e6454a` added the API boot check; it failed on the pidfile crash. <link to failed run>
- Green: `e33f81d` fixed `puma.rb`; the same unchanged check passed. <link to passing run>

---

- ID : F-02
- Sev : P0
- Finding : Any admin user can obtain a valid token for any organization by choosing it in a request header at login
- Type : Missing spec (multi-tenancy and login are undefined) + Built wrong (authorization trusts client input)
- Impact : Any admin of one client can enter any other client's organization and read or change its vacancies, assessments, interview sessions, and candidate data
- Status : Fixed (a371fea)

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

**Fix:** 
Users now belong to one organization (`users.tenant_id`, new migration). Login signs the user's own organization into the token and returns `403` if the user has none. Removed: `resolve_scheme`, which took the organization from the `X-Tenant-Scheme` header and fell back to the first organization in the table.

**Assumption (not in spec):** 
a user belongs to exactly one organization. If users are meant to work across several organizations, this needs a membership table and an explicit organization choice that is checked against it.

**Deploy note:** 
existing users have no organization after the migration and get `403` at login until one is assigned.

**Red → green:** 
- Red: `fc47200` added the F-02 API tests; two of three failed (tokens issued for both organizations, header honoured). The positive control passed. <link to failed run>
- Green: `a371fea` fixed login; the same unchanged tests passed. The only test-data change gives the test admin its organization (`ci_fixtures.rb`). <link to passing run>

---

- ID : F-03
- Sev : P0
- Finding : An admin of one organization can read and change another organization's candidate portfolios by id
- Type : Built wrong (sessions, assessments, and vacancies are filtered by organization; portfolios and portfolio skills are not)
- Impact : One client's admin can export another client's candidate portfolio and overwrite that candidate's skill levels
- Status : Fixed (2304f74)

### F-03: Portfolio reads and skill overrides ignore the organization

**Severity:**
P0. F-02 closed the door at login, and this is the same door on the data itself. A caller who already belongs to one organization can still read and change another organization's candidate assessment. Even read as a data-integrity issue it is at least P1, because the override is saved and then deletes and regenerates that portfolio's fit/gap reports.

**Type:**
Built wrong. Organization filtering exists and works for sessions, assessments, and vacancies. Portfolios belong to a session, but the portfolio endpoints look the portfolio and its skills up by id alone.

**Impact:**
An admin token for organization B can export organization A's candidate portfolio (skills, evidence quotes, competency summaries) and can set that candidate's skill levels. The override is stored and triggers regeneration of A's fit/gap reports.

**Evidence / repro:**
Setup: organizations `test-corp` and `other-corp`. User `other-admin@example.com` belongs to `other-corp`. A completed portfolio (id 1) with one skill (id 1, label "Ruby", ai_level 3) belongs to a session (id 1) whose assessment belongs to `test-corp`. All calls use the `other-corp` token.
1. `GET /api/v1/sessions/1/portfolio` → `404` "Session not found". Session lookup is filtered by organization. This is the control.
2. `GET /api/v1/portfolios/1/export` → `200`, body contains portfolio 1, session 1, skill "Ruby". Cross-organization read.
3. `POST /api/v1/portfolio_skills/1/override` with `{"override":{"override_level":5}}` → `201` Created.
4. The skill's assessor override is stored with `override_level` 5.
5. `GET /api/v1/portfolios/1/fitgap/1` → `404` "Fit/gap report not found", not "Portfolio not found". The portfolio itself was found; only the report is missing.

**Root cause:**
`Portfolio` and `PortfolioSkill` are not organization-scoped. `PortfoliosController#set_portfolio` uses `Portfolio.find(params[:id])` for export, and `fitgap`, `show_fitgap`, and `regenerate_fitgap` do the same. `PortfolioSkillsController#set_portfolio_skill` uses `PortfolioSkill.joins(:portfolio).find(params[:id])`. None of these joins go through `Session`, which is the model that actually filters by organization.

**Not verified:**
`POST /api/v1/portfolios/:id/fitgap` and `POST /api/v1/portfolios/:id/regenerate_fitgap` now use the same organization-scoped lookup as export. The tests do not call them, because they enqueue background jobs.

**Fix:**
A request can load a portfolio only when its session belongs to the caller's organization (`Portfolio.find_for_current_tenant!`, and the same for `PortfolioSkill`). Any other id is a 404. Removed: `Portfolio.find(params[:id])` on export, fit/gap, and fit/gap regeneration, and `PortfolioSkill.joins(:portfolio).find(params[:id])` on skill override. The background fit/gap job still uses `Portfolio.find`, because it runs with no logged-in organization.

**Red → green:**
- Red: `bf71dc2` added the F-03 API tests. The owning organization could export (the positive control passed). The other organization also got 200 on export and on skill override. <link to failed run>
- Green: `2304f74` scoped the lookups. The same unchanged tests passed. That commit also sets `AUTH_LOGIN_LIMIT` for the API tests workflow only, so the suite can log in once per test. The default login limit stays 5 per minute. <link to passing run>

---

- ID : F-04
- Sev : P1
- Finding : An invalid or missing AI skill level is saved as a real L1–L5 score
- Type : Built wrong (a fabricated score is stored as an assessed level)
- Impact : A candidate who was not scored on a skill looks like a weak (or, if the value was too high, expert) candidate, and the fit/gap report treats that invented level as a real gap or exceed
- Status : Fixed (0b1455a)

### F-04: Invalid skill levels are clamped into real scores

**Severity:**
P1. The product still produces a portfolio, so the objective is reached. The data underneath is wrong: a missing or out-of-range model output is stored as a valid L1–L5 score. Any data-integrity issue is at least P1.

**Type:**
Built wrong. A skill level is an assessed score. A missing or invalid level is not a score, and it must not be written as one. The spec does not say what to do instead; it also does not say to invent L1 or L5.

**Impact:**
A recruiter reading the portfolio, or a fit/gap report comparing the candidate to a vacancy, treats the invented number as a real assessment. `nil` and `"N/A"` become L1, so an unassessed skill looks like a weak candidate. `9` becomes L5, so a bad model output looks like an expert.

**Evidence / repro:**
A completed session, with Gemini replaced by a fixed response, so no API key is needed.
1. `Portfolios::Generator` is called with configured skills whose `level` values are `nil`, `"N/A"`, `0`, `9`, and `3`.
2. `portfolio.portfolio_skills.pluck(:skill_label, :ai_level)` returns:
`[["Missing level", 1], ["Not assessed", 1], ["Zero", 1], ["Too high", 5], ["Valid", 3]]`

Only "Valid" is a real score. The other four were rewritten.

**Root cause:**
`Portfolios::Generator#save_skills` writes `skill_data['level'].to_i.clamp(1, 5)`. In Ruby, `nil.to_i` and `"N/A".to_i` are `0`, and `0.clamp(1, 5)` is `1`. `9.clamp(1, 5)` is `5`. The database check (`ai_level` between 1 and 5) then accepts the invented value. Nothing is logged.

**Not verified:**
Whether the same clamp exists on assessor override input. The override endpoint already has a database check for 1–5, so an invalid override should fail rather than be rewritten; that path was not exercised.

**Fix:**
A level is stored only when it is an integer from 1 to 5 (`assessed_level`). Anything else is skipped and logged. Removed: `skill_data['level'].to_i.clamp(1, 5)` on both configured and discovered skills.

**Assumption (not in spec):**
reject the bad skill; do not fail the whole portfolio. A valid skill in the same response is still saved. Fit/gap then treats the missing skill as not assessed.

**Red → green:**
- Local red: `7925e88` added the F-04 examples. Two of three failed (invented L1 and L5). The valid-L3 example passed.
- Product fix: `0b1455a` removed the clamp. The same unchanged examples passed locally.
- CI note: the **API tests** runs on `7925e88` and `0b1455a` were also red, but for a different reason. GitHub sets `CI=true`, which eager-loaded the app and raised `uninitialized constant AudioWebsocketMiddleware` before any example ran. That name error was already in the original import (class `AudioWebSocketMiddleware` vs file `audio_websocket_middleware.rb`). `4ee3150` turns eager load off in test so the examples can run. The F-04 assertions were not changed.
- Green: `4ee3150` plus the product fix. <link to passing run>

## Leads to verify

Observed while reading config. These are not confirmed findings yet.

- `ALLOWED_ORIGINS` is read with `ENV.fetch` and no default, so the API fails to boot if it is unset. The sample config sets it to `"*"` (any origin).

- The README and `application.yml.sample` disagree on variable names (`GEMINI_ANALYSIS_MODEL` vs `GEMINI_FLASH_MODEL`).

- The README's frontend step points to `../ai-interview-web`; the folder is `web/`.

- JWT signing depends on `SECRET_KEY_BASE` matching an external service, and organizations are expected to come from an external shared database. The platform's auth and tenancy depend on a system that is not in this repo.

- Eager load fails on `AudioWebSocketMiddleware` (file `audio_websocket_middleware.rb`). The live API still boots because an initializer `require_relative`s the file. Test eager load stays off until this is fixed.

## Systemic pattern

_To be written once enough findings are in._

## Coverage of this audit

_What was examined deeply, what was skimmed, and what was not examined. To be written at the end._

