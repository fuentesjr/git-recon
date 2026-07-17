# implementation notes — git-recon

## Decisions

- Self-contained bash with raw git commands, no dependency on the
  `.gitconfig` aliases — the whole point is portability to
  containers/machines without the dotfiles.
- `set -eu` without `pipefail`: every section pipes through `head`, which
  SIGPIPEs upstream `sort` when it closes early; pipefail would turn that
  into a spurious failure.
- Hard output caps (recent 50, churn 30, churn-dirs 20, bug-files 20,
  hotspot 25 commits, deeper analyses 20 each) for agent token economy; each
  new capped section says so in its header or a trailing note.
- Interpretation guidance lives only in `explain`/`help` (user's choice) so
  data output stays clean; the Claude skill carries a condensed version.
- Windows (90d / 1y / 6mo) are constants at the top of the script, not
  flags — no demonstrated need for per-call tuning yet.
- `hotspot` keeps `--follow` parity with the original alias; on directories
  git ignores it silently, matching prior behavior.
- `overview` remains the cheap orientation call; `deep` is the explicit
  second pass for coupling, risk, knowledge silos, repair rate, and test gaps.
- Coupling is commit-level pair counting in `awk`, limited to one year and
  skips commits over 30 files. Ratios were omitted to keep the full-repo pass
  simple and fast; counts are the primary signal requested.
- Risk uses current text files only. Complexity is lines times maximum
  indentation (tabs count as one level; two spaces as one), joined to one-year
  historical churn; deleted files and binary files are excluded.
- Silos analyzes only the top 20 churn files; fix-rate requires five commits;
  test-gap selects the top 20 non-test churn files before its commit pass.
- Test classification is path-only: test/tests/spec/__tests__ directories and
  conventional `_test`, `_spec`, `.test`, and `.spec` filenames.
- Skill is canonical in `skills/git-recon/`, symlinked from
  `~/.claude/skills/` (matches existing pattern there, e.g. skill-pruner).
- Script symlinked into `~/.local/bin` (on PATH via .zprofile and .zshrc);
  `~/bin` exists but is NOT on PATH.
- Style: Google Shell Style Guide — `[[ ]]`, quoted expansions, `local`,
  `readonly` constants, `main()` dispatch, ≤80-char lines, ShellCheck clean
  (one targeted SC2016 disable for a single-quoted awk program). Deliberate
  deviations documented in the header: env shebang (macOS /bin/bash is 3.2)
  and no pipefail (SIGPIPE rationale above).
- `facts` is a separate, versioned compact JSON contract for automated
  consumers. Fixed tuples avoid repeated keys: commits are `[oid, epoch,
  subject]`, lists reference commit indexes, coupling is
  `[path, count, [supporting commit indexes]]`, and line origins are
  `[commit_index, start, end]`.
- Its 365-day window anchors to the resolved revision, not wall-clock time.
  The inclusive window applies to recent, repair, and coupling facts; line
  origins may name older ancestors. Lists cap at five, shared commits cap at
  20, and deterministic sort keys are part of the contract. Full OIDs
  preserve SHA-1 and SHA-256 compatibility.
- Coupling provenance is representative rather than exhaustive. Up to five
  supporting indexes reuse support commits from the fixed recent/repair base
  table. If none occur there, the newest support is reused or added. This
  preserves traceability without letting the compact table grow without bound.
- Repairs match `fix|bug|broken` case-insensitively against the full commit
  message. Coupling skips commits with more than 30 distinct added, modified,
  or deleted paths and returns only paths present at the resolved revision.
  Path history is literal and does not follow renames. Origins are contiguous,
  whitespace-insensitive blame spans and are produced only for `-L`.
- `schema/facts-v1.schema.json` defines success and typed failure payloads.
  Cross-field index/range checks and the 160 UTF-8-byte subject cap remain
  documented rules because JSON Schema cannot express them.
- Valid UTF-8 path text is preserved. Subject normalization maps C0/DEL
  controls to spaces, collapses and trims whitespace, drops invalid UTF-8,
  caps at 160 bytes, then drops any split trailing codepoint. Invalid or
  control-byte paths return a typed error. `iconv` is a required system tool,
  but this pass adds no package dependency.
- Machine output omits author-name and email metadata, message bodies, patches,
  and raw Git output. Paths and subjects are not privacy-filtered. Existing
  human commands and their human-oriented plain-text reports are unchanged.
- Repair matching reuses the ordinary path-history commit set with
  `git log --no-walk`; it must not pay for a second path-limited revision walk.
- Coupling filters commits over the 30-path ceiling in a quoted line-oriented
  pass, then sends only eligible commits through the exact NUL-delimited Bash
  parser. Quoted names are count keys only and never reach the JSON response.

## Scope boundaries

- No jj support: script dies with a clear message on jj-native repos.
- `branches`/`incoming`/`outgoing`/`tags-recent` aliases deliberately left
  out — they concern local branch state, not codebase investigation.
- Not added to the preferences gist; propose separately if it proves useful.
- This pass adds git-recon's agent contract only. It does not integrate
  ctxpack, score relevance, add package dependencies, or change human report
  formats.

## Verification

- Deterministic fixture suite at `test/run_tests.sh` covers every deeper
  command, `deep`, and existing `churn` with controlled authors, dates, fix
  messages, co-change pairs, a 33-file skipped sweep, and test co-change.
- Fixture suite passes. On the full Rails checkout, coupling completes in
  0.26s wall-clock and `deep` in 4.37s; all five standalone analyses complete
  successfully and produce plausible bounded output.
- Rails risk ranks code/test/guide files in its first six positions;
  `activerecord/CHANGELOG.md` is seventh and `Gemfile.lock` is outside the top
  20. Silos finds active and inactive majorities, fix-rate respects the
  five-commit floor, and test-gap is ordered from low to high co-change.
- Unknown commands, missing required arguments, excess coupling arguments,
  and execution outside a Git repository all exit nonzero with `die()` errors.
- All subcommands exercised against the full `~/Projects/rails` checkout
  (see session log): overview, hotspot, owners, blame -L, repairs, monthly,
  explain, error paths (unknown command, missing arg, non-repo, jj repo).
- `git shortlog` stdin gotcha checked: `--all` supplies revisions, so it
  does not fall back to reading stdin when non-interactive.
- Post-implementation style pass re-verified: `shellcheck` clean on script
  and tests, zero lines over 80 chars, fixture suite green, `deep` runs
  clean on Rails.

### Facts contract evidence

- Baseline: `test/run_tests.sh` passed and ShellCheck was clean before edits.
- Tracer RED: the suite exited 1 with `git-recon: unknown command: facts`;
  GREEN: the fixture suite passed.
- Recent/repair RED: `facts should rank recent and repair commits for the
  seed path`; coupling RED: `facts should rank current co-change paths for the
  seed path`. Each slice reached the fixture-suite PASS line.
- Origins RED: `facts --format=json -L 1,2` exited nonzero with the prior usage
  error; GREEN: the fixture suite passed.
- Typed-error RED: `facts should report not_repository as compact JSON on
  stdout`; the shallow case was also observed red. Unicode RED: `facts should
  accept valid UTF-8 paths`. GREEN preserved `lib/café.rb` and its Unicode,
  quoted, backslashed subject; the fixture suite passed.
- Final verification: `test/run_tests.sh` printed its PASS line; ShellCheck
  and `/bin/bash -n bin/git-recon test/run_tests.sh` were clean. Ruby's JSON
  parser loaded the schema, `git diff --check` was clean, and help displayed
  the facts syntax. No new line exceeds 80 characters; existing long lines
  remain unchanged.
- Documentation and schema reconciliation corrected the example cutoff,
  bounded the shared commit table at 20, documented signal semantics and
  privacy limits, and restored representative coupling provenance as the
  third tuple item. Ruby's JSON parser and `git diff --check` verify these
  documentation-only edits.
- Review caught a Rails-scale process-amplification defect before acceptance:
  the first implementation spawned work per escaped control byte, candidate
  commit, and candidate path and did not finish the representative Rails path
  within 35 seconds. The corrected path normalizes controls in one pipeline,
  rejects oversized commits before partner work, batches current-tree object
  checks, and streams all candidate diffs through one Git process. Parent
  smokes for Rails' PostgreSQL adapter completed in 10.27–13.02 seconds; the
  interface is now bounded but remains a deliberately non-instant history
  query on a large, high-churn seed.
- Additional fixture coverage protects future-timestamp exclusion, literal
  pathspecs, Git-failure propagation, signal cleanup, list and provenance
  caps, equal-epoch OID ordering, historical revisions, locale/time-zone
  replay, and UTF-8-safe subject truncation with empty success stderr.
- A Rails Trace2 profile of the PostgreSQL adapter query measured 10.417s wall
  time. Three path-history walks used 4.776s, all 23 Git processes used 5.116s,
  and Bash spent 4.763s parsing 38,092 diff tokens. The optimized query parses
  1,130 exact tokens after a cheap quoted-name count pass and reuses the first
  history walk for repair filtering.
- `test/benchmark_facts.sh` is an opt-in, external-checkout benchmark because
  wall time is unsuitable for the deterministic fixture suite. At an 8s gate,
  the pinned Rails case was red at 10.776s and green at 4.965s with the same
  1,920 bytes (SHA-256
  `02c35bdc7c0d73c3b7eaece160ec4f0ad66efcc72558b940cf4f17d329e1ff43`).
- Final checkout runs completed in 4.838s, 4.845s, and 5.192s. The fixture
  suite, ShellCheck, Bash syntax checks, and `git diff --check` all pass.
- A compiled rewrite is not justified by this profile. Keeping Git subprocesses
  leaves roughly one second of orchestration overhead after optimization;
  replacing the history walks would instead be a new Git-semantics and
  distribution project. If a future target requires that work, evaluate Rust
  first, C/libgit2 second, and Zig only with evidence of a specific advantage.
