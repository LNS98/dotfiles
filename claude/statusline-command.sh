#!/usr/bin/env bash

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // ""')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // ""')
context_size=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
current_input=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // 0')
current_output=$(echo "$input" | jq -r '.context_window.current_usage.output_tokens // 0')
cache_creation=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')
cache_read=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')

CYAN='\033[96m'
GREEN='\033[92m'
YELLOW='\033[93m'
MAGENTA='\033[95m'
BLUE='\033[94m'
RED='\033[91m'
RESET='\033[0m'
BOLD='\033[1m'

status_parts=()

if [ -n "$used_pct" ] && [ "$used_pct" != "null" ]; then
    used_int=$(printf "%.0f" "$used_pct")

    if [ "$used_int" -lt 50 ]; then
        bar_color="$GREEN"
    elif [ "$used_int" -lt 75 ]; then
        bar_color="$YELLOW"
    else
        bar_color="$RED"
    fi

    bar_filled=$((used_int / 10))
    bar_empty=$((10 - bar_filled))

    bar="["
    for ((i=0; i<bar_filled; i++)); do bar+="█"; done
    for ((i=0; i<bar_empty; i++)); do bar+="░"; done
    bar+="]"

    status_parts+=("$(printf "${bar_color}${bar} ${used_int}%%${RESET}")")
fi

if [ "$current_input" != "null" ] && [ "$current_output" != "null" ]; then
    total_used=$((current_input + current_output + cache_creation + cache_read))

    if [ "$total_used" -ge 1000 ]; then
        used_k=$(awk "BEGIN {printf \"%.1f\", $total_used/1000}")
        used_display="${used_k}K"
    else
        used_display="$total_used"
    fi

    if [ "$context_size" -ge 1000 ]; then
        size_k=$(awk "BEGIN {printf \"%.0f\", $context_size/1000}")
        size_display="${size_k}K"
    else
        size_display="$context_size"
    fi

    status_parts+=("$(printf "${CYAN}${used_display}/${size_display}${RESET}")")
fi

if [ -n "$cwd" ] && [ -d "$cwd" ]; then
    git_branch=$(cd "$cwd" 2>/dev/null && git --no-optional-locks rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [ -n "$git_branch" ]; then
        git_status=""
        if [ -n "$(cd "$cwd" 2>/dev/null && git --no-optional-locks status --porcelain 2>/dev/null)" ]; then
            git_status="$(printf " ${RED}●${RESET}")"
        fi
        status_parts+=("$(printf "${MAGENTA}${git_branch}${git_status}${RESET}")")
    fi
fi

if [ -n "$cwd" ] && [ -d "$cwd" ]; then
    project_name=$(basename "$cwd")
    status_parts+=("$(printf "${BLUE}${BOLD}${project_name}${RESET}")")
fi

if [ ${#status_parts[@]} -gt 0 ]; then
    printf "%s" "${status_parts[0]}"
    for part in "${status_parts[@]:1}"; do
        printf " ${BOLD}|${RESET} %s" "$part"
    done
    printf "\n"
fi
