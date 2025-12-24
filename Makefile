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

# Remove all unused Docker data (containers, images, volumes, etc.)
.PHONY: prune-all
prune-all:
	docker system prune -af && docker volume prune -af

# List all Docker images with their digests and save to digests.txt
.PHONY: digests
digests:
	docker images --digests > digests.txt

# Run the Wolfi base image interactively
.PHONY: wolfi
wolfi:
	docker run -it --rm --pull=always cgr.dev/chainguard/wolfi-base

# Run the apko image and display its version
.PHONY: apko
apko:
	docker run --rm --pull=always cgr.dev/chainguard/apko version

# Run the melange image and display its version
.PHONY: melange
melange:
	docker run --rm --pull=always cgr.dev/chainguard/melange version

# Run the Wolfi SDK image
.PHONY: sdk
sdk:
	docker run --rm --pull=always ghcr.io/wolfi-dev/sdk

# Run the crane image and display its version
.PHONY: crane
crane:
	docker run --rm --pull=always cgr.dev/chainguard/crane version

# Run the Chainguard Laravel image interactively
.PHONY: laravel
laravel:
	docker run -it --rm --pull=always cgr.dev/chainguard/laravel:latest-dev

# Run the Chainguard Nginx image interactively
.PHONY: nginx
nginx:
	docker run -it --rm --pull=always cgr.dev/chainguard/nginx:latest-dev


# Load the built image tarball into Docker
.PHONY: load
load:
	docker load -i $(IMAGES_DIR)/$(name)/$(tag)/image.tar

# Analyze the built image using dive
.PHONY: dive
dive:
	$(eval image := $(registry)/$(name):$(tag))
	docker run --rm -it --pull=always \
  		-v /var/run/docker.sock:/var/run/docker.sock \
		--group-add $(shell getent group docker | cut -d: -f3) \
  		cgr.dev/chainguard/dive:latest $(image)

# Show the filesystem contents of the built image
.PHONY: show-fs
show-fs:
	$(eval image := $(registry)/$(name):$(tag))
	crane export $(image) - | tar -tvf -


.PHONY: run
run:
	docker run -it --rm $(registry)/$(name):$(tag)

# Run tests for the built image
.PHONY: test
test:
	./images/$(name)/tests/run.sh $(registry)/$(name):$(tag)

############################################################################
# Building Wolfi packages and images
############################################################################
ARCH ?= $(shell uname -m)
ROOT_DIR := $(shell pwd)
WOLFI_DIR := ${ROOT_DIR}/infra/wolfi
IMAGES_DIR := ${WOLFI_DIR}/images
IMAGE_CACHE_DIR ?= ${IMAGES_DIR}/.cache
OS_DIR := ${WOLFI_DIR}/os
REPO := ${OS_DIR}/packages

include infra/wolfi/Makefile
include infra/wolfi/os/Makefile
# include infra/wolfi/images/Makefile


