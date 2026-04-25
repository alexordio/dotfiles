#!/usr/bin/env bash
# ~/.claude/statusline.sh
# Shows: repo-name | model | ctx: XX% | 5h: XX%
# Colors for ctx: green <40%, yellow 40-59%, red >=60%

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
model=$(echo "$input" | jq -r '.model.display_name // "claude"')
ctx_pct=$(echo "$input" | jq -r '.context_window.used_percentage // 0')
five_hour=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // 0')

if [ -n "$cwd" ]; then
  repo=$(basename "$cwd")
else
  repo="claude"
fi

reset="\033[0m"
green="\033[32m"
yellow="\033[33m"
red="\033[31m"
dim="\033[2m"
bold="\033[1m"

if [ "$ctx_pct" -lt 40 ]; then
  ctx_color="$green"
elif [ "$ctx_pct" -lt 60 ]; then
  ctx_color="$yellow"
else
  ctx_color="$red"
fi

if [ "$five_hour" -lt 60 ]; then
  rl_color="$dim"
elif [ "$five_hour" -lt 85 ]; then
  rl_color="$yellow"
else
  rl_color="$red"
fi

printf "${bold}%s${reset} ${dim}|${reset} ${dim}%s${reset} ${dim}|${reset} ${ctx_color}ctx: %d%%${reset} ${dim}|${reset} ${rl_color}5h: %d%%${reset}" \
  "$repo" "$model" "$ctx_pct" "$five_hour"
