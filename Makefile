# Project Variables
PROJECT_NAME ?= blender_mcp_sandbox
BLENDER_VERSION ?= 5.2.2
MCP_VERSION ?= 1.0.3
DISPLAY_SERVER ?= wayland
WORKSPACE_DIR ?= ./project_data

# Auto-detect Container Engine (Podman preferred, fallback to Docker)
CONTAINER_ENGINE ?= $(shell command -v podman 2>/dev/null || command -v docker 2>/dev/null)
COMPOSE_ENGINE   ?= $(shell command -v podman-compose 2>/dev/null || echo "$(CONTAINER_ENGINE) compose")

# Compose Command Wrapper
COMPOSE_CMD := COMPOSE_PROJECT_NAME=$(PROJECT_NAME) $(COMPOSE_ENGINE)

.DEFAULT_GOAL := help
.PHONY: up down rebuild ps purge audit help shell

#@ Environment & Container Management

## Spin up the Blender environment in background mode (via podman-compose)
up:
	@echo "--> Starting $(PROJECT_NAME) in $(DISPLAY_SERVER) mode..."
	@xhost +local: > /dev/null 2>&1 || true
	BLENDER_VERSION=$(BLENDER_VERSION) DISPLAY_SERVER=$(DISPLAY_SERVER) $(COMPOSE_CMD) up -d
	$(MAKE) audit

## Stop and remove running project containers
down:
	@echo "--> Stopping $(PROJECT_NAME)..."
	$(COMPOSE_CMD) down

## Stop containers and force a clean image rebuild without cache
rebuild: down
	@echo "--> Rebuilding $(PROJECT_NAME) image from scratch (no cache)..."
	BLENDER_VERSION=$(BLENDER_VERSION) DISPLAY_SERVER=$(DISPLAY_SERVER) $(COMPOSE_CMD) build --no-cache
	$(MAKE) up

## Display container execution status for this project
ps:
	@echo "--> Running containers for $(PROJECT_NAME):"
	podman ps --filter "label=io.podman.compose.project=$(PROJECT_NAME)"

#@ Development & Debugging

## Open an interactive bash shell inside the running container
shell:
	@echo "--> Entering interactive shell in $(PROJECT_NAME)..."
	podman exec -it $(PROJECT_NAME) /bin/bash

#@ Maintenance & Cleanup

## Deep purge dangling images, build cache, and stopped container states
purge: down
	@echo "--> Executing full system purge in Podman..."
	podman system prune -a --volumes -f
	podman builder prune --all -f
	@echo "[OK] System storage purged successfully."

#@ Diagnostics & Help

## Perform a quick containerized GPU hardware acceleration audit
audit:
	@echo "--> Auditing GPU acceleration inside the container..."
	@podman exec -it $(PROJECT_NAME) blender --background --python-expr "\
import gpu, bpy; \
gpu.init(); \
print('\n' + '='*50); \
print(' [PODMAN GPU AUDIT]'); \
print(' Blender Version :', bpy.app.version_string); \
print(' GPU Vendor      :', gpu.platform.vendor_get()); \
print(' GPU Renderer    :', gpu.platform.renderer_get()); \
print('='*50 + '\n')"

## Display this dynamic help menu by parsing Makefile comments
help:
	@echo "Usage: make [target] [VARIABLES...]"
	@echo ""
	@echo "Configurable Variables:"
	@echo "  PROJECT_NAME     Compose project scope (Default: $(PROJECT_NAME))"
	@echo "  DISPLAY_SERVER   Display protocol: wayland | x11 (Default: $(DISPLAY_SERVER))"
	@echo "  BLENDER_VERSION  Target Blender binary version (Default: $(BLENDER_VERSION))"
	@echo ""
	@awk '/^#@/ { print "\n\033[1;33m" substr($$0, 4) "\033[0m" } \
		/^##/ { helpMsg = substr($$0, 4) } \
		/^[a-zA-Z_-]+:/ { \
			if (helpMsg) { \
				printf "  \033[36m%-15s\033[0m %s\n", $$1, helpMsg; \
				helpMsg = "" \
			} \
		}' $(MAKEFILE_LIST) | sed 's/://'
	@echo ""
