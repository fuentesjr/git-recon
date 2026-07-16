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
git-recon overview              # first pass: vitals, recent, churn, authors, repairs
git-recon vitals                # repo scale + concentration, to calibrate the rest
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

[docs/examples.md](docs/examples.md) walks through a real session against
rails/rails — overview, deep, and drill-downs with annotated output.

### Automated facts interface

Use the compact JSON contract when a tool needs bounded history for one seed
path instead of the human-oriented reports above:

```text
git-recon facts --format=json [--at REV] [-L START,END] -- PATH
```

The command emits one compact line; whitespace is added below for display:

```json
{"v":1,
 "at":"f827fcb7488463a6e2f24d133499e646066e34d3",
 "path":"app/models/user.rb","since":1718287100,
 "commits":[["f827fcb7488463a6e2f24d133499e646066e34d3",
              1749823100,"Fix stale account state"]],
 "recent":[0],"repairs":[0],
 "coupled":[["app/services/sync.rb",8,[0]]],
 "origins":[[0,42,57]]}
```

`commits` rows are `[oid, epoch, subject]`; `recent` and `repairs` contain
indexes into `commits`; `coupled` rows are
`[path, count, [supporting_commit_indexes]]`; `origins` rows are
`[commit_index, start_line, end_line]`. OIDs are full SHA-1 or SHA-256 values.

The window is exactly 365 days before the resolved revision's committer time,
inclusive at both ends. It applies to recent commits, repair commits, and
coupled paths. Origins may reference older ancestors because they describe who
last changed the requested current lines. Each fact list is capped at five;
commits are shared across lists and capped at 20. Recent and repair commits
rank newest first, with full OID as the tie-breaker. Coupled paths rank by
count, then path; origins follow current line order.

Repair candidates match `fix|bug|broken` case-insensitively against the full
commit message. Coupling counts qualifying cochanges with the seed: commits
touching more than 30 distinct added, modified, or deleted paths are skipped,
and only coupled paths that exist at the resolved revision are returned. Its
  supporting indexes are representative and capped at five. They reuse
support commits from the fixed recent/repair commit table; when none occur
there, the producer reuses or adds the newest support. History is scoped to the
literal path and does not
follow renames. Origins are emitted only with `-L`; they collapse contiguous,
whitespace-insensitive blame spans inside the requested current-line range.

Shallow repositories are refused. Typed errors go to stdout as JSON and exit
nonzero. The interface omits author-name and email metadata, commit-message
bodies, patches, and raw Git output. Path and subject text are not
privacy-filtered. It requires the system `iconv` command and accepts only
UTF-8 paths without control bytes. The exact contract is
[JSON Schema 2020-12](schema/facts-v1.schema.json). Rules outside the schema:
indexes address `commits`, origin start lines do not exceed end lines, and
subjects are capped at 160 UTF-8 bytes. Subject normalization maps C0/DEL
controls to spaces, collapses and trims whitespace, drops invalid UTF-8, then
drops any partial codepoint left by the byte cap.

## Install

```sh
ln -s "$PWD/bin/git-recon" ~/.local/bin/git-recon
```

Claude Code skill (routes agents to the tool automatically):

```sh
ln -s "$PWD/skills/git-recon" ~/.claude/skills/git-recon
```

## Design notes

- Human-oriented reports use plain text with hard caps per section, so agent
  token cost stays bounded on large repos. Raw git is the escape hatch for
  full history.
- `overview` stays the cheap orientation pass. Run `deep` explicitly when an
  investigation needs slower risk and instability analysis, then use the
  path-based drill-down commands on the strongest signals.
- Everything here is signal, not proof. The `repairs` section is a
  commit-message heuristic and depends on message discipline in the repo.
- `facts` is the versioned machine contract; it does not change the plain-text
  human commands or their overview-first workflow.
- Requires a `.git` directory; jj-native repos are unsupported (use `jj`
  directly).
