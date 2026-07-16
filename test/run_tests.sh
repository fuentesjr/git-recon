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

assert_facts_error() {
  local working_dir="$1"
  local code="$2"
  local message="$3"
  shift 3

  set +e
  (cd "${working_dir}" && "$@") \
    >"${FIXTURE_DIR}/facts-out" 2>"${FIXTURE_DIR}/facts-err"
  local facts_status="$?"
  set -e
  local output
  local error_output
  output="$(cat "${FIXTURE_DIR}/facts-out")"
  error_output="$(cat "${FIXTURE_DIR}/facts-err")"
  local expected
  expected='{"v":1,"error":{"code":"'"${code}"'","message":"'
  expected="${expected}${message}\"}}"
  [[ "${facts_status}" -ne 0 && "${output}" == "${expected}" \
    && -z "${error_output}" ]] \
    || fail "facts should report ${code} as compact JSON on stdout"
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
assert_contains "${output}" \
  '^\(top 30 of 40 files = 88% of 86 changes in last year\)$' \
  'churn should append a coverage-share footer'

output="$("${GIT_RECON}" churn-dirs)"
assert_contains "${output}" \
  '^\(top 5 of 5 dirs = 100% of 86 changes in last year\)$' \
  'churn-dirs should append a coverage-share footer'

output="$("${GIT_RECON}" vitals)"
assert_contains "${output}" \
  '^commits: 16 all-time \(first 2025-06-01\), 15 in last year$' \
  'vitals should report commit counts and repo age'
assert_contains "${output}" '^files: 40 touched in last year, 40 tracked$' \
  'vitals should report touched vs tracked file counts'
assert_contains "${output}" \
  '^authors: 1 active in last 6 months of 2 all-time; top: Bob Active \(100% of recent commits\)$' \
  'vitals should report author concentration'

output="$("${GIT_RECON}" overview)"
assert_contains "${output}" '^== vitals ==$' \
  'overview should lead with the vitals section'

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

unicode_message='Répare café "JSON" \ chemin'
commit_changes '2026-06-25T12:00:00Z' 'Bob Active' 'bob@example.com' \
  "${unicode_message}" 'lib/café.rb'
unicode_sha="$(git rev-parse HEAD)"
unicode_epoch="$(git show -s --format=%ct HEAD)"
unicode_commit="[\"${unicode_sha}\",${unicode_epoch},"
unicode_commit="${unicode_commit}\"Répare café \\\"JSON\\\" \\\\ chemin\"]"
if ! output="$("${GIT_RECON}" facts --format=json -- 'lib/café.rb')"; then
  fail 'facts should accept valid UTF-8 paths'
fi
[[ "${output}" == *'"path":"lib/café.rb"'*"${unicode_commit}"* ]] \
  || fail 'facts should preserve valid UTF-8 paths and subjects'

mkdir "${FIXTURE_DIR}/not-a-repo"
assert_facts_error "${FIXTURE_DIR}/not-a-repo" not_repository \
  'not a git repository' env GIT_CEILING_DIRECTORIES="${FIXTURE_DIR}" \
  "${GIT_RECON}" facts --format=json -- lib/example.rb
git clone -q --depth 1 "file://${FIXTURE_DIR}" "${FIXTURE_DIR}/shallow"
assert_facts_error "${FIXTURE_DIR}/shallow" shallow_repository \
  'complete history is required' "${GIT_RECON}" facts --format=json \
  -- lib/complex.rb
assert_facts_error "${FIXTURE_DIR}" invalid_revision \
  'revision is not a commit' "${GIT_RECON}" facts --format=json \
  --at missing -- lib/complex.rb
assert_facts_error "${FIXTURE_DIR}" invalid_path \
  'path does not exist at revision' "${GIT_RECON}" facts --format=json \
  -- missing.rb
assert_facts_error "${FIXTURE_DIR}" invalid_range \
  'line range exceeds file bounds' "${GIT_RECON}" facts --format=json \
  -L 1,999 -- lib/complex.rb
assert_facts_error "${FIXTURE_DIR}" unsupported_format \
  'only --format=json is supported' "${GIT_RECON}" facts --format=yaml \
  -- lib/complex.rb
assert_facts_error "${FIXTURE_DIR}" invalid_arguments \
  'invalid facts arguments' "${GIT_RECON}" facts --format=json --at
bad_path=$'lib/\377.rb'
assert_facts_error "${FIXTURE_DIR}" unsupported_path_encoding \
  'path must be valid UTF-8 without control bytes' "${GIT_RECON}" facts \
  --format=json -- "${bad_path}"

facts_at="$(git rev-parse HEAD)"
facts_epoch="$(git show -s --format=%ct HEAD)"
facts_since="$((facts_epoch - 31536000))"
expected='{"v":1,"at":"'"${facts_at}"'",'
expected="${expected}\"path\":\"lib/complex.rb\","
expected="${expected}\"since\":${facts_since},\"commits\":["
output="$("${GIT_RECON}" facts --format=json -- lib/complex.rb)"
[[ "${output}" == "${expected}"* ]] \
  || fail \
  'facts should expose the compact v1 JSON protocol'

origin_sha="$(git rev-list --max-parents=0 HEAD)"
origin_epoch="$(git show -s --format=%ct "${origin_sha}")"
origin_commit="[\"${origin_sha}\",${origin_epoch},\"initial fixture\"]"
output="$("${GIT_RECON}" facts --format=json -L 1,2 -- lib/complex.rb)"
origin_index="$(printf '%s\n' "${output}" \
  | sed -e 's/^.*"commits":\[\[//' -e 's/\]\],"recent".*$//' \
    -e 's/\],\[/\
/g' \
  | awk -F, -v sha="\"${origin_sha}\"" '$1 == sha { print NR - 1; exit }')"
[[ -n "${origin_index}" \
  && "${output}" == *"${origin_commit}"* \
  && "${output}" == *'"origins":[['"${origin_index}"',1,2]]}' ]] \
  || fail 'facts should add compact line provenance for a source range'
if ! output="$(cd "${FIXTURE_DIR}/test" \
  && "${GIT_RECON}" facts --format=json -L 1,2 -- lib/complex.rb)"; then
  fail 'facts should resolve a repo-root blame path from a subdirectory'
fi
[[ "${output}" == *'"path":"lib/complex.rb"'* \
  && "${output}" == *'"origins":[['* ]] \
  || fail 'subdirectory facts should retain compact line provenance'

# Fact ranks use committer epoch descending, then full SHA ascending.
fact_messages=(
  'paired feature five'
  'fix paired bug four'
  'fix paired bug three'
  'fix paired bug two'
  'fix paired bug one'
)
expected_commits=''
for fact_message in "${fact_messages[@]}"; do
  fact_sha="$(git log -1 --format=%H --grep="^${fact_message}$")"
  fact_epoch="$(git show -s --format=%ct "${fact_sha}")"
  [[ -z "${expected_commits}" ]] \
    || expected_commits="${expected_commits},"
  expected_commits="${expected_commits}[\"${fact_sha}\",${fact_epoch},"
  expected_commits="${expected_commits}\"${fact_message}\"]"
done
expected='{"v":1,"at":"'"${facts_at}"'",'
expected="${expected}\"path\":\"lib/buggy.rb\","
expected="${expected}\"since\":${facts_since},"
expected="${expected}\"commits\":[${expected_commits}],"
expected="${expected}\"recent\":[0,1,2,3,4],"
expected_coupled='"coupled":[["lib/orphan.rb",5,[0,1,2,3,4]],'
expected_coupled="${expected_coupled}[\"lib/pair_a.rb\",5,[0,1,2,3,4]],"
expected_coupled="${expected_coupled}[\"lib/pair_b.rb\",5,[0,1,2,3,4]],"
expected_coupled="${expected_coupled}[\"CHANGELOG.md\",3,[0,2,4]],"
expected_coupled="${expected_coupled}[\"Gemfile.lock\",2,[1,3]]]"
expected="${expected}\"repairs\":[1,2,3,4],${expected_coupled},"
expected="${expected}\"origins\":[]}"
output="$("${GIT_RECON}" facts --format=json -- lib/buggy.rb)"
[[ "${output}" == "${expected}" ]] \
  || fail 'facts should rank recent and repair commits for the seed path'
[[ "${output}" == *"${expected_coupled}"* ]] \
  || fail \
  'facts should couple current paths to supporting commit indexes'

support_partners=(
  lib/orphan.rb lib/pair_a.rb lib/pair_b.rb CHANGELOG.md Gemfile.lock
)
support_indexes=('0 1 2 3 4' '0 1 2 3 4' '0 1 2 3 4' '0 2 4' '1 3')
for ((support_case = 0; support_case < ${#support_partners[@]};
  support_case++)); do
  partner="${support_partners[$support_case]}"
  read -r -a indexes <<< "${support_indexes[$support_case]}"
  for index in "${indexes[@]}"; do
    support_sha="$(git log -1 --format=%H \
      --grep="^${fact_messages[$index]}$")"
    changed="$(git diff-tree --root --no-commit-id --name-only -r \
      "${support_sha}")"
    if ! printf '%s\n' "${changed}" \
      | grep -Fx -- lib/buggy.rb >/dev/null \
      || ! printf '%s\n' "${changed}" \
      | grep -Fx -- "${partner}" >/dev/null; then
      fail 'coupled support indexes must resolve to real cochanges'
    fi
  done
done

cap_paths=(lib/cap_seed.rb)
for index in {1..6}; do
  cap_paths+=("lib/cap_${index}.rb")
done
for hour in {12..17}; do
  commit_changes "2026-06-26T${hour}:00:00Z" 'Bob Active' \
    'bob@example.com' "fix cap coupling ${hour}" "${cap_paths[@]}"
done
output="$("${GIT_RECON}" facts --format=json -- lib/cap_seed.rb)"
expected_capped='"coupled":[["lib/cap_1.rb",6,[0,1,2,3,4]],'
expected_capped="${expected_capped}[\"lib/cap_2.rb\",6,[0,1,2,3,4]],"
expected_capped="${expected_capped}[\"lib/cap_3.rb\",6,[0,1,2,3,4]],"
expected_capped="${expected_capped}[\"lib/cap_4.rb\",6,[0,1,2,3,4]],"
expected_capped="${expected_capped}[\"lib/cap_5.rb\",6,[0,1,2,3,4]]]"
[[ "${output}" == *"${expected_capped}"* \
  && "${output}" != *'"lib/cap_6.rb"'* ]] \
  || fail 'facts should cap coupled paths and supporting indexes at five'
[[ "${output}" == *'"recent":[0,1,2,3,4],'* \
  && "${output}" == *'"repairs":[0,1,2,3,4],'* ]] \
  || fail 'facts should cap recent and repair indexes at five'

commit_changes '2026-07-10T12:00:00Z' 'Bob Active' 'bob@example.com' \
  'fix future-skewed history' lib/skewed.rb lib/future_partner.rb
future_skewed_sha="$(git rev-parse HEAD)"
commit_changes '2026-07-01T12:00:00Z' 'Bob Active' 'bob@example.com' \
  'skewed cutoff' lib/skewed.rb
skewed_cutoff_sha="$(git rev-parse HEAD)"
output="$("${GIT_RECON}" facts --format=json --at "${skewed_cutoff_sha}" \
  -- lib/skewed.rb)"
[[ "${output}" == *'"at":"'"${skewed_cutoff_sha}"'"'* \
  && "${output}" != *"${future_skewed_sha}"* \
  && "${output}" != *'lib/future_partner.rb'* ]] \
  || fail 'facts should resolve historical --at without future context'

commit_changes '2026-07-02T12:00:00Z' 'Bob Active' 'bob@example.com' \
  'literal wildcard path' 'lib/star*.rb'
literal_path_sha="$(git rev-parse HEAD)"
commit_changes '2026-07-03T12:00:00Z' 'Bob Active' 'bob@example.com' \
  'fix unrelated wildcard match' lib/star-other.rb
unrelated_path_sha="$(git rev-parse HEAD)"
output="$("${GIT_RECON}" facts --format=json -L 1,1 -- 'lib/star*.rb')"
[[ "${output}" == *"${literal_path_sha}"* \
  && "${output}" != *"[\"${unrelated_path_sha}\""* ]] \
  || fail 'facts should treat metacharacters as a literal path'
output="$("${GIT_RECON}" facts --format=json -- lib)"
[[ "${output}" == *'"path":"lib"'*"[\"${unrelated_path_sha}\""* ]] \
  || fail 'facts should preserve recursive directory history'

marker_partner=$'COMMIT\t0000000000000000000000000000000000000000'
commit_changes '2026-07-03T13:00:00Z' 'Bob Active' 'bob@example.com' \
  'marker-shaped partner path' AAA_marker_seed.rb "${marker_partner}"
if ! output="$("${GIT_RECON}" facts --format=json -- AAA_marker_seed.rb)"; then
  fail 'facts should not parse a marker-shaped path as a commit boundary'
fi
[[ "${output}" == *'"path":"AAA_marker_seed.rb"'* \
  && "${output}" == *'"coupled":[]'* ]] \
  || fail 'facts should omit a control-byte partner path'

control_message=$'fix control\001subject\177here'
commit_changes '2026-07-04T12:00:00Z' 'Bob Active' 'bob@example.com' \
  "${control_message}" lib/control.rb
output="$("${GIT_RECON}" facts --format=json -- lib/control.rb)"
[[ "${output}" == *'"fix control subject here"'* ]] \
  || fail 'facts should normalize subject control bytes'

tie_date='2026-07-05T12:00:00Z'
commit_changes "${tie_date}" 'Bob Active' 'bob@example.com' \
  'fix tied rank one' lib/tied_rank.rb
tie_one_sha="$(git rev-parse HEAD)"
commit_changes "${tie_date}" 'Bob Active' 'bob@example.com' \
  'fix tied rank two' lib/tied_rank.rb
tie_two_sha="$(git rev-parse HEAD)"
tie_epoch="$(git show -s --format=%ct HEAD)"
tie_first_sha="$(printf '%s\n%s\n' "${tie_one_sha}" "${tie_two_sha}" \
  | LC_ALL=C sort | sed -n '1p')"
tie_second_sha="$(printf '%s\n%s\n' "${tie_one_sha}" "${tie_two_sha}" \
  | LC_ALL=C sort | sed -n '2p')"
if [[ "${tie_first_sha}" == "${tie_one_sha}" ]]; then
  tie_first_message='fix tied rank one'
  tie_second_message='fix tied rank two'
else
  tie_first_message='fix tied rank two'
  tie_second_message='fix tied rank one'
fi
expected_ties='"commits":[["'"${tie_first_sha}"'",'"${tie_epoch}"','
expected_ties="${expected_ties}\"${tie_first_message}\"],[\""
expected_ties="${expected_ties}${tie_second_sha}\",${tie_epoch},\""
expected_ties="${expected_ties}${tie_second_message}\"]]"
output="$("${GIT_RECON}" facts --format=json -- lib/tied_rank.rb)"
[[ "${output}" == *"${expected_ties}"* \
  && "${output}" == *'"recent":[0,1],"repairs":[0,1]'* ]] \
  || fail 'facts should break equal-epoch rank ties by full OID ascending'

long_message='fix x'
for index in {1..100}; do
  long_message="${long_message}é"
done
expected_long_subject='fix x'
for index in {1..77}; do
  expected_long_subject="${expected_long_subject}é"
done
[[ "$(printf '%s' "${expected_long_subject}" \
  | LC_ALL=C wc -c | tr -d ' ')" -eq 159 ]] \
  || fail 'long-subject fixture should end before a split codepoint'
commit_changes '2026-07-06T12:00:00Z' 'Bob Active' 'bob@example.com' \
  "${long_message}" lib/long_subject.rb
long_sha="$(git rev-parse HEAD)"
long_epoch="$(git show -s --format=%ct HEAD)"
long_since="$((long_epoch - 31536000))"
expected='{"v":1,"at":"'"${long_sha}"'",'
expected="${expected}\"path\":\"lib/long_subject.rb\","
expected="${expected}\"since\":${long_since},\"commits\":[[\""
expected="${expected}${long_sha}\",${long_epoch},\""
expected="${expected}${expected_long_subject}\"]],"
expected="${expected}\"recent\":[0],\"repairs\":[0],"
expected="${expected}\"coupled\":[],\"origins\":[]}"
if ! "${GIT_RECON}" facts --format=json -- lib/long_subject.rb \
  >"${FIXTURE_DIR}/facts-out" 2>"${FIXTURE_DIR}/facts-err"; then
  fail 'facts should accept a subject crossing the byte cap'
fi
output="$(cat "${FIXTURE_DIR}/facts-out")"
[[ "${output}" == "${expected}" \
  && ! -s "${FIXTURE_DIR}/facts-err" ]] \
  || fail 'facts should cap subjects without splitting UTF-8 codepoints'

replay_c="$(env LC_ALL=C TZ=UTC "${GIT_RECON}" facts --format=json \
  -- lib/long_subject.rb)"
replay_again="$(env LC_ALL=C TZ=UTC "${GIT_RECON}" facts --format=json \
  -- lib/long_subject.rb)"
replay_tz="$(env LC_ALL=C TZ=America/Los_Angeles "${GIT_RECON}" facts \
  --format=json -- lib/long_subject.rb)"
[[ "${replay_c}" == "${replay_again}" \
  && "${replay_c}" == "${replay_tz}" ]] \
  || fail 'facts should be byte-identical across replay and time zones'
utf8_locale=''
available_locales="$(locale -a 2>/dev/null || true)"
for candidate in C.UTF-8 C.utf8 en_US.UTF-8 en_US.utf8; do
  if printf '%s\n' "${available_locales}" \
    | grep -Fxi -- "${candidate}" >/dev/null; then
    utf8_locale="${candidate}"
    break
  fi
done
if [[ -n "${utf8_locale}" ]]; then
  replay_utf8="$(env LC_ALL="${utf8_locale}" TZ=UTC "${GIT_RECON}" facts \
    --format=json -- lib/long_subject.rb)"
  [[ "${replay_c}" == "${replay_utf8}" ]] \
    || fail 'facts should be byte-identical across available locales'
fi

# Fill each facts segment to prove the normalized commit-table ceiling.
max_origin_shas=()
for day in {1..6}; do
  commit_changes "2025-06-0${day}T12:00:00Z" 'Bob Active' \
    'bob@example.com' "max packet origin ${day}" lib/max_packet.rb
  max_origin_shas+=("$(git rev-parse HEAD)")
done
max_partner_shas=()
for hour in {1..5}; do
  commit_changes "2026-07-07T0${hour}:00:00Z" 'Bob Active' \
    'bob@example.com' "max packet context ${hour}" lib/max_packet.rb \
    "lib/max_partner_${hour}.rb"
  max_partner_shas+=("$(git rev-parse HEAD)")
done
max_repair_shas=()
for hour in {1..5}; do
  commit_changes "2026-07-08T0${hour}:00:00Z" 'Bob Active' \
    'bob@example.com' "fix max packet ${hour}" lib/max_packet.rb
  max_repair_shas+=("$(git rev-parse HEAD)")
done
max_recent_shas=()
for hour in {1..5}; do
  commit_changes "2026-07-09T0${hour}:00:00Z" 'Bob Active' \
    'bob@example.com' "max packet recent ${hour}" lib/max_packet.rb
  max_recent_shas+=("$(git rev-parse HEAD)")
done
output="$("${GIT_RECON}" facts --format=json -L 1,6 \
  -- lib/max_packet.rb)"
[[ "${output}" == *'"recent":[0,1,2,3,4],'* \
  && "${output}" == *'"repairs":[5,6,7,8,9],'* ]] \
  || fail 'facts should keep ten distinct recent and repair base commits'
expected_max_coupled='"coupled":[["lib/max_partner_1.rb",1,[10]],'
expected_max_coupled="${expected_max_coupled}[\"lib/max_partner_2.rb\",1,[11]],"
expected_max_coupled="${expected_max_coupled}[\"lib/max_partner_3.rb\",1,[12]],"
expected_max_coupled="${expected_max_coupled}[\"lib/max_partner_4.rb\",1,[13]],"
expected_max_coupled="${expected_max_coupled}[\"lib/max_partner_5.rb\",1,[14]]]"
expected_max_origins='"origins":[[15,1,1],[16,2,2],[17,3,3],'
expected_max_origins="${expected_max_origins}[18,4,4],[19,5,5]]}"
[[ "${output}" == *"${expected_max_coupled}"* \
  && "${output}" == *"${expected_max_origins}"* \
  && "${output}" != *"${max_origin_shas[5]}"* ]] \
  || fail 'facts should cap fallback coupling and origin additions at five'
max_commit_rows="$(printf '%s\n' "${output}" \
  | sed -e 's/^.*"commits":\[\[//' -e 's/\]\],"recent".*$//' \
    -e 's/\],\[/\
/g')"
max_commit_count="$(printf '%s\n' "${max_commit_rows}" \
  | awk 'NF { count++ } END { print count + 0 }')"
[[ "${max_commit_count}" -eq 20 ]] \
  || fail 'facts should cap the normalized commit table at twenty rows'
for index in {0..4}; do
  row="$(printf '%s\n' "${max_commit_rows}" \
    | sed -n "$((index + 11))p")"
  [[ "${row}" == \""${max_partner_shas[$index]}"\",* ]] \
    || fail 'coupled fallback indexes should resolve to support commits'
  row="$(printf '%s\n' "${max_commit_rows}" \
    | sed -n "$((index + 16))p")"
  [[ "${row}" == \""${max_origin_shas[$index]}"\",* ]] \
    || fail 'origin indexes should resolve in source-line order'
done

mkdir "${FIXTURE_DIR}/git-wrapper"
cat > "${FIXTURE_DIR}/git-wrapper/git" <<'EOF'
#!/bin/sh
if [ "$1" = show ] && [ "${GIT_RECON_FAIL_BLOB_SHOW:-}" = 1 ]; then
  case "$2" in
    *:*) exit 42 ;;
  esac
fi
if [ "$1" = log ]; then
  if [ "${GIT_RECON_HANG_LOG:-}" = 1 ]; then
    : > "$GIT_RECON_LOG_STARTED"
    sleep 1
  fi
  exit 42
fi
exec "$GIT_RECON_REAL_GIT" "$@"
EOF
chmod +x "${FIXTURE_DIR}/git-wrapper/git"
mkdir "${FIXTURE_DIR}/blob-failure-tmp"
assert_facts_error "${FIXTURE_DIR}" git_failure 'git query failed' env \
  GIT_RECON_REAL_GIT="$(command -v git)" GIT_RECON_FAIL_BLOB_SHOW=1 \
  TMPDIR="${FIXTURE_DIR}/blob-failure-tmp" \
  PATH="${FIXTURE_DIR}/git-wrapper:${PATH}" \
  "${GIT_RECON}" facts --format=json -L 1,1 -- lib/complex.rb
[[ -z "$(find "${FIXTURE_DIR}/blob-failure-tmp" -type d \
  -name 'git-recon-facts.*' -print -quit)" ]] \
  || fail 'facts should clean temporary files after a blob-show failure'
assert_facts_error "${FIXTURE_DIR}" git_failure 'git query failed' env \
  GIT_RECON_REAL_GIT="$(command -v git)" \
  PATH="${FIXTURE_DIR}/git-wrapper:${PATH}" \
  "${GIT_RECON}" facts --format=json -- lib/complex.rb
mkdir "${FIXTURE_DIR}/facts-tmp"
started="${FIXTURE_DIR}/git-log-started"
env GIT_RECON_REAL_GIT="$(command -v git)" GIT_RECON_HANG_LOG=1 \
  GIT_RECON_LOG_STARTED="${started}" TMPDIR="${FIXTURE_DIR}/facts-tmp" \
  PATH="${FIXTURE_DIR}/git-wrapper:${PATH}" \
  "${GIT_RECON}" facts --format=json -- lib/complex.rb >/dev/null &
facts_pid=$!
for index in {1..50}; do
  [[ ! -e "${started}" ]] || break
  sleep 0.02
done
kill -TERM "${facts_pid}"
set +e
wait "${facts_pid}"
set -e
[[ -z "$(find "${FIXTURE_DIR}/facts-tmp" -type d \
  -name 'git-recon-facts.*' -print -quit)" ]] \
  || fail 'facts should clean temporary files when interrupted'

printf 'PASS: git-recon fixture tests\n'
