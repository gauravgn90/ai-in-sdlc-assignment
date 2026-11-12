#!/usr/bin/env bash
# Runs the review eval: every case in its own fresh, headless Claude Code session.
#
# Usage:
#   ops/evals/run-eval.sh <run-label> [--context FILE] [--model MODEL]
#
# Examples:
#   ops/evals/run-eval.sh run-1                          # baseline
#   ops/evals/run-eval.sh run-2
#   ops/evals/run-eval.sh run-3
#   ops/evals/run-eval.sh run-4-context --context AGENTS.md   # the one changed variable
#   ops/evals/run-eval.sh run-2 --only case-12                # re-run a single case
#
# Each case runs in an empty temp directory, so the reviewer sees only the
# review prompt and the diff (as ops/evals/README.md requires), and never this
# repo, its CLAUDE.md, or answer-key.md. With --context, the given file is
# copied into that directory as CLAUDE.md, which Claude Code loads automatically.
set -euo pipefail

LABEL="${1:?usage: run-eval.sh <run-label> [--context FILE] [--model MODEL]}"
shift
CONTEXT=""
MODEL=""
ONLY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --context) CONTEXT="$(realpath "$2")"; shift 2 ;;
    --model)   MODEL="$2"; shift 2 ;;
    --only)    ONLY="$2"; shift 2 ;;
    *) echo "unknown option: $1" >&2; exit 1 ;;
  esac
done

EVAL_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT_DIR="$EVAL_DIR/results/$LABEL"
mkdir -p "$OUT_DIR"

PROMPT='Review this diff for defects. For each finding give the file, the line, what goes wrong, and how confident you are. If you find nothing, say so explicitly rather than listing general observations.'

MODEL_ARGS=()
if [ -n "$MODEL" ]; then MODEL_ARGS=(--model "$MODEL"); fi

{
  echo "label: $LABEL"
  echo "date: $(date -Iseconds)"
  echo "claude: $(claude --version 2>/dev/null || echo unknown)"
  echo "model: ${MODEL:-default}"
  echo "context: ${CONTEXT:-none}"
} >> "$OUT_DIR/_run-info.txt"

for case_file in "$EVAL_DIR"/cases/case-*.diff; do
  name="$(basename "$case_file" .diff)"
  if [ -n "$ONLY" ] && [ "$name" != "$ONLY" ]; then continue; fi
  sandbox="$(mktemp -d)"
  if [ -n "$CONTEXT" ]; then cp "$CONTEXT" "$sandbox/CLAUDE.md"; fi
  echo "[$LABEL] $name"
  if ! ( cd "$sandbox" && claude -p "$PROMPT" "${MODEL_ARGS[@]}" < "$case_file" ) > "$OUT_DIR/$name.md" 2>&1; then
    echo "  failed, see $OUT_DIR/$name.md" >&2
  fi
  rm -rf "$sandbox"
done

if grep -l "session limit" "$OUT_DIR"/case-*.md 2>/dev/null; then
  echo "WARNING: the files above hit the Claude session limit. Re-run them after the limit resets." >&2
fi
echo "Done. Review outputs are in $OUT_DIR"
