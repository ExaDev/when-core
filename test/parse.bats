#!/usr/bin/env bats

load "../node_modules/bats-support/load"
load "../node_modules/bats-assert/load"

setup() {
  export GITHUB_OUTPUT="$BATS_TEST_TMPDIR/output"
  : >"$GITHUB_OUTPUT"
  export CONDITIONS=$'label:\ncheck:\nnot-draft\nthreads-resolved'
  export EFFECTS=$'merge\nready'
  export THEN=merge
  export WHEN=$'label: automerge\ncheck: Required Checks\nnot-draft'
}

run_parse() { run "$BATS_TEST_DIRNAME/../parse.sh"; }

# Prints the named multiline output written to GITHUB_OUTPUT, without its delimiters.
output_of() {
  awk -v name="$1" '
    index($0, name "<<") == 1 { delimiter = substr($0, length(name) + 3); inside = 1; next }
    inside && $0 == delimiter { exit }
    inside { print }
    index($0, name "=") == 1 { print substr($0, length(name) + 2) }
  ' "$GITHUB_OUTPUT"
}

nothing_written() { [ ! -s "$GITHUB_OUTPUT" ]; }

@test "valid conditions are written one per line" {
  run_parse
  assert_success
  run output_of conditions
  assert_output $'label: automerge\ncheck: Required Checks\nnot-draft'
}

@test "the effect is written as given" {
  THEN=ready run_parse
  assert_success
  run output_of then
  assert_output ready
}

@test "blank lines, comments and surrounding space are stripped" {
  WHEN=$'# opt in\n\n   label:   automerge  \n\t# indented comment\n  not-draft\t\n' THEN=$'  merge \n' run_parse
  assert_success
  run output_of conditions
  assert_output $'label: automerge\nnot-draft'
  run output_of then
  assert_output merge
}

@test "a missing space after the colon is normalised" {
  WHEN='check:Required Checks' run_parse
  assert_success
  run output_of conditions
  assert_output 'check: Required Checks'
}

@test "a value keeps its inner spacing and any further colons" {
  WHEN='check: build: linux  x64' run_parse
  assert_success
  run output_of conditions
  assert_output 'check: build: linux  x64'
}

@test "the vocabulary may carry comments and blank lines too" {
  CONDITIONS=$'# with a value\nlabel:\n\n# without\nnot-draft' EFFECTS=$'\nmerge\n# later\nready' WHEN=$'label: a\nnot-draft' run_parse
  assert_success
}

@test "an unknown condition is rejected" {
  WHEN=$'label: automerge\nlabels: automerge' run_parse
  assert_failure
  assert_output --partial 'Unknown condition: "labels: automerge"'
  nothing_written
}

@test "an unknown bare condition is rejected" {
  WHEN='not-a-draft' run_parse
  assert_failure
  assert_output --partial 'Unknown condition: "not-a-draft"'
  nothing_written
}

@test "a condition that needs a value is rejected without one" {
  WHEN='label:' run_parse
  assert_failure
  assert_output --partial 'Condition "label" needs a value'
  nothing_written
}

@test "a condition that needs a value is rejected written bare" {
  WHEN='label' run_parse
  assert_failure
  assert_output --partial 'Condition "label" needs a value'
  nothing_written
}

@test "a condition that takes no value is rejected with one" {
  WHEN='not-draft: yes' run_parse
  assert_failure
  assert_output --partial 'Condition "not-draft" takes no value'
  nothing_written
}

@test "a condition that takes no value is rejected with an empty one" {
  WHEN='not-draft:' run_parse
  assert_failure
  assert_output --partial 'Condition "not-draft" takes no value'
  nothing_written
}

@test "a line with nothing before its colon is rejected" {
  WHEN=': automerge' run_parse
  assert_failure
  assert_output --partial 'Malformed condition'
  nothing_written
}

@test "an empty when is rejected" {
  WHEN=$'# nothing\n\n' run_parse
  assert_failure
  assert_output --partial "when has no conditions"
  nothing_written
}

@test "an unknown effect is rejected" {
  THEN=close run_parse
  assert_failure
  assert_output --partial 'Unknown effect: "close"'
  nothing_written
}

@test "an empty then is rejected" {
  THEN=' ' run_parse
  assert_failure
  assert_output --partial "then names no effect"
  nothing_written
}

@test "more than one effect is rejected" {
  THEN=$'merge\nready' run_parse
  assert_failure
  assert_output --partial "then takes one effect"
  nothing_written
}

@test "an empty condition vocabulary is rejected" {
  CONDITIONS='# none' run_parse
  assert_failure
  assert_output --partial "declares no conditions"
  nothing_written
}

@test "an empty effect vocabulary is rejected" {
  EFFECTS='' run_parse
  assert_failure
  assert_output --partial "declares no effects"
  nothing_written
}

@test "a malformed condition declaration is rejected" {
  CONDITIONS=$'label:\ncheck: name' run_parse
  assert_failure
  assert_output --partial 'malformed condition name: "check: name"'
  nothing_written
}

@test "a malformed effect declaration is rejected" {
  EFFECTS=$'merge\nre ady' run_parse
  assert_failure
  assert_output --partial 'malformed effect name: "re ady"'
  nothing_written
}
