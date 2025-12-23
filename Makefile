# Makefile shortcuts for Docker Compose environments
# Usage:
#   make dev   # Start development environment
#   make prod  # Start production environment
#
# This Makefile provides shortcuts to quickly start development or production
# environments using Docker Compose. You can also add other targets as needed
# (e.g., stop, restart, logs).


# Start development environment using compose.dev.yml
# Includes hot reload, dev servers, and local volumes
.PHONY: dev
dev:
	docker compose -f compose.dev.yml up --build

# Start production environment using compose.yml
# Builds optimized images, runs with production settings
.PHONY: prod
prod:
	docker compose up --build


############################################################################
# Below are existing targets for building and managing Wolfi images
############################################################################
include infra/wolfi/Makefile
