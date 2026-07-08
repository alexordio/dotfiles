#!/usr/bin/env bash
# ~/.claude/ccx.sh
# Lists available Claude agents and skills for the current directory.

PLUGINS_JSON="$HOME/.claude/plugins/installed_plugins.json"
AGENTS_DIR="$HOME/.claude/agents"
CWD="${1:-$PWD}"

reset="\033[0m"
bold="\033[1m"
dim="\033[2m"
cyan="\033[36m"
yellow="\033[33m"
green="\033[32m"
blue="\033[34m"

divider() { printf "${dim}%s${reset}\n" "─────────────────────────────────────────"; }

get_description() {
  local file="$1"
  python3 - "$file" << 'PYEOF'
import sys, re

path = sys.argv[1]
try:
    text = open(path).read()
except Exception:
    sys.exit(0)

# extract frontmatter between --- markers
m = re.search(r'^---\s*\n(.*?)\n---', text, re.DOTALL)
if not m:
    sys.exit(0)

fm = m.group(1)

# handle multi-line YAML block scalar (description: >)
dm = re.search(r'^description:\s*>\s*\n((?:[ \t]+.+\n?)+)', fm, re.MULTILINE)
if dm:
    desc = ' '.join(dm.group(1).split())
else:
    dm = re.search(r'^description:\s*(.+)', fm, re.MULTILINE)
    desc = dm.group(1).strip('"\'') if dm else ''

desc = desc[:55] + '…' if len(desc) > 55 else desc
print(desc)
PYEOF
}

# ── Header ──────────────────────────────────────────────────────────────────
repo=$(basename "$CWD")
branch=$(git -C "$CWD" rev-parse --abbrev-ref HEAD 2>/dev/null)
has_claude_md=$( [[ -f "$CWD/CLAUDE.md" || -f "$CWD/.claude/CLAUDE.md" ]] && echo "yes" || echo "")

divider
printf "  ${bold}${cyan}%s${reset}" "$repo"
[[ -n "$branch" ]] && printf "  ${dim}%s${reset}" "$branch"
[[ -n "$has_claude_md" ]] && printf "  ${dim}CLAUDE.md${reset}"
printf "\n"
divider

# ── Agents ───────────────────────────────────────────────────────────────────
printf "\n${bold}AGENTS${reset}\n"

print_agent() {
  local f="$1" scope="$2"
  local name desc
  name=$(basename "$f" .md)
  desc=$(get_description "$f")
  printf "  ${yellow}%-26s${reset} ${dim}%s${reset}\n" "$name" "$desc"
}

if [[ -d "$AGENTS_DIR" ]]; then
  for f in "$AGENTS_DIR"/*.md; do
    [[ -f "$f" ]] || continue
    print_agent "$f" "global"
  done
fi

local_agents_dir="$CWD/.claude/agents"
if [[ -d "$local_agents_dir" ]]; then
  for f in "$local_agents_dir"/*.md; do
    [[ -f "$f" ]] || continue
    print_agent "$f" "project"
  done
fi

# ── Skills ───────────────────────────────────────────────────────────────────
printf "\n${bold}SKILLS${reset}\n"

print_skills() {
  local color="$1" install_path="$2"
  local skills_dir="$install_path/skills"
  [[ -d "$skills_dir" ]] || return
  for skill_dir in "$skills_dir"/*/; do
    [[ -d "$skill_dir" ]] || continue
    local skill desc skill_file
    skill=$(basename "$skill_dir")
    skill_file=$(find "$skill_dir" -maxdepth 1 -iname "skill.md" | head -1)
    desc=""
    [[ -n "$skill_file" ]] && desc=$(get_description "$skill_file")
    printf "  ${color}/%-24s${reset} ${dim}%s${reset}\n" "$skill" "$desc"
  done
}

if [[ ! -f "$PLUGINS_JSON" ]]; then
  printf "  ${dim}no plugins installed${reset}\n"
else
  printf "\n  ${dim}global${reset}\n"
  while IFS= read -r line; do
    install_path=$(echo "$line" | jq -r '.installPath')
    print_skills "$green" "$install_path"
  done < <(jq -c '
    .plugins | to_entries[] |
    .value[] |
    select(.scope == "user") |
    {installPath: .installPath}
  ' "$PLUGINS_JSON")

  project_skills=$(jq -c --arg cwd "$CWD" '
    .plugins | to_entries[] |
    .value[] |
    select(.scope == "project" and .projectPath == $cwd) |
    {installPath: .installPath}
  ' "$PLUGINS_JSON")

  if [[ -n "$project_skills" ]]; then
    printf "\n  ${dim}this repo${reset}\n"
    while IFS= read -r line; do
      install_path=$(echo "$line" | jq -r '.installPath')
      print_skills "$blue" "$install_path"
    done <<< "$project_skills"
  fi
fi

printf "\n"
divider
