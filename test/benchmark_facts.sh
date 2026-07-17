#!/usr/bin/env bash
# Wall-clock thresholds depend on an external checkout and machine load, so
# this representative benchmark is opt-in rather than part of run_tests.sh.
set -eu

if [[ $# -ne 6 ]]; then
  printf '%s\n' \
    'usage: benchmark_facts.sh GIT_RECON REPO REV PATH EXPECTED MAX_SECONDS' \
    >&2
  exit 2
fi

git_recon="$1"
repo="$2"
revision="$3"
path="$4"
expected="$5"
max_seconds="$6"
temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/git-recon-benchmark.XXXXXX")"
actual="${temp_dir}/actual.json"
timing="${temp_dir}/timing"

cleanup() {
  rm -rf "$temp_dir"
}
trap cleanup EXIT

if ! (
  cd "$repo"
  TIMEFORMAT='%R'
  { time "$git_recon" facts --format=json --at "$revision" -- "$path" \
      > "$actual"; } 2> "$timing"
); then
  cat "$timing" >&2
  exit 1
fi

elapsed="$(tr -d '[:space:]' < "$timing")"
cmp -s "$expected" "$actual" || {
  printf 'facts output differs from %s\n' "$expected" >&2
  exit 1
}
awk -v elapsed="$elapsed" -v maximum="$max_seconds" \
  'BEGIN { exit !(elapsed <= maximum) }' || {
    printf 'facts took %ss; maximum is %ss\n' "$elapsed" "$max_seconds" >&2
    exit 1
  }

printf 'PASS: facts %ss <= %ss; output byte-identical\n' \
  "$elapsed" "$max_seconds"
