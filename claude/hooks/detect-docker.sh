#!/usr/bin/env bash
# ~/.claude/hooks/detect-docker.sh
# SessionStart hook: detects docker-compose setup and injects context.

input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd // ""')

if [ -z "$cwd" ]; then
  exit 0
fi

# Per-project override: .claude/docker.json with {"project": "...", "service": "..."}
override_file="$cwd/.claude/docker.json"
if [ -f "$override_file" ]; then
  project_flag=$(jq -r '.project // ""' "$override_file")
  php_service=$(jq -r '.service // ""' "$override_file")

  if [ -n "$project_flag" ]; then
    exec_prefix="docker compose -p ${project_flag} exec"
    run_prefix="docker compose -p ${project_flag} run --rm"
  else
    exec_prefix="docker compose exec"
    run_prefix="docker compose run --rm"
  fi

  if [ -z "$php_service" ]; then
    php_service="php"
  fi

  cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "Docker Compose detected (project override). Run PHP/Symfony/Composer/bin-console commands inside the container, not on the host:\n- \`${exec_prefix} ${php_service} php bin/console ...\`\n- \`${exec_prefix} ${php_service} composer ...\`\n- \`${exec_prefix} ${php_service} vendor/bin/phpunit ...\`\n- \`${exec_prefix} ${php_service} vendor/bin/phpstan ...\`\nFor one-off commands without an existing container, use \`${run_prefix} ${php_service} ...\`. Never run \`php\` or \`composer\` directly on the host for this project."
  }
}
EOF
  exit 0
fi

# Look for a compose file in the cwd (and one level up, for monorepos)
compose_file=""
for candidate in \
  "$cwd/docker-compose.yml" \
  "$cwd/docker-compose.yaml" \
  "$cwd/compose.yml" \
  "$cwd/compose.yaml" \
  "$cwd/../docker-compose.yml"; do
  if [ -f "$candidate" ]; then
    compose_file="$candidate"
    break
  fi
done

if [ -z "$compose_file" ]; then
  exit 0
fi

# Try to find a PHP service name. Common names: php, app, api, fpm.
php_service=""
for name in php app api fpm web symfony; do
  if grep -qE "^\s*${name}:" "$compose_file" 2>/dev/null; then
    php_service="$name"
    break
  fi
done

# Fallback
if [ -z "$php_service" ]; then
  php_service="php"
fi

# Emit structured additionalContext for Claude
cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "Docker Compose detected at ${compose_file}. Run PHP/Symfony/Composer/bin-console commands inside the container, not on the host:\n- \`docker compose exec ${php_service} php bin/console ...\`\n- \`docker compose exec ${php_service} composer ...\`\n- \`docker compose exec ${php_service} vendor/bin/phpunit ...\`\n- \`docker compose exec ${php_service} vendor/bin/phpstan ...\`\nFor one-off commands without an existing container, use \`docker compose run --rm ${php_service} ...\`. Never run \`php\` or \`composer\` directly on the host for this project."
  }
}
EOF
