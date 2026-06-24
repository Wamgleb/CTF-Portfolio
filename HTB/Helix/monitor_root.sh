#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK_PY="$SCRIPT_DIR/check.py"
MAINT_FILE="/opt/helix/state/maintenance_window"

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required but not found"
  exit 1
fi

printf '=== helix root monitor started (%s) ===\n' "$(date '+%F %T')"
while true; do
  now="$(date '+%F %T')"
  echo "\n[$now]"

  if [ -r "$MAINT_FILE" ]; then
    until_ts="$(cat "$MAINT_FILE" 2>/dev/null || true)"
    if [[ "$until_ts" =~ ^[0-9]+$ ]]; then
      now_ts="$(date +%s)"
      if (( now_ts < until_ts )); then
        remaining=$((until_ts - now_ts))
        echo "[+] maintenance_window is OPEN (expires in ${remaining}s)"
      else
        echo "[-] maintenance_window file exists but expired"
      fi
    else
      echo "[-] maintenance_window file is present but invalid: ${until_ts}"
    fi
  else
    echo "[-] maintenance_window is CLOSED or unreadable"
  fi

  if [ -f "$CHECK_PY" ]; then
    status="$(python3 "$CHECK_PY" 2>/dev/null || true)"
    if [ -n "$status" ]; then
      mode="$(printf '%s' "$status" | grep 'Node: Mode' | awk -F'Value:' '{print $2}' | tr -d '[:space:]')"
      test_override="$(printf '%s' "$status" | grep 'Node: TestOverride' | awk -F'Value:' '{print $2}' | tr -d '[:space:]')"
      rods="$(printf '%s' "$status" | grep 'Node: RodsInserted' | awk -F'Value:' '{print $2}' | tr -d '[:space:]')"
      cooling="$(printf '%s' "$status" | grep 'Node: EmergencyCooling' | awk -F'Value:' '{print $2}' | tr -d '[:space:]')"
      trip="$(printf '%s' "$status" | grep 'Node: TripActive' | awk -F'Value:' '{print $2}' | tr -d '[:space:]')"
      temp="$(printf '%s' "$status" | grep 'Node: Temperature |' | awk -F'Value:' '{print $2}' | tr -d '[:space:]')"
      pressure="$(printf '%s' "$status" | grep 'Node: Pressure' | awk -F'Value:' '{print $2}' | tr -d '[:space:]')"

      echo "[*] Mode=$mode TestOverride=$test_override RodsInserted=$rods Cooling=$cooling Trip=$trip Temp=$temp Pressure=$pressure"
    else
      echo "[-] check.py returned no status"
    fi
  else
    echo "[-] check.py not found at $CHECK_PY"
  fi

  sleep 5
 done
