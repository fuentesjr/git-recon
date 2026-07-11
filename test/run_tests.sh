#!/usr/bin/env bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GIT_RECON="${SCRIPT_DIR}/../bin/git-recon"
FIXTURE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/git-recon-tests.XXXXXX")"
trap 'rm -rf "${FIXTURE_DIR}"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local output="$1"
  local pattern="$2"
  local description="$3"

  printf '%s\n' "${output}" | grep -E -- "${pattern}" >/dev/null \
    || fail "${description}"
}

commit_changes() {
  local date="$1"
  local author_name="$2"
  local author_email="$3"
  local message="$4"
  shift 4
  local path

  for path in "$@"; do
    mkdir -p "$(dirname "${path}")"
    printf 'change %s\n' "${message}" >> "${path}"
    git add -- "${path}"
  done
  GIT_AUTHOR_NAME="${author_name}" \
    GIT_AUTHOR_EMAIL="${author_email}" \
    GIT_AUTHOR_DATE="${date}" \
    GIT_COMMITTER_NAME="${author_name}" \
    GIT_COMMITTER_EMAIL="${author_email}" \
    GIT_COMMITTER_DATE="${date}" \
    git commit -q -m "${message}"
}

cd "${FIXTURE_DIR}"
git init -q
git config commit.gpgsign false
git config core.fsmonitor false

mkdir -p lib test
cat > lib/complex.rb <<'EOF'
class Complex
  def call
    if ready?
      work
    end
  end
end
EOF
printf 'release notes\n' > CHANGELOG.md
printf 'dependencies\n' > Gemfile.lock
printf 'pair a\n' > lib/pair_a.rb
printf 'pair b\n' > lib/pair_b.rb
printf 'orphan\n' > lib/orphan.rb
printf 'buggy\n' > lib/buggy.rb
printf 'untested\n' > lib/no_tests.rb
printf 'test\n' > test/complex_test.rb
git add .
GIT_AUTHOR_NAME='Alice Old' GIT_AUTHOR_EMAIL='alice@example.com' \
  GIT_AUTHOR_DATE='2025-06-01T12:00:00Z' \
  GIT_COMMITTER_NAME='Alice Old' GIT_COMMITTER_EMAIL='alice@example.com' \
  GIT_COMMITTER_DATE='2025-06-01T12:00:00Z' \
  git commit -q -m 'initial fixture'

commit_changes '2025-09-01T12:00:00Z' 'Alice Old' 'alice@example.com' \
  'fix paired bug one' lib/pair_a.rb lib/pair_b.rb lib/orphan.rb \
  lib/buggy.rb CHANGELOG.md
commit_changes '2025-09-08T12:00:00Z' 'Alice Old' 'alice@example.com' \
  'fix paired bug two' lib/pair_a.rb lib/pair_b.rb lib/orphan.rb \
  lib/buggy.rb Gemfile.lock
commit_changes '2025-09-15T12:00:00Z' 'Alice Old' 'alice@example.com' \
  'fix paired bug three' lib/pair_a.rb lib/pair_b.rb lib/orphan.rb \
  lib/buggy.rb CHANGELOG.md
commit_changes '2025-10-01T12:00:00Z' 'Alice Old' 'alice@example.com' \
  'fix paired bug four' lib/pair_a.rb lib/pair_b.rb lib/orphan.rb \
  lib/buggy.rb Gemfile.lock
commit_changes '2025-10-15T12:00:00Z' 'Alice Old' 'alice@example.com' \
  'paired feature five' lib/pair_a.rb lib/pair_b.rb lib/orphan.rb \
  lib/buggy.rb CHANGELOG.md
commit_changes '2025-11-01T12:00:00Z' 'Alice Old' 'alice@example.com' \
  'paired feature six' lib/pair_a.rb lib/pair_b.rb lib/orphan.rb Gemfile.lock

commit_changes '2026-03-01T12:00:00Z' 'Bob Active' 'bob@example.com' \
  'complex work one' lib/complex.rb lib/no_tests.rb CHANGELOG.md
commit_changes '2026-03-10T12:00:00Z' 'Bob Active' 'bob@example.com' \
  'complex work two' lib/complex.rb lib/no_tests.rb Gemfile.lock
commit_changes '2026-04-01T12:00:00Z' 'Bob Active' 'bob@example.com' \
  'complex work with tests' lib/complex.rb test/complex_test.rb CHANGELOG.md
commit_changes '2026-04-10T12:00:00Z' 'Bob Active' 'bob@example.com' \
  'complex work four' lib/complex.rb lib/no_tests.rb Gemfile.lock
commit_changes '2026-05-01T12:00:00Z' 'Bob Active' 'bob@example.com' \
  'complex work five' lib/complex.rb lib/no_tests.rb CHANGELOG.md
commit_changes '2026-05-10T12:00:00Z' 'Bob Active' 'bob@example.com' \
  'complex work with more tests' lib/complex.rb test/complex_test.rb \
  Gemfile.lock
commit_changes '2026-06-01T12:00:00Z' 'Bob Active' 'bob@example.com' \
  'complex work seven' lib/complex.rb lib/no_tests.rb CHANGELOG.md
commit_changes '2026-06-10T12:00:00Z' 'Bob Active' 'bob@example.com' \
  'complex work eight' lib/complex.rb lib/orphan.rb Gemfile.lock

sweep_files=(lib/pair_a.rb lib/pair_b.rb)
for index in {1..31}; do
  sweep_files+=("sweep/file_${index}.txt")
done
commit_changes '2026-06-20T12:00:00Z' 'Bob Active' 'bob@example.com' \
  'formatting sweep' "${sweep_files[@]}"

output="$("${GIT_RECON}" churn)"
assert_contains "${output}" '^[[:space:]]*8[[:space:]]+lib/complex\.rb$' \
  'existing churn command should count complex.rb changes'

output="$("${GIT_RECON}" coupling)"
assert_contains "${output}" \
  '^[[:space:]]*6[[:space:]]+lib/pair_a\.rb -- lib/pair_b\.rb$' \
  'coupling should report the strong pair and skip the 33-file sweep'

output="$("${GIT_RECON}" coupling lib/pair_a.rb)"
assert_contains "${output}" '^[[:space:]]*6[[:space:]]+lib/pair_b\.rb$' \
  'path coupling should report the paired file'

output="$("${GIT_RECON}" risk)"
assert_contains "${output}" '^score churn complexity file$' \
  'risk should print its column header'
first_risk_file="$(printf '%s\n' "${output}" | sed -n '2s/.* //p')"
[[ "${first_risk_file}" == 'lib/complex.rb' ]] \
  || fail 'risk should rank complex logic first'

output="$("${GIT_RECON}" silos)"
assert_contains "${output}" '^8[0-9]% INACTIVE Alice Old lib/orphan\.rb$' \
  'silos should expose the inactive majority owner'

output="$("${GIT_RECON}" fix-rate)"
assert_contains "${output}" '^80% 4/5 lib/buggy\.rb$' \
  'fix-rate should report four fixes in five follow-up commits'

output="$("${GIT_RECON}" test-gap)"
assert_contains "${output}" '^0% 5 lib/no_tests\.rb$' \
  'test-gap should report logic with no test co-change'
assert_contains "${output}" '^25% 8 lib/complex\.rb$' \
  'test-gap should report two test co-changes in eight commits'

output="$("${GIT_RECON}" deep)"
assert_contains "${output}" '^== coupling \(last year, top 20 pairs\) ==$' \
  'deep should include coupling with its cap'
assert_contains "${output}" \
  '^== test-gap \(last year, top 20 churn files\) ==$' \
  'deep should include test-gap with its cap'

printf 'PASS: git-recon fixture tests\n'
