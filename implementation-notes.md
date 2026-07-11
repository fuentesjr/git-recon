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

## Scope boundaries

- No jj support: script dies with a clear message on jj-native repos.
- `branches`/`incoming`/`outgoing`/`tags-recent` aliases deliberately left
  out — they concern local branch state, not codebase investigation.
- Not added to the preferences gist; propose separately if it proves useful.

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
