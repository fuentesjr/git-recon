---
name: git-recon
description: History-first codebase investigation via the git-recon CLI. Use BEFORE reading code in an unfamiliar repo, when asked to review/audit/orient in a codebase, find hotspots or likely owners, or investigate instability (frequent fixes, reverts, rollbacks); also BEFORE editing a file whose history you have not seen, and BEFORE declaring a change done (check co-changed files and tests). Not for jj-native repos (no .git directory).
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

## Before editing a file

If you have not looked at a file's history, run `git-recon hotspot <path>`
or `git-recon facts --format=json -- <path>` first. Note recent fixes and
coupled files. Run `git-recon owners <path>` to find who has context.

## Before declaring a change done

For each edited file, find its matching tests and confirm any you did not
touch were left alone on purpose. Then run `git-recon coupling <path>` (or
read the `coupled` facts). Treat an untouched coupled file as a lead only
when its co-change count is 3 or more; lower counts are mostly noise from
sweep commits.

## Automated consumers

Use the versioned machine contract when a tool or pipeline needs bounded
history for one known seed path, instead of parsing the human reports:

```text
git-recon facts --format=json [--at REV] [-L START,END] -- PATH
```

One compact JSON line per call: a shared commit table (capped at 20) plus
recent, repair, and coupled-path facts — and line origins with `-L` — each
capped at five. The window is 365 days anchored to the resolved revision.
Typed errors go to stdout as JSON with a nonzero exit; shallow repositories
are refused. Resolve the seed to a repository path (and optional line range)
before calling, and parse by the schema (`schema/facts-v1.schema.json` in
the git-recon repo) rather than displaying the transport directly. For
interactive orientation this supplements, and never replaces, the
overview-first workflow above.

Rows are positional arrays, not objects. `recent`, `repairs`, and the last
element of each `coupled` row `[path, count, [indexes]]` are indexes into
`commits` (`[oid, epoch, subject]`). `origins` rows are
`[commit index, start, end]`.

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
