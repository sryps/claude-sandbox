.PHONY: help build run exec stop status logs clean restart shell

NAME ?=
CONTAINER = claude-code-dev-$(NAME)

help:
	@echo "Claude Code Docker Environment"
	@echo "==============================="
	@echo ""
	@echo "Available commands:"
	@echo "  make build           - Build the Docker image"
	@echo "  make run             - Start the container (interactive path prompt) and exec into Claude container"
	@echo "  make exec   NAME=x   - Attach to running container with Claude Code"
	@echo "  make shell  NAME=x   - Open bash shell in running container"
	@echo "  make stop   NAME=x   - Stop and remove the container"
	@echo "  make start           - Start the container (non-interactive)"
	@echo "  make restart NAME=x  - Stop and restart the container"
	@echo "  make status          - Show all claude-code container statuses"
	@echo "  make logs   NAME=x   - Show container logs"
	@echo "  make clean           - Remove all claude-code containers and image"
	@echo ""

build:
	docker build -t claudecode:latest -f claudecode.dockerfile . --no-cache

run:
	@bash code.sh

exec:
	@[ -n "$(NAME)" ] || (echo "Error: NAME is required. Usage: make exec NAME=<container-suffix>"; exit 1)
	docker exec -it $(CONTAINER) claude

start:
	@bash code.sh

shell:
	@[ -n "$(NAME)" ] || (echo "Error: NAME is required. Usage: make shell NAME=<container-suffix>"; exit 1)
	docker exec -it $(CONTAINER) /bin/bash

stop:
	@[ -n "$(NAME)" ] || (echo "Error: NAME is required. Usage: make stop NAME=<container-suffix>"; exit 1)
	docker stop $(CONTAINER)

restart: stop run

status:
	@docker ps --filter "label=project=claude-code"

logs:
	@[ -n "$(NAME)" ] || (echo "Error: NAME is required. Usage: make logs NAME=<container-suffix>"; exit 1)
	docker logs -f $(CONTAINER)

clean:
	@docker ps -q --filter "label=project=claude-code" | xargs -r docker stop
	@docker ps -aq --filter "label=project=claude-code" | xargs -r docker rm
	@docker stop ai-dev-ui-1 2>/dev/null || true
	@docker stop ai-dev-db-1 2>/dev/null || true
	@docker rmi claudecode:latest 2>/dev/null || true
	@echo "Cleanup complete"

