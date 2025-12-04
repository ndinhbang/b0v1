# Makefile shortcuts for Docker Compose environments
# Usage:
#   make dev   # Start development environment
#   make prod  # Start production environment
#
# This Makefile provides shortcuts to quickly start development or production
# environments using Docker Compose. You can also add other targets as needed
# (e.g., stop, restart, logs).
APKO_IMAGE=cgr.dev/chainguard/apko@sha256:e8a0f222ebea23f37eb22cd86f7bff4837c7ec0c07bb6d6828888ee5ab4c5126

.PHONY: dev prod wolfi apko digests

# Start development environment using compose.dev.yml
# Includes hot reload, dev servers, and local volumes
dev:
	docker compose -f compose.dev.yml up --build

# Start production environment using compose.yml
# Builds optimized images, runs with production settings
prod:
	docker compose up --build

wolfi:
	docker run -it --pull=always cgr.dev/chainguard/wolfi-base

apko:
	docker run --rm $(APKO_IMAGE) version

digests:
	docker images --digests > docker-images.txt
