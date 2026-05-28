#!/bin/bash
# Comet Harness Context - generates deterministic phase-scoped harness context packs
# Usage: comet-harness.sh <change-name> <phase> --write

set -euo pipefail

red() { echo -e "\033[31m$1\033[0m" >&2; }
green() { echo -e "\033[32m$1\033[0m" >&2; }

validate_change_name() {
  local name="$1"
  if [ -z "$name" ]; then
    red "ERROR: Change name cannot be empty"
    exit 1
  fi
  if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    red "ERROR: Invalid change name: '$name'"
    red "Valid characters: a-z, A-Z, 0-9, -, _"
    exit 1
  fi
  if [[ "$name" =~ \.\. ]]; then
    red "ERROR: Change name cannot contain '..' (path traversal not allowed)"
    exit 1
  fi
}

strip_wrapping_quotes() {
  local value="$1"
  case "$value" in
    \"*\") printf '%s\n' "${value:1:${#value}-2}" ;;
    \'*\') printf '%s\n' "${value:1:${#value}-2}" ;;
    *) printf '%s\n' "$value" ;;
  esac
}

strip_inline_comment() {
  local value="$1"
  printf '%s\n' "$value" | awk -v squote="'" '
    {
      out = ""
      quote = ""
      for (i = 1; i <= length($0); i++) {
        c = substr($0, i, 1)
        if (quote == "") {
          if (c == "\"" || c == squote) {
            quote = c
          } else if (c == "#" && (i == 1 || substr($0, i - 1, 1) ~ /[[:space:]]/)) {
            sub(/[[:space:]]+$/, "", out)
            print out
            next
          }
        } else if (c == quote) {
          quote = ""
        }
        out = out c
      }
      print out
    }
  '
}

yaml_field_value() {
  local field="$1"
  local yaml="$CHANGE_DIR/.comet.yaml"
  local value
  value=$(grep "^${field}:" "$yaml" 2>/dev/null | sed "s/^${field}: *//" || true)
  value=$(strip_inline_comment "$value")
  strip_wrapping_quotes "$value"
}

hash_stream() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{print $1}'
  else
    red "ERROR: sha256sum or shasum is required"
    exit 1
  fi
}

hash_file() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{print $1}'
  else
    red "ERROR: sha256sum or shasum is required"
    exit 1
  fi
}

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

file_line_count() {
  local file="$1"
  wc -l < "$file" | tr -d ' '
}

write_file_excerpt() {
  local file="$1"
  local total_lines
  total_lines=$(file_line_count "$file")

  echo "## $file"
  echo ""
  echo "- Source: $file"
  echo "- Lines: 1-$total_lines"
  echo "- SHA256: $(hash_file "$file")"
  echo ""
  echo '```md'
  cat "$file"
  echo '```'
  echo ""
}

discover_harness_files() {
  local scratch="$1"
  local seen="$2"
  : > "$scratch"
  : > "$seen"

  if [ ! -d ".harness" ]; then
    return 0
  fi

  for file in \
    ".harness/README.md" \
    ".harness/index/routing.md" \
    ".harness/index/priority.md"; do
    if [ -f "$file" ] && ! grep -Fxq "$file" "$seen"; then
      printf '%s\n' "$file" >> "$scratch"
      printf '%s\n' "$file" >> "$seen"
    fi
  done

  local references_file
  references_file=$(mktemp)
  cat \
    ".harness/README.md" \
    ".harness/index/routing.md" \
    ".harness/index/priority.md" 2>/dev/null |
    grep -Eo '(\.harness/)?[A-Za-z0-9._/-]+\.(md|txt|yaml|yml|json)' |
    sed 's#^\./##' |
    awk '
      {
        candidate = $0
        if (candidate !~ /^\.harness\//) {
          candidate = ".harness/" candidate
        }
        print candidate
      }
    ' | sort -u > "$references_file" || true

  while IFS= read -r candidate; do
    [ -n "$candidate" ] || continue
    [ -f "$candidate" ] || continue
    if ! grep -Fxq "$candidate" "$seen"; then
      printf '%s\n' "$candidate" >> "$scratch"
      printf '%s\n' "$candidate" >> "$seen"
    fi
  done < "$references_file"
  rm -f "$references_file"

  find ".harness" -type f \( -name "*.md" -o -name "*.txt" -o -name "*.yaml" -o -name "*.yml" -o -name "*.json" \) 2>/dev/null |
    sort | while IFS= read -r file; do
      if ! grep -Fxq "$file" "$seen"; then
        printf '%s\n' "$file" >> "$scratch"
        printf '%s\n' "$file" >> "$seen"
      fi
    done
}

compute_context_hash() {
  local files_list="$1"
  {
    printf 'phase:%s\n' "$PHASE"
    while IFS= read -r file; do
      [ -f "$file" ] || continue
      printf 'path:%s\n' "$file"
      printf 'sha256:%s\n' "$(hash_file "$file")"
    done < "$files_list"
  } | hash_stream
}

write_markdown_context() {
  local output="$1"
  local files_list="$2"
  {
    echo "# Comet Harness Context"
    echo ""
    echo "- Change: $CHANGE"
    echo "- Phase: $PHASE"
    echo "- Context hash: $CONTEXT_HASH"
    echo ""
    echo "Generated-by: comet-harness.sh"
    echo ""
    if [ ! -d ".harness" ]; then
      echo "No .harness directory exists for this project."
      echo ""
    else
      echo "This phase-scoped context pack is generated from the project harness entrypoints and their referenced files."
      echo "Use it before making phase decisions, editing files, or invoking downstream skills."
      echo ""
      while IFS= read -r file; do
        [ -f "$file" ] || continue
        write_file_excerpt "$file"
      done < "$files_list"
    fi
  } > "$output"
}

write_json_context() {
  local output="$1"
  local files_list="$2"
  {
    echo "{"
    echo "  \"change\": \"$(json_escape "$CHANGE")\","
    echo "  \"phase\": \"$(json_escape "$PHASE")\","
    echo "  \"generated_by\": \"comet-harness.sh\","
    echo "  \"context_hash\": \"$CONTEXT_HASH\","
    echo "  \"harness_present\": $HARNESS_PRESENT,"
    echo "  \"files\": ["
    local first=1
    while IFS= read -r file; do
      [ -f "$file" ] || continue
      if [ "$first" -eq 0 ]; then
        echo ","
      fi
      first=0
      printf '    { "path": "%s", "sha256": "%s" }' "$(json_escape "$file")" "$(hash_file "$file")"
    done < "$files_list"
    echo ""
    echo "  ]"
    echo "}"
  } > "$output"
}

CHANGE="${1:-}"
PHASE="${2:-}"
MODE="${3:-}"

validate_change_name "$CHANGE"

case "$PHASE" in
  open|design|build|verify|archive) ;;
  *)
    red "Usage: comet-harness.sh <change-name> <open|design|build|verify|archive> --write"
    exit 1
    ;;
esac

if [ "$MODE" != "--write" ]; then
  red "Usage: comet-harness.sh <change-name> <open|design|build|verify|archive> --write"
  exit 1
fi

CHANGE_DIR="openspec/changes/$CHANGE"
YAML="$CHANGE_DIR/.comet.yaml"
SCRIPT_DIR="$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")" 2>/dev/null || dirname "$0")"
STATE_SH="$SCRIPT_DIR/comet-state.sh"

if [ ! -d "$CHANGE_DIR" ]; then
  red "ERROR: change directory not found: $CHANGE_DIR"
  exit 1
fi
if [ ! -f "$YAML" ]; then
  red "ERROR: .comet.yaml not found at $YAML"
  exit 1
fi

HANDOFF_DIR="$CHANGE_DIR/.comet/handoff"
mkdir -p "$HANDOFF_DIR"
CONTEXT_JSON="$HANDOFF_DIR/${PHASE}-harness-context.json"
CONTEXT_MD="$HANDOFF_DIR/${PHASE}-harness-context.md"

FILES_LIST=$(mktemp)
SEEN_LIST=$(mktemp)
discover_harness_files "$FILES_LIST" "$SEEN_LIST"

if [ -d ".harness" ]; then
  HARNESS_PRESENT=true
else
  HARNESS_PRESENT=false
fi

CONTEXT_HASH="$(compute_context_hash "$FILES_LIST")"
write_markdown_context "$CONTEXT_MD" "$FILES_LIST"
write_json_context "$CONTEXT_JSON" "$FILES_LIST"

rm -f "$FILES_LIST" "$SEEN_LIST"

if [ -x "$STATE_SH" ] || [ -f "$STATE_SH" ]; then
  bash "$STATE_SH" set "$CHANGE" harness_context "$CONTEXT_JSON" >/dev/null
  bash "$STATE_SH" set "$CHANGE" harness_hash "$CONTEXT_HASH" >/dev/null
  bash "$STATE_SH" set "$CHANGE" harness_phase "$PHASE" >/dev/null
else
  red "ERROR: comet-state.sh not found; cannot record harness fields"
  exit 1
fi

green "[HARNESS] wrote $CONTEXT_JSON"
green "[HARNESS] wrote $CONTEXT_MD"
