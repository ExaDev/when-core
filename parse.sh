#!/usr/bin/env bash
# Checks a when action's condition lines and effect against the vocabulary its engine declares, and writes them out normalised, so an engine acts only on input it understands.
#
# Inputs (environment): WHEN        the condition lines, one per line; blank lines and lines starting with # are ignored CONDITIONS  the condition names the engine knows, one per line; a name ending in ":" takes a value (label:), any other takes none (not-draft) THEN        the one effect to apply once every condition holds EFFECTS     the effect names the engine knows, one per line GITHUB_OUTPUT  the file the step outputs are appended to
#
# Outputs: conditions  one condition per line, as "name" or "name: value" with surrounding space removed then        the effect, with surrounding space removed
#
# Exits 1 on an unknown condition or effect, a condition line whose value doesn't match its declaration, or an empty list, writing nothing.
set -euo pipefail

: "${GITHUB_OUTPUT:?GITHUB_OUTPUT is required}"

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  printf '%s' "${s%"${s##*[![:space:]]}"}"
}

# Prints the meaningful lines of $1, trimmed, skipping blank lines and # comments.
lines() {
  local line
  while IFS= read -r line || [ -n "$line" ]; do
    line=$(trim "$line")
    case "$line" in
      "" | "#"*) ;;
      *) printf '%s\n' "$line" ;;
    esac
  done <<<"$1"
}

fail() {
  echo "$1" >&2
  exit 1
}

valued=()
bare=()
while IFS= read -r name; do
  case "$name" in
    *[[:space:]]* | :* | *:?*) fail "The engine declares a malformed condition name: \"$name\"." ;;
    *:) valued+=("${name%:}") ;;
    *) bare+=("$name") ;;
  esac
done < <(lines "${CONDITIONS-}")
[ $((${#valued[@]} + ${#bare[@]})) != 0 ] || fail "The engine declares no conditions."

effects=()
while IFS= read -r name; do
  case "$name" in
    *[[:space:]]* | *:*) fail "The engine declares a malformed effect name: \"$name\"." ;;
    *) effects+=("$name") ;;
  esac
done < <(lines "${EFFECTS-}")
[ "${#effects[@]}" != 0 ] || fail "The engine declares no effects."

# Succeeds when $1 is one of the remaining arguments.
among() {
  local wanted="$1" item
  shift
  for item in "$@"; do
    [ "$item" != "$wanted" ] || return 0
  done
  return 1
}

conditions=()
while IFS= read -r line; do
  if [[ "$line" == *:* ]]; then
    name=$(trim "${line%%:*}")
    value=$(trim "${line#*:}")
  else
    name="$line"
    value=""
  fi
  if [ -z "$name" ]; then
    fail "Malformed condition, with no name before the colon: \"$line\"."
  elif among "$name" ${valued[@]+"${valued[@]}"}; then
    [ -n "$value" ] || fail "Condition \"$name\" needs a value, as \"$name: <value>\": \"$line\"."
    conditions+=("$name: $value")
  elif among "$name" ${bare[@]+"${bare[@]}"}; then
    [[ "$line" != *:* ]] || fail "Condition \"$name\" takes no value: \"$line\"."
    conditions+=("$name")
  else
    fail "Unknown condition: \"$line\"."
  fi
done < <(lines "${WHEN-}")
[ "${#conditions[@]}" != 0 ] || fail "when has no conditions."

then_lines=$(lines "${THEN-}")
[ -n "$then_lines" ] || fail "then names no effect."
[[ "$then_lines" != *$'\n'* ]] || fail "then takes one effect, not several: \"${then_lines//$'\n'/, }\"."
among "$then_lines" "${effects[@]}" || fail "Unknown effect: \"$then_lines\"."

# A random heredoc delimiter, so no condition value can end the multiline output early.
delimiter="WHEN_CORE_$(od -An -N8 -tx1 /dev/urandom | tr -d ' \n')"
{
  echo "conditions<<$delimiter"
  printf '%s\n' "${conditions[@]}"
  echo "$delimiter"
  echo "then=$then_lines"
} >>"$GITHUB_OUTPUT"
printf '%s\n' "${conditions[@]}"
echo "then: $then_lines"
