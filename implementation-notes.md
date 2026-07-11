# implementation notes — git-recon

## Decisions

- Self-contained bash with raw git commands, no dependency on the
  `.gitconfig` aliases — the whole point is portability to
  containers/machines without the dotfiles.
- `set -eu` without `pipefail`: every section pipes through `head`, which
  SIGPIPEs upstream `sort` when it closes early; pipefail would turn that
  into a spurious failure.
- Hard output caps (recent 50, churn 30, churn-dirs 20, bug-files 20,
  hotspot 25 commits) for agent token economy; each capped section says so
  in its header or a trailing note, and points at raw git for full history.
- Interpretation guidance lives only in `explain`/`help` (user's choice) so
  data output stays clean; the Claude skill carries a condensed version.
- Windows (90d / 1y / 6mo) are constants at the top of the script, not
  flags — no demonstrated need for per-call tuning yet.
- `hotspot` keeps `--follow` parity with the original alias; on directories
  git ignores it silently, matching prior behavior.
- Skill is canonical in `skills/git-recon/`, symlinked from
  `~/.claude/skills/` (matches existing pattern there, e.g. skill-pruner).
- Script symlinked into `~/.local/bin` (on PATH via .zprofile and .zshrc);
  `~/bin` exists but is NOT on PATH.

## Scope boundaries

- No jj support: script dies with a clear message on jj-native repos.
- `branches`/`incoming`/`outgoing`/`tags-recent` aliases deliberately left
  out — they concern local branch state, not codebase investigation.
- Not added to the preferences gist; propose separately if it proves useful.

## Verification

- All subcommands exercised against the full `~/Projects/rails` checkout
  (see session log): overview, hotspot, owners, blame -L, repairs, monthly,
  explain, error paths (unknown command, missing arg, non-repo, jj repo).
- `git shortlog` stdin gotcha checked: `--all` supplies revisions, so it
  does not fall back to reading stdin when non-interactive.
