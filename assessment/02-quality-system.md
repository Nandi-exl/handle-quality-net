# 02 — Quality system

> **Status: working draft.** This is the net so far: what each check is, where it lives, and how to run it. The release gate (G3) is not in yet.

Each check matches how the bug shows up. There is no single test folder for every finding.

## How to run

From the repo root, with Docker already up.

**Boot (F-01):** CI only. Push to `main` and open the **API boot** workflow. It starts Puma from a clean checkout and hits `/health`.

**API tests (F-02, F-03):**

```bat
cd web
npx vitest run --config vitest.api.config.ts
```

Needs the API on `http://127.0.0.1:3001`.

**Unit tests (F-04):**

```bat
docker compose exec -e RAILS_ENV=test api bundle exec rspec
```

Does not need the API running. Uses the `rakamin_test` database and a fake Gemini client.

On GitHub, **API tests** runs the unit tests first, then the black-box API tests. **API boot** is a separate workflow.

## Checks

- ID : F-01
- Kind : Boot
- File : `.github/workflows/api-boot.yml`
- Protects : API starts from a clean checkout
- Does not cover : HTTP behaviour, data, Gemini
- Status : Green after `e33f81d`

- ID : F-02
- Kind : Black-box API
- File : `web/test/api/f02-tenant-login.test.ts`
- Protects : Login issues a token only for the user's own organization
- Does not cover : Portfolio lookups, skill scores
- Status : Green after `a371fea`

- ID : F-03
- Kind : Black-box API
- File : `web/test/api/f03-portfolio-tenant.test.ts`
- Protects : A portfolio can only be read or changed by the organization that owns its session
- Does not cover : Login, skill-level generation
- Status : Green after `2304f74`

- ID : F-04
- Kind : Unit
- File : `api/spec/services/portfolios/f04_generator_levels_spec.rb`
- Protects : An invalid or missing AI skill level is not stored as a real L1–L5 score
- Does not cover : HTTP, live Gemini output
- Status : Fixed (`0b1455a`). CI can run the examples after `4ee3150` (eager load off in test).

- ID : G2
- Kind : Workflow gate
- Files : `.github/pull_request_template.md`, `.github/workflows/definition-of-ready.yml`, `.github/scripts/check_definition_of_ready.py`
- Protects : A pull request names a spec, acceptance criteria, a design plan, and a test (or N/A plus a reason)
- Does not cover : Whether those inputs are good, whether product tests pass, or commits pushed straight to `main`
- Status : Files added. Needs two demo PRs (one blocked, one passing).

## G2 — how the gate works

This check runs only on pull requests, not on push to `main`.

1. GitHub fills a new PR with the template.
2. The **Definition of Ready** workflow reads the PR body.
3. Each of the four headings must have text that is not only an HTML comment. `N/A` plus a reason is enough.
4. Edit the PR body and the check runs again.

To try it locally:

```bat
set PR_BODY=## Spec / PRD%0Aassessment/01-audit.md#f-04%0A%0A## Acceptance criteria%0AGiven an invalid level, When the generator runs, Then that skill is not saved.%0A%0A## Design plan%0ARemove the clamp.%0A%0A## Test%0Aapi/spec/services/portfolios/f04_generator_levels_spec.rb
python .github\scripts\check_definition_of_ready.py
```

On GitHub, open two PRs and leave them visible: one with a blank body (blocked), one with all four sections filled (passing).

## Why the files sit in different places

- F-01 dies before any client can call the API, so the check is "does the process stay up."
- F-02 and F-03 are wrong HTTP answers, so the check is a TypeScript client against the running API, the same way the web app talks to it.
- F-04 happens inside a background job after Gemini returns. There is no endpoint that accepts fake skill levels, so the check calls `Portfolios::Generator` with a stub client.

## G3 — how the release gate works

On a version tag (`v*`), workflow **Release** runs API boot and API tests, then prints **releasable** or **blocked**.

1. Commit the notes and the workflow to `main`.
2. Tag `v1.0.0` on that commit and push the tag.
3. Open the **Release** run. The last job is the status.
4. Copy that result into `assessment/03-release-decision.md`.

G2 demo PRs stay open: one blocked, one passing. They are not part of the tag gate.

## Not built yet

- Close the audit: ranking, systemic pattern, ship / do-not-ship, and coverage in `01-audit.md`.



