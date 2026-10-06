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

