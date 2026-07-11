# git-recon

History-first codebase investigation for humans and AI agents.

Before reading code in an unfamiliar repo, use its git history to decide what
to read first: hotspots (churn), likely owners, and repair patterns (bug-fix
and rollback-shaped commits). One `overview` call gives the first pass;
`deep` adds slower risk/instability signals, and focused drill-down
subcommands follow the trail.

This is a self-contained port of the review aliases in
`dotfiles/git/.gitconfig` (documented in `GIT_ALIASES_CHEATSHEET.md` there),
so it works on machines and containers that don't have those aliases.

## Usage

```text
git-recon overview              # first pass: recent, churn, authors, repairs
git-recon deep                  # coupling, risk, silos, fix-rate, test-gap
git-recon coupling app/models   # files that co-change with this path
git-recon risk                  # churn weighted by current complexity
git-recon silos                 # concentrated and inactive ownership
git-recon fix-rate              # normalized repair-shaped commit rate
git-recon test-gap              # logic changes without test co-change
git-recon hotspot app/models    # history + stats for one path
git-recon owners app/models     # top contributors for one path
git-recon blame -L 10,40 foo.rb # whitespace-insensitive blame
git-recon explain               # how to interpret each section
git-recon help                  # full command list
```

Because the script is named `git-recon` and on PATH, `git recon <cmd>` also
works.

## Install

```sh
ln -s "$PWD/bin/git-recon" ~/.local/bin/git-recon
```

Claude Code skill (routes agents to the tool automatically):

```sh
ln -s "$PWD/skills/git-recon" ~/.claude/skills/git-recon
```

## Design notes

- Output is plain text with hard caps per section, so agent token cost stays
  bounded on large repos. Raw git is the escape hatch for full history.
- `overview` stays the cheap orientation pass. Run `deep` explicitly when an
  investigation needs slower risk and instability analysis, then use the
  path-based drill-down commands on the strongest signals.
- Everything here is signal, not proof. The `repairs` section is a
  commit-message heuristic and depends on message discipline in the repo.
- Requires a `.git` directory; jj-native repos are unsupported (use `jj`
  directly).
