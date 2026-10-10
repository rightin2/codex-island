#!/bin/bash
# Exercises hooks/usage-cap-hook.sh against fake state files.
set -u
cd "$(dirname "$0")/.."
hook=hooks/usage-cap-hook.sh
f=$(mktemp)
fail=0
check() { if [ "$2" = "$3" ]; then echo "PASS $1"; else echo "FAIL $1: got [$2] want [$3]"; fail=1; fi; }
run() { echo '{}' | CODEXISLAND_CAP_FILE="$f" "$hook" "$1"; }
now=$(date +%s)

unlink "$f"
check "no state file: silent" "$(run pre)" ""
printf 'level=soft\nmessage=Wrap up\nupdated=%s\n' "$now" > "$f"
check "soft pre: allowed" "$(run pre)" ""
check "soft post: wrap-up note" "$(run post)" '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"Wrap up"}}'
check "soft prompt: note" "$(run prompt)" '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"Wrap up"}}'
printf 'level=hard\nmessage=Paused\nupdated=%s\n' "$now" > "$f"
check "hard pre: stop" "$(run pre)" '{"continue":false,"stopReason":"Paused"}'
check "hard prompt: blocked" "$(run prompt)" '{"decision":"block","reason":"Paused"}'
printf 'level=hard\nmessage=Paused\nupdated=%s\n' "$((now - 3600))" > "$f"
check "stale file (island quit): allowed" "$(run pre)" ""
unlink "$f"
exit $fail
