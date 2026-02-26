#!/bin/bash

# Interactive script to run Claude Code in Docker

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

# Prompt for container name
read -e -p "Enter a name for this container: " container_name
if [ -z "$container_name" ]; then
  echo "Error: No container name provided."
  exit 1
fi
CONTAINER_NAME="claude-code-dev-${container_name}"

docker run -d \
  -v ${PATH_TO_CODE}:/workspace \
  --name $CONTAINER_NAME \
  --label project=claude-code \
  claudecode:latest \
  tail -f /dev/null

echo "Container '$CONTAINER_NAME' started."
docker exec -it $CONTAINER_NAME claude

# Cleanup after claude exits
docker stop $CONTAINER_NAME > /dev/null
docker rm $CONTAINER_NAME > /dev/null
echo "Container '$CONTAINER_NAME' removed."
