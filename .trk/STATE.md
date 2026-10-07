# STATE

## Goal

## Dispatched

## Next

## Backlog
- facts-side-branch-test — No fixture proves facts coupling still counts a merged side-branch commit that default history simplification prunes; --full-history keeps it by reasoning only. Add a fixture test. (2026-10-07T15:40Z)
- human-coupling-bookkeeping — Plain-text coupling and deep still list changelogs and lockfiles; facts and churn/bug-files hide them. Hiding them changes human report output and docs/examples.md coupling blocks; needs its own change. (2026-10-07T15:40Z)
- untouched-test-hint — Parked narrow diff idea: warn when a name-mapped test was not touched. Rails backtest: 17 of 26 such alarms were false (change tested in another file). Needs a PR-level backtest before building. (2026-10-07T15:40Z)
- facts-trailing-slash — facts -- bin/ returns coupled:[] while facts -- bin returns 5 rows: "${path}/"* becomes bin//*. Strip a trailing slash from PATH; add a test. (2026-10-07T15:50Z)
- churn-dirs-root-files — churn-dirs lists root files (README.md) as directories: sed 's,/[^/]*$,,' leaves slashless paths unchanged. Map them to '.'; add a test. (2026-10-07T15:50Z)
