#!/bin/bash

# Interactive script to run Claude Code in Docker

# Load .env if it exists (source from script's directory, not cwd)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/.env" ]; then
  set -a
  source "$SCRIPT_DIR/.env"
  set +a
fi

# Check if path was provided as argument
if [ -n "$1" ]; then
  PATH_TO_CODE=$(realpath "$1")
else
  # Interactive prompt
  read -e -p "Enter the path to your code directory: " user_path

  if [ -z "$user_path" ]; then
    echo "Error: No path provided."
    exit 1
  fi

  # Expand ~ and resolve to absolute path
  user_path="${user_path/#\~/$HOME}"
  PATH_TO_CODE=$(realpath "$user_path" 2>/dev/null)

  if [ ! -d "$PATH_TO_CODE" ]; then
    echo "Error: Directory '$user_path' does not exist."
    exit 1
  fi
fi

# Ensure Docker image exists
if ! docker image inspect claudecode:latest > /dev/null 2>&1;
then
  echo "Docker image 'claudecode:latest' not found. Please build it first with 'make build'."
  exit 1
fi

# Check for GitHub token
if [ -z "$GH_TOKEN" ]; then
  echo "Warning: GH_TOKEN not set. GitHub access will not be configured."
  echo "  Copy .env.example to .env and set GH_TOKEN to enable git push, gh pr create, etc."
  GH_ENABLED=false
else
  GH_ENABLED=true
fi

# Prompt for container name
read -e -p "Enter a name for this container: " container_name
if [ -z "$container_name" ]; then
  echo "Error: No container name provided."
  exit 1
fi
CONTAINER_NAME="claude-code-dev-${container_name}"

# Prompt for dangerously skip permissions flag (default: yes)
read -e -p "Skip permission prompts? (--dangerously-skip-permissions) [Y/n]: " skip_perms
skip_perms="${skip_perms:-Y}"

CLAUDE_CMD="claude"
if [[ "$skip_perms" =~ ^[Yy]$ ]] || [ -z "$skip_perms" ]; then
  CLAUDE_CMD="claude --dangerously-skip-permissions"
fi

DOCKER_RUN_ARGS=(
  -d
  -v "${PATH_TO_CODE}:/workspace"
  --name "$CONTAINER_NAME"
  --label project=claude-code
)

# Mount sryps skills individually, skipping any that already exist in the target project
if [ -d "${SCRIPT_DIR}/skills/sryps" ]; then
  for skill_dir in "${SCRIPT_DIR}/skills/sryps"/*/; do
    skill_name=$(basename "$skill_dir")
    if [ -d "${PATH_TO_CODE}/.claude/skills/${skill_name}" ]; then
      echo "Skipping skill '${skill_name}' — already exists in project."
    else
      DOCKER_RUN_ARGS+=(-v "${skill_dir}:/workspace/.claude/skills/${skill_name}")
    fi
  done
fi

docker run "${DOCKER_RUN_ARGS[@]}" \
  claudecode:latest \
  tail -f /dev/null

echo "Container '$CONTAINER_NAME' started."

# Fix ownership of Docker-created mount points
docker exec -u root "$CONTAINER_NAME" chown -R dev:dev /workspace/.claude 2>/dev/null || true

# Git identity (override via env vars GIT_USER_NAME / GIT_USER_EMAIL)
docker exec "$CONTAINER_NAME" git config --global user.name "${GIT_USER_NAME:-Claude Dev}"
docker exec "$CONTAINER_NAME" git config --global user.email "${GIT_USER_EMAIL:-claude-dev@localhost}"

if [ "$GH_ENABLED" = true ]; then
  # Write token to tmpfs (RAM-only)
  echo "$GH_TOKEN" | docker exec -i "$CONTAINER_NAME" sh -c 'cat > /run/secrets/gh_token && chmod 600 /run/secrets/gh_token'

  # Verify the token was written
  if ! docker exec "$CONTAINER_NAME" test -s /run/secrets/gh_token; then
    echo "Error: Failed to write GH_TOKEN to container. GitHub access will not work."
    GH_ENABLED=false
  fi

  # Auth gh CLI
  docker exec "$CONTAINER_NAME" sh -c 'cat /run/secrets/gh_token | gh auth login --with-token 2>/dev/null'

  # Git credential helper for HTTPS push
  docker exec "$CONTAINER_NAME" sh -c "git config --global credential.helper '!f() { echo username=x-access-token; echo password=\$(cat /run/secrets/gh_token); }; f'"

  # Rewrite SSH remotes to HTTPS so the credential helper works
  docker exec "$CONTAINER_NAME" git config --global url."https://github.com/".insteadOf "git@github.com:"

  echo "GitHub access configured."
fi

if [ "$GH_ENABLED" = true ]; then
  docker exec "$CONTAINER_NAME" sh -c 'echo "export GH_TOKEN=\$(cat /run/secrets/gh_token)" >> /home/dev/.bashrc'
fi
docker exec -it -e GH_TOKEN="${GH_TOKEN:-}" "$CONTAINER_NAME" $CLAUDE_CMD

# Cleanup after claude exits
docker stop "$CONTAINER_NAME" > /dev/null
docker rm "$CONTAINER_NAME" > /dev/null
echo "Container '$CONTAINER_NAME' removed."
