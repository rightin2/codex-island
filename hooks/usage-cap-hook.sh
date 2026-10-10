#!/bin/bash
# CodexIsland usage cap hook for Claude Code (PreToolUse, PostToolUse, UserPromptSubmit).
# CodexIsland writes ~/.claude/usage-cap.state only while a cap is reached, so normally
# this exits straight away. Usage: usage-cap-hook.sh pre|post|prompt
f="${CODEXISLAND_CAP_FILE:-$HOME/.claude/usage-cap.state}"
[ -f "$f" ] || exit 0
cat >/dev/null
level= message= updated=0
while IFS='=' read -r k v; do
  case $k in level) level=$v ;; message) message=$v ;; updated) updated=$v ;; esac
done < "$f"
# The island refreshes the file every minute; an old one means it quit, so don't block anything.
[ $(( $(date +%s) - updated )) -le 600 ] || exit 0
case "$level:$1" in
  soft:post)   printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}\n' "$message" ;;
  soft:prompt) printf '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"%s"}}\n' "$message" ;;
  hard:pre|hard:post) printf '{"continue":false,"stopReason":"%s"}\n' "$message" ;;
  hard:prompt) printf '{"decision":"block","reason":"%s"}\n' "$message" ;;
esac
exit 0
