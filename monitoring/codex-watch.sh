#!/usr/bin/env bash
set -euo pipefail
REPO='D:/PLATTFORM/-CLOUD-SUPERBRAIN-DEVELOPER-PLATFORM'
LOG="$REPO/monitoring/watch.jsonl"
mkdir -p "$(dirname "$LOG")"
while true; do
  pushd "$REPO" >/dev/null
  status="$(git status --short || true)"
  popd >/dev/null
  changes="$(printf "%s\n" "$status" | sed '/^$/d' | wc -l | tr -d ' ')"
  if [ "$changes" -gt 0 ]; then
    ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    stats="$(printf "%s\n" "$status" | awk '/^ /{print $1}' | while IFS= read -r p; do
      numstat="$(git -C "$REPO" diff --numstat -- "$p" 2>/dev/null | head -n 1 || true)"
      if [ -n "$numstat" ]; then
        add="$(echo "$numstat" | awk '{print $1}')"
        del="$(echo "$numstat" | awk '{print $2}')"
        printf '"%s":"+%s -%s"' "$p" "$add" "$del"
      fi
    done | paste -sd,)"
    verify_msg="$(bash "$REPO/scripts/verify-phase5.sh" 2>/dev/null || true)"
    : > /tmp/codex_watch_entry.json
    entry="{\"time\":\"$ts\",\"changes\":$changes,\"stats\":{$stats},\"verify\":\"$verify_msg\"}"
    if command -v jq >/dev/null 2>&1; then
      entry="$(printf '%s' "$entry" | jq -c .)"
    fi
    printf '%s\n' "$entry" >> "$LOG"
    if printf '%s' "$verify_msg" | grep -Eqi 'TRASH|OBVIOUS|LOOP'; then
      echo "[$ts] Watchdog: suspicious output, triggering auto-repair."
      bash "$REPO/scripts/auto-repair-codex.sh" >/dev/null 2>&1 || true
    fi
  fi
  sleep 10
done
