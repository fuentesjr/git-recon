# Worked example: investigating rails/rails

A real session showing the intended workflow: `overview` to orient, `deep`
for risk signals, then drill-downs on the strongest trail. Every code block
below is actual output; rows elided from the middle of a block are marked
with `…` in place, and `… (output trimmed)` marks a truncated tail. The
interpretation notes are what you'd conclude at each step.

Pinned so drift is detectable:

- git-recon `f1e33d6` (2026-07-11)
- rails/rails at `3947087c36` (main, 2026-07-12), full-history
  single-branch clone (vitals counts all refs, so a default clone's numbers
  will differ slightly)
- session run 2026-07-12

The run date is a load-bearing pin, not trivia: every analysis window
(`1 year ago`, 90 days, 6 months) resolves against the clock at run time,
not against the checkout. Checking out `3947087c36` pins the upper bound of
history, but the window's lower bound moves with the clock — run this
months later and `recent` drains while churn counts shrink. To reproduce
exactly, run on a clock set to 2026-07-12 (e.g. libfaketime), or rerun the
underlying git commands with absolute dates (`--since=2025-07-12` matches
the one-year sections byte-for-byte). Rows with equal counts may swap order
across locales.

## 1. Orient: `git-recon overview`

```text
== vitals ==
commits: 98779 all-time (first 2004-11-24), 3411 in last year
files: 1953 touched in last year, 4968 tracked
authors: 239 active in last 6 months of 6438 all-time; top: Kenta Ishizaki (19% of recent commits)
```

Calibration for everything below: a mature, large, multi-owner repo. The top
recent author holds only 19% of commits, so no single person is the repo. In
a repo where 1,953 files changed last year, 42 commits on one file is a lot.

```text
== recent (last 90 days, first 50) ==
2026-07-12 3947087c36 fatkodima Merge pull request #58077 from 55728/fix-query-command-line-comment-strip
2026-07-11 09e9417652 Kenta Ishizaki Strip only the commented line when detecting a LIMIT in rails query
2026-07-12 109b3c4c58 fatkodima Merge pull request #58092 from 55728/fix-relative-time-in-words-non-time-inputs
2026-07-12 b0955ca345 Kenta Ishizaki Accept Date and numeric inputs in relative_time_in_words
2026-07-12 d30eb2413c fatkodima Merge pull request #58091 from 55728/fix-sqlite3-add-check-constraint-if-not-exists
…
2026-07-11 82557c1738 kyuuri1791 Fix MySQL POINT and MULTIPOINT columns being misreported as integers
…
2026-07-07 43bc0d9dc7 Winfield Peterson Fix ActionController::Live streams hanging on client disconnect
… (output trimmed)
```

Daily cadence, merge-PR workflow, and descriptive "Fix …" subjects. That
last part matters: the `repairs` and `fix-rate` sections are commit-message
heuristics, and this repo's message discipline means they'll be trustworthy.

```text
== churn (last year, top 30 files) ==
 124 activerecord/CHANGELOG.md
  67 actionpack/CHANGELOG.md
  66 Gemfile.lock
  60 activesupport/CHANGELOG.md
  55 railties/CHANGELOG.md
  53 guides/source/configuring.md
  42 activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb
  37 activerecord/lib/active_record/connection_adapters/abstract/database_statements.rb
  34 activestorage/CHANGELOG.md
  33 activerecord/lib/active_record/connection_adapters/abstract/connection_pool.rb
…
  26 activerecord/lib/active_record/relation/query_methods.rb
… (output trimmed)
(top 30 of 1953 files = 17% of 6059 changes in last year)
```

First check for expected glue — and here the entire top of the list is glue:
CHANGELOGs and `Gemfile.lock` churn because every feature touches them, not
because they're unstable. The first real logic file is
`postgresql_adapter.rb` at 42 commits. The share footer says the top 30
files cover only 17% of changes: change is spread out, so the per-file
ranking is a weak signal on its own and `churn-dirs` matters more:

```text
== churn-dirs (last year, top 20 dirs) ==
 368 guides/source
 290 activerecord/test/cases
 249 activerecord/lib/active_record
 219 activesupport/lib/active_support
 145 activesupport/test
 137 activerecord
 131 activerecord/lib/active_record/connection_adapters
 109 activerecord/lib/active_record/connection_adapters/abstract
  92 activerecord/test/cases/adapters/postgresql
…
  70 activerecord/lib/active_record/connection_adapters/postgresql
… (output trimmed)
(top 20 of 445 dirs = 42% of 6059 changes in last year)
```

Three of the top twenty directories are the same subsystem. The hotspot
isn't one file — it's the connection-adapter layer of Active Record. That's
the trail to follow.

```text
== repairs (last year) ==

== bug-files ==
  47 activerecord/CHANGELOG.md
  21 Gemfile.lock
  18 actionpack/CHANGELOG.md
…
   8 activerecord/lib/active_record/connection_adapters/postgresql/schema_statements.rb
…
   7 activerecord/lib/active_record/relation/query_methods.rb
… (output trimmed)
```

A caveat in action: CHANGELOGs dominate because Rails' convention is that
every fix commit also edits a changelog, so the glue absorbs the signal.
Read past it to the logic files — the adapter layer shows up again.

## 2. Risk pass: `git-recon deep`

```text
== coupling (last year, top 20 pairs) ==
24 Gemfile -- Gemfile.lock
20 guides/source/configuring.md -- railties/lib/rails/application/configuration.rb
18 activerecord/.../postgresql_adapter.rb -- activerecord/test/cases/adapters/postgresql/postgresql_adapter_test.rb
16 activerecord/CHANGELOG.md -- activerecord/.../postgresql_adapter.rb
15 activerecord/.../abstract/database_statements.rb -- activerecord/.../postgresql/database_statements.rb
…
12 activerecord/.../abstract/database_statements.rb -- activerecord/.../sqlite3/database_statements.rb
…
 9 activerecord/.../abstract/database_statements.rb -- activerecord/.../mysql2/database_statements.rb
… (paths shortened, output trimmed)
```

The signal here: `abstract/database_statements.rb` co-changes with its
postgresql, sqlite3, and mysql2 counterparts. That's the cross-adapter
contract — touching the abstract layer means touching every adapter. Plan
any change in this area accordingly. (The config file ↔ configuring-guide
pair is a healthy kind of coupling: docs kept in lockstep with code.)

```text
== silos (last year, top 20 churn files) ==
70% active Matthew Draper activerecord/test/cases/connection_pool_test.rb
68% active Rafael Mendonça França guides/source/8_1_release_notes.md
63% active Matthew Draper activerecord/test/cases/adapters/postgresql/postgresql_adapter_test.rb
62% active Matthew Draper activerecord/lib/active_record/connection_adapters/abstract/database_statements.rb
54% active Matthew Draper activerecord/lib/active_record/connection_adapters/abstract/connection_pool.rb
50% active Matthew Draper activerecord/lib/active_record/connection_adapters/abstract_adapter.rb
50% active Matthew Draper activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb
…
28% INACTIVE Harsh Deep guides/source/getting_started.md
… (output trimmed)
```

One person is the majority author on six of the top churn files — the
entire hotspot cluster — and they're active. So there's a clear person with
context, and no orphaned-knowledge risk on the code that matters (the one
INACTIVE entry in the top 20 is a guide).

```text
== test-gap (last year, top 20 churn files) ==
 3% 28 guides/source/getting_started.md
34% 26 Gemfile
39% 66 Gemfile.lock
…
62% 37 activerecord/lib/active_record/connection_adapters/abstract/database_statements.rb
63% 33 activerecord/lib/active_record/connection_adapters/abstract/connection_pool.rb
…
83% 42 activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb
86% 23 activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb
… (output trimmed)
```

Low percentages are the gap signal, and the lowest entries here are guides
and Gemfiles — files that shouldn't have test co-changes. The hot adapter
files land at 62–86%, i.e. most commits touching them also touch tests. No
real gap; the heuristic's noise floor is exactly what `explain` warns about.

## 3. Drill down on the strongest signal

```text
$ git-recon coupling activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb
18 activerecord/test/cases/adapters/postgresql/postgresql_adapter_test.rb
16 activerecord/CHANGELOG.md
12 activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb
 9 activerecord/lib/active_record/connection_adapters/abstract_mysql_adapter.rb
 9 activerecord/lib/active_record/connection_adapters/abstract/database_statements.rb
 9 activerecord/lib/active_record/connection_adapters/postgresql/schema_statements.rb
 8 activerecord/lib/active_record/connection_adapters/sqlite3_adapter.rb
… (output trimmed)
```

Confirms the pair-level view: this file's change partners are its test, its
changelog, and the other adapters. A patch here is rarely a one-file patch.

```text
$ git-recon owners activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb
   126	Aaron Patterson
    90	Ryuta Kamizono
    67	Jeremy Kemper
    49	Matthew Draper
… (output trimmed)
```

All-time counts differ from the recent picture: the historical owners are
Aaron Patterson and Ryuta Kamizono, but `silos` showed the last year belongs
to Matthew Draper. For "why is it like this" ask history; for "what's
changing now" ask Draper.

```text
$ git-recon hotspot activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb
commit c162370c8f92ac081d2a9ab2265cfb282b9dca3f
Author: Adrianna Chang <adrianna.chang@shopify.com>
Date:   Wed Jun 24 12:29:56 2026 -0400

    Report PostgreSQL default timestamp/time precision as 6

    PostgreSQL omits the typmod for bare timestamp/time columns, but those
    types still behave with microsecond precision by default. Reflect that
    effective precision in Active Record metadata so type casting normalizes
    timestamps consistently with persisted database values.

 .../lib/active_record/connection_adapters/postgresql_adapter.rb  | 9 +++++++++
 1 file changed, 9 insertions(+)

commit 4bb6e610c63e4c1334591d815a0c8d26dea275f3
Author: Matthew Draper <matthew@trebex.net>
Date:   Sat Jun 6 00:11:34 2026 +0000

    Capture terminating PostgreSQL notices

    PostgreSQL can deliver a connection-terminating fatal error through the
    notice receiver rather than as a query result. Keep a snapshot of that
    typed PG error and mark the connection for replacement so clean
    connections reconnect before reuse.

    If the connection can't be safely replaced first, raise the captured
    error before querying a socket we already know is dead, preserving its
    SQLSTATE and exception class instead of tripping over a generic socket
    failure.

 .../connection_adapters/postgresql_adapter.rb      | 54 +++++++++++++++++++++-
 1 file changed, 52 insertions(+), 2 deletions(-)
… (output trimmed)
```

The recent history is careful behavioral hardening — connection-failure and
reconnection work in three of the four latest commits, type-precision edge
cases in the newest. The file is hot because it's absorbing real-world edge
cases, not because it's being rewritten.

```text
$ git-recon blame -L 400,408 activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb
dc4420c5645 (Matthew Draper         2022-03-01 400)         @type_map = nil
a63f380bbaf (Matthew Draper         2026-03-06 401)         @type_map_queried = false
d917896f45a (Jean Boussier          2022-10-04 402)         @raw_connection = nil
56c56853245 (Adrianna Chang         2022-12-09 403)         @notice_receiver_sql_warnings = []
4bb6e610c63 (Matthew Draper         2026-06-06 404)         @notice_receiver_fatal_error = nil
36150c902b3 (Aaron Patterson        2010-07-14 405)
e54acf1308e (Rafael Mendonça França 2013-02-21 406)         @use_insert_returning = @config.key?(:insert_returning) ? self.class.type_cast_config_to_boolean(@config[:insert_returning]) : true
e8f664dde03 (Jeremy Kemper          2005-11-22 407)       end
e8f664dde03 (Jeremy Kemper          2005-11-22 408)
```

Lines from 2005 sit next to lines from last month: a long-lived file under
continuous repair. Each line's author and date tells you which commit — and
whose PR discussion — explains it.

## What the ten minutes bought

Before reading a line of adapter code, the session established: the active
subsystem is Active Record's connection-adapter layer; changes there fan out
across all database adapters via the abstract/database_statements contract;
Matthew Draper has the current context while Patterson and Kamizono have the
historical context; recent work is connection-failure hardening; and the
repair heuristics are trustworthy here because commit discipline is good.
That's the reading order and the review roster, from history alone.
