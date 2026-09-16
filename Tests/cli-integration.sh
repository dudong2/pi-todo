#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
BIN_DIR=$(cd "$ROOT" && swift build --show-bin-path)
TODOCTL="$BIN_DIR/todoctl"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
DB="$TMP/todos.sqlite"

ADD_OUTPUT=$(
    "$TODOCTL" --database "$DB" add \
        --project "pi-todo" \
        --title "Verify CLI persistence" \
        --details $'Background: The helper writes context.\nDone when: Details survive reopening.'
)
ID=$(printf '%s\n' "$ADD_OUTPUT" | awk '{sub(/^Added /, ""); sub(/:.*/, ""); print}')

JSON=$("$TODOCTL" --database "$DB" list --json)
python3 - "$ID" "$JSON" <<'PY'
import json
import sys

todo_id, payload = sys.argv[1], sys.argv[2]
todos = json.loads(payload)
assert len(todos) == 1, todos
assert todos[0]["id"] == todo_id, todos
assert todos[0]["project"] == "pi-todo", todos
assert todos[0]["title"] == "Verify CLI persistence", todos
assert todos[0]["details"] == "Background: The helper writes context.\nDone when: Details survive reopening.", todos
assert todos[0]["completed_at"] is None, todos
PY

"$TODOCTL" --database "$DB" complete "$ID" >/dev/null
JSON=$("$TODOCTL" --database "$DB" list --json)
python3 - "$JSON" <<'PY'
import json
import sys

assert json.loads(sys.argv[1]) == [], sys.argv[1]
PY

ALL_JSON=$("$TODOCTL" --database "$DB" list --all --json)
python3 - "$ALL_JSON" <<'PY'
import json
import sys

todos = json.loads(sys.argv[1])
assert len(todos) == 1, todos
assert todos[0]["completed_at"] is not None, todos
PY

printf 'CLI integration passed\n'
