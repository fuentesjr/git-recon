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

1. `git-recon overview` — one call: repo vitals (scale/concentration),
   recent activity, file/dir churn, active authors, repair-shaped commits.
   Start every investigation here. Use vitals to calibrate every other
   number: churn counts only mean something relative to repo size, and the
   churn share footers say whether the repo is hotspot-driven at all.
2. If the investigation is about risk or instability, run `git-recon deep`.
3. Pick a suspicious file or directory from the strongest signals.
4. `git-recon hotspot <path>` — commit history + per-commit stats for it.
5. `git-recon owners <path>` — likely owners / who has context.
6. `git-recon blame -L start,end <file>` — recent line-level history.
7. Only now read the code, with historical context.

Run `git-recon explain` once if you need interpretation guidance for a
section (caveats, what each signal does and does not mean).

## Automated consumers

Use this bounded machine contract when an agent or tool needs history for a
known seed path:

```text
git-recon facts --format=json [--at REV] [-L START,END] -- PATH
```

For ctxpack, resolve the input seed to a repository path and optional source
range before calling `facts`; ctxpack decides which returned facts enter its
packet. Parse the versioned compact JSON by its schema rather than displaying
the transport directly. This interface supplements, and never replaces, the
overview-first human orientation workflow above.

## Rules

- Treat output as signal, not proof. The repairs section is a commit-message
  heuristic; corroborate before concluding anything about quality or health.
- Check whether top churn entries are real logic files or expected glue
  (lockfiles, routes, generated code) before drilling in.
- `facts` refuses shallow repositories. Shallow clones and squash-merge
  workflows weaken the human-oriented reports; note this in your findings.
- If `git-recon` is not on PATH (fresh container), fall back to raw git:
  the script at `~/Projects/git-recon/bin/git-recon` documents every
  underlying command.
- jj-native repos have no `.git` directory and are unsupported; use `jj log`
  directly instead.
