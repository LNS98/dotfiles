#!/bin/sh
# Tab-bar status for herdr (ui.tab_bar_right command entry), macOS and Linux.
# One line, e.g.: "1 blocked · 2 working  cpu 12%  mem 9.8G/16G  bat 87%"
# Runs on the herdr server every few seconds, so keep it cheap (~30ms here).

# Agents needing attention. Only non-idle states are shown, so this segment
# disappears when nothing is happening. Needs jq (install.sh requires it).
agents=""
if command -v jq >/dev/null 2>&1; then
  agents=$(herdr agent list 2>/dev/null | jq -r '
    [.result.agents[].agent_status]
    | { blocked: map(select(. == "blocked")) | length,
        working: map(select(. == "working")) | length,
        done:    map(select(. == "done"))    | length }
    | to_entries | map(select(.value > 0) | "\(.value) \(.key)") | join(" · ")' 2>/dev/null)
fi

# CPU: sum of per-process %cpu over core count, so 100% = every core busy.
case "$(uname -s)" in
  Darwin)
    ncpu=$(sysctl -n hw.ncpu)
    page=$(sysctl -n hw.pagesize)
    # used = active + wired + compressed, what Activity Monitor calls "used"
    used=$(vm_stat | awk -v p="$page" '
      /Pages active/                 {a=$NF}
      /Pages wired down/             {w=$NF}
      /Pages occupied by compressor/ {c=$NF}
      END {gsub(/\./,"",a); gsub(/\./,"",w); gsub(/\./,"",c); printf "%.1f", (a+w+c)*p/1073741824}')
    total=$(sysctl -n hw.memsize | awk '{printf "%d", $1/1073741824}')
    bat=$(pmset -g batt 2>/dev/null | awk '/InternalBattery/ {
      match($0, /[0-9]+%/); b=substr($0, RSTART, RLENGTH)
      if ($0 ~ /; charging/ || $0 ~ /; charged/) b=b"⚡"
      print b }')
    ;;
  Linux)
    ncpu=$(nproc)
    used=$(awk '/MemTotal/ {t=$2} /MemAvailable/ {a=$2} END {printf "%.1f", (t-a)/1048576}' /proc/meminfo)
    total=$(awk '/MemTotal/ {printf "%d", $2/1048576}' /proc/meminfo)
    bat=""
    for b in /sys/class/power_supply/BAT*; do
      [ -r "$b/capacity" ] || continue
      bat="$(cat "$b/capacity")%"
      [ "$(cat "$b/status" 2>/dev/null)" = "Charging" ] && bat="$bat⚡"
      break
    done
    ;;
  *) ncpu=1; used="?"; total="?"; bat="" ;;
esac
cpu=$(ps -A -o %cpu= | awk -v n="$ncpu" '{s+=$1} END {printf "%d", s/n}')

out="cpu ${cpu}%  mem ${used}G/${total}G"
[ -n "$agents" ] && out="$agents  $out"
[ -n "$bat" ] && out="$out  bat $bat"
printf '%s\n' "$out"
