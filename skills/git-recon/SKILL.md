---
name: git-recon
description: History-first codebase investigation via the git-recon CLI. Use BEFORE reading code in an unfamiliar repo, when asked to review/audit/orient in a codebase, find hotspots or likely owners, or investigate instability (frequent fixes, reverts, rollbacks). Not for jj-native repos (no .git directory).
---

# git-recon

Use git history to decide what to read first, instead of reading code blind.
Churn and repair patterns expose recurring behavior over time — this is the
concrete form of the user's systems-thinking preference for orienting in
unfamiliar codebases.

## Workflow

1. `git-recon overview` — one call: recent activity, file/dir churn, active
   authors, repair-shaped commits. Start every investigation here.
2. Pick a suspicious file or directory from the churn/repairs sections.
3. `git-recon hotspot <path>` — commit history + per-commit stats for it.
4. `git-recon owners <path>` — likely owners / who has context.
5. `git-recon blame -L start,end <file>` — recent line-level history.
6. Only now read the code, with historical context.

Run `git-recon explain` once if you need interpretation guidance for a
section (caveats, what each signal does and does not mean).

## Rules

- Treat output as signal, not proof. The repairs section is a commit-message
  heuristic; corroborate before concluding anything about quality or health.
- Check whether top churn entries are real logic files or expected glue
  (lockfiles, routes, generated code) before drilling in.
- Shallow clones and squash-merge workflows weaken every signal — note this
  in your findings if the repo is one.
- If `git-recon` is not on PATH (fresh container), fall back to raw git:
  the script at `~/Projects/git-recon/bin/git-recon` documents every
  underlying command.
- jj-native repos have no `.git` directory and are unsupported; use `jj log`
  directly instead.
