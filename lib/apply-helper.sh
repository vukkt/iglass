#!/bin/bash
# Applies iTerm2 app-wide settings while iTerm2 is not running.
#
# iTerm2 writes its preferences back when it quits, so global settings only stick if they are
# changed while it is closed. The iglass CLI usually runs inside iTerm2, so it hands this job to
# launchd (`launchctl submit`), which keeps it alive after iTerm2 exits. When iTerm2 is already
# closed, the CLI runs this script directly.
#
# Usage: apply-helper.sh DOMAIN PLAN RESULT ID TIMEOUT PROCESS [LABEL]
#   PLAN    tab-separated lines: "write<TAB>key<TAB>type<TAB>value" or "delete<TAB>key"
#   RESULT  receives one line: "ID<TAB>applied|aborted|failed<TAB>message"
#   LABEL   launchd label to remove when done (omit when not started by launchd)
#
# Always exits 0: launchd restarts submitted jobs that exit with an error.

set -u

domain=$1 plan=$2 result=$3 id=$4 timeout=$5 process=$6 label=${7:-}
log="$result.log"

finish() {
  printf '%s\t%s\t%s\n' "$id" "$1" "$2" >"$result"
  printf '%s %s %s: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$id" "$1" "$2" >>"$log"
  if [[ -n "$label" ]]; then
    launchctl remove "$label" >/dev/null 2>&1
  fi
  exit 0
}

notify() {
  osascript - "$1" >/dev/null 2>&1 <<'APPLESCRIPT'
on run argv
  display notification (item 1 of argv) with title "iglass"
end run
APPLESCRIPT
}

[[ -r "$plan" ]] || finish failed "plan file missing: $plan"

was_running=0
if pgrep -x "$process" >/dev/null 2>&1; then
  was_running=1
  # iTerm2 may ask the user to confirm quitting; if they cancel, it keeps running and
  # nothing is written.
  osascript -e 'tell application id "com.googlecode.iterm2" to quit' >/dev/null 2>&1 &
  quitter=$!
  ticks=0
  while pgrep -x "$process" >/dev/null 2>&1; do
    if ((ticks >= timeout * 2)); then
      kill "$quitter" >/dev/null 2>&1
      notify "iTerm2 did not quit, so its settings were not changed."
      finish aborted "iTerm2 did not quit within ${timeout}s"
    fi
    sleep 0.5
    ticks=$((ticks + 1))
  done
  wait "$quitter" 2>/dev/null
  sleep 1 # let iTerm2's final preference write settle
fi

failures=""
while IFS=$'\t' read -r op key type value || [[ -n "$op" ]]; do
  [[ -z "$op" ]] && continue
  case "$op" in
    write)
      case "$type" in
        integer) flag=-int ;;
        float) flag=-float ;;
        boolean) flag=-bool ;;
        string) flag=-string ;;
        *)
          failures="$failures $key"
          continue
          ;;
      esac
      defaults write "$domain" "$key" "$flag" "$value" >/dev/null 2>&1 || failures="$failures $key"
      ;;
    delete)
      # Deleting a key that is already absent is fine.
      defaults delete "$domain" "$key" >/dev/null 2>&1 || true
      ;;
    *)
      failures="$failures $op"
      ;;
  esac
done <"$plan"

if [[ $was_running == 1 ]]; then
  open -b com.googlecode.iterm2 >/dev/null 2>&1 || true
fi

if [[ -n "$failures" ]]; then
  notify "Some iTerm2 settings could not be changed. Run: iglass doctor"
  finish failed "could not write:$failures"
fi
finish applied "ok"
