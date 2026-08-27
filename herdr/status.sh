#!/bin/sh
# Tab-bar status for herdr (ui.tab_bar_right command entry). macOS only.
# Prints one line: "cpu 12%  mem 9.8G/16G  bat 87%"
# Keep it cheap: it runs every few seconds on the herdr server.

# CPU: sum of per-process %cpu, normalised by core count so 100% = every core busy.
ncpu=$(sysctl -n hw.ncpu)
cpu=$(ps -A -o %cpu= | awk -v n="$ncpu" '{s+=$1} END {printf "%d", s/n}')

# Memory: used = active + wired + compressed pages (what Activity Monitor calls "used").
page=$(sysctl -n hw.pagesize)
used=$(vm_stat | awk -v p="$page" '
  /Pages active/      {a=$NF}
  /Pages wired down/  {w=$NF}
  /Pages occupied by compressor/ {c=$NF}
  END {gsub(/\./,"",a); gsub(/\./,"",w); gsub(/\./,"",c); printf "%.1f", (a+w+c)*p/1073741824}')
total=$(sysctl -n hw.memsize | awk '{printf "%d", $1/1073741824}')

# Battery: "87%" plus a flash when charging; empty on desktops.
bat=$(pmset -g batt 2>/dev/null | awk '/InternalBattery/ {
  match($0, /[0-9]+%/); b=substr($0, RSTART, RLENGTH)
  if ($0 ~ /; charging/ || $0 ~ /; charged/) b=b"⚡"
  print b }')

out="cpu ${cpu}%  mem ${used}G/${total}G"
[ -n "$bat" ] && out="$out  bat $bat"
printf '%s\n' "$out"
