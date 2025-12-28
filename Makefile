# =============================================================================
# Main Makefile - Docker Compose & Wolfi Build System
# =============================================================================
# This Makefile provides shortcuts for:
#   - Docker Compose environments (dev/prod)
#   - Wolfi OS package and image building
#   - Container management and testing
#
# Quick Start:
#   make help          # Show all available commands
#   make dev           # Start development environment
#   make dev-container-wolfi  # Enter Wolfi build container
# =============================================================================

.DEFAULT_GOAL := help

# =============================================================================
# Help Target - Display all available make commands
# =============================================================================
.PHONY: help
help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*##"; printf "\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-25s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
	@if [ -f "infra/wolfi/images/Makefile" ]; then \
		echo ''; \
		echo '\033[1mWolfi Images (infra/wolfi/images/):\033[0m'; \
		awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_\/-]+:.*?##/ { printf "  \033[36m%-25s\033[0m %s\n", $$1, $$2 }' infra/wolfi/images/Makefile; \
		echo ''; \
		echo '  \033[2mUsage: make -C infra/wolfi/images <target> name=<name> tag=<tag>\033[0m'; \
		echo '  \033[2mExample: make -C infra/wolfi/images image/build name=laravel tag=latest-dev\033[0m'; \
	fi
	@if [ -f "infra/wolfi/os/Makefile" ]; then \
		echo ''; \
		echo '\033[1mWolfi OS Packages (infra/wolfi/os/):\033[0m'; \
		awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_\/-][a-zA-Z0-9_\/-]*:.*?##/ { printf "  \033[36m%-25s\033[0m %s\n", $$1, $$2 } /[a-zA-Z_\/-][a-zA-Z0-9_\/-]*\/%:.*?##/ { match($$0, /[a-zA-Z_\/-][a-zA-Z0-9_\/-]*\/%/); target = substr($$0, RSTART, RLENGTH); printf "  \033[36m%-25s\033[0m %s\n", target, $$2 }' infra/wolfi/os/Makefile; \
		echo ''; \
		echo '  \033[2mUsage: make -C infra/wolfi/os <target>\033[0m'; \
		echo '  \033[2mExample: make -C infra/wolfi/os package/php\033[0m'; \
	fi

##@ Docker Compose Environments

# Start development environment using compose.dev.yml
# Includes hot reload, dev servers, and local volumes
.PHONY: dev
dev: ## Start development environment with hot reload
	docker compose -f compose.dev.yml up --build

# Start production environment using compose.yml
# Builds optimized images, runs with production settings
.PHONY: prod
prod: ## Start production environment
	docker compose up --build

# Remove all unused Docker data (containers, images, volumes, etc.)
.PHONY: prune-all
prune-all: ## Clean up all Docker resources (images, containers, volumes)
	docker system prune -af && docker volume prune -af

# List all Docker images with their digests and save to digests.txt
.PHONY: digests
digests: ## List all Docker images with digests
	docker images --digests > digests.txt

##@ Wolfi & Chainguard Images

# Run the Wolfi base image interactively
.PHONY: wolfi
wolfi: ## Run Wolfi base image interactively
	docker run -it --rm --pull=always cgr.dev/chainguard/wolfi-base

# Run the apko image and display its version
.PHONY: apko
apko: ## Show apko version
	docker run --rm --pull=always cgr.dev/chainguard/apko version

# Run the melange image and display its version
.PHONY: melange
melange: ## Show melange version
	docker run --rm --pull=always cgr.dev/chainguard/melange version

# Run the Wolfi SDK image
.PHONY: sdk
sdk: ## Run Wolfi SDK image
	docker run --rm --pull=always ghcr.io/wolfi-dev/sdk

# Run the crane image and display its version
.PHONY: crane
crane: ## Show crane version
	docker run --rm --pull=always cgr.dev/chainguard/crane version

# Run the Chainguard Laravel image interactively
.PHONY: laravel
laravel: ## Run Laravel image interactively
	docker run -it --rm --pull=always cgr.dev/chainguard/laravel:latest-dev

# Run the Chainguard Nginx image interactively
.PHONY: nginx
nginx: ## Run Nginx image interactively
	docker run -it --rm --pull=always cgr.dev/chainguard/nginx:latest-dev

##@ Image Testing & Analysis

# Load the built image tarball into Docker
.PHONY: load
load: ## Load built image tarball into Docker (requires name= and tag=)
	@test -n "$(name)" || (echo "Error: name= is required"; exit 1)
	@test -n "$(tag)" || (echo "Error: tag= is required"; exit 1)
	docker load -i $(IMAGES_DIR)/$(name)/$(tag)/image.tar

# Analyze the built image using dive
.PHONY: dive
dive: ## Analyze image with dive tool (requires name= and tag=)
	@test -n "$(name)" || (echo "Error: name= is required"; exit 1)
	@test -n "$(tag)" || (echo "Error: tag= is required"; exit 1)
	$(eval image := $(registry)/$(name):$(tag))
	docker run --rm -it --pull=always \
  		-v /var/run/docker.sock:/var/run/docker.sock \
		--group-add $(shell getent group docker | cut -d: -f3) \
  		cgr.dev/chainguard/dive:latest $(image)

# Show the filesystem contents of the built image
.PHONY: show-fs
show-fs: ## Show filesystem contents of image (requires name= and tag=)
	@test -n "$(name)" || (echo "Error: name= is required"; exit 1)
	@test -n "$(tag)" || (echo "Error: tag= is required"; exit 1)
	$(eval image := $(registry)/$(name):$(tag))
	crane export $(image) - | tar -tvf -

.PHONY: run
run: ## Run image interactively (requires name= and tag=)
	@test -n "$(name)" || (echo "Error: name= is required"; exit 1)
	@test -n "$(tag)" || (echo "Error: tag= is required"; exit 1)
	docker run -it --rm $(registry)/$(name):$(tag)

# Run tests for the built image
.PHONY: test
test: ## Run tests for image (requires name= and tag=)
	@test -n "$(name)" || (echo "Error: name= is required"; exit 1)
	@test -n "$(tag)" || (echo "Error: tag= is required"; exit 1)
	@test -f ./images/$(name)/tests/run.sh || (echo "Error: Test script not found"; exit 1)
	./images/$(name)/tests/run.sh $(registry)/$(name):$(tag)

############################################################################
# Building Wolfi packages and images
############################################################################

# =============================================================================
# Architecture & Platform Configuration
# =============================================================================
ARCH ?= $(shell uname -m)
# Normalize ARM architecture names
ifeq (${ARCH}, arm64)
	ARCH = aarch64
endif

# Configure melange cache directory
ifeq (${TMPDIR}, )
    CACHEDIR = /tmp/melange-cache
else
    CACHEDIR = ${TMPDIR}/melange-cache
endif

# Tool paths
MELANGE ?= $(shell which melange)
WOLFICTL ?= $(shell which wolfictl)

# =============================================================================
# Git & Build Reproducibility
# =============================================================================
GIT_DIR := $(shell git rev-parse --show-toplevel 2>/dev/null || pwd)
SOURCE_DATE_EPOCH := $(shell git -C $(GIT_DIR) --no-pager log -1 --pretty=%ct || echo no-git)
ifeq ($(SOURCE_DATE_EPOCH),no-git)
$(error setting SOURCE_DATE_EPOCH failed - $(SOURCE_DATE_EPOCH))
endif
export SOURCE_DATE_EPOCH

# Docker platform argument based on architecture
DOCKER_PLATFORM_ARG := $(shell \
  case $(ARCH) in \
	(aarch64) darch=arm64;; \
	(x86_64) darch=amd64;; \
	(*) echo "unknown-docker-platform-arch-$(ARCH)"; exit 1;; \
  esac ; \
  echo "--platform=linux/$$darch" \
)

# =============================================================================
# Directory Configuration
# =============================================================================
ROOT_DIR := $(shell pwd)
WOLFI_DIR := ${ROOT_DIR}/infra/wolfi

# Host directories (on your local machine)
HOST_IMAGES_DIR := ${WOLFI_DIR}/images
HOST_OS_DIR := ${WOLFI_DIR}/os
HOST_OUT_DIR := ${WOLFI_DIR}/artifacts
HOST_PACKAGES_OUT_DIR := ${HOST_OUT_DIR}/packages
HOST_IMAGES_OUT_DIR := ${HOST_OUT_DIR}/images
KEY ?= local-melange.rsa
REPO := ${HOST_OS_DIR}/packages

# Container directories (inside Docker container)
CONTAINER_OUT_DIR := /work/out
CONTAINER_OS_DIR := /work/os
CONTAINER_PACKAGES_DIR := /work/packages
IMAGE_CACHE_DIR ?= ${CONTAINER_OUT_DIR}/.cache

# Backward compatibility aliases (deprecated, use HOST_* and CONTAINER_* instead)
IMAGES_DIR := ${HOST_IMAGES_DIR}
OS_DIR := ${HOST_OS_DIR}
OUT_DIR := ${HOST_OUT_DIR}
OUT_LOCAL_DIR := ${CONTAINER_OUT_DIR}
OS_LOCAL_DIR := ${CONTAINER_OS_DIR}
PACKAGES_CONTAINER_FOLDER := ${CONTAINER_PACKAGES_DIR}
USE_CACHE ?= no

# =============================================================================
# Wolfi Development Containers
# =============================================================================

##@ Wolfi Development Containers

# Generate melange signing key if it doesn't exist
.PHONY: keygen
keygen: ## Generate melange signing key
	@if [ -f "${HOST_OS_DIR}/${KEY}" ] && [ -f "${HOST_OS_DIR}/${KEY}.pub" ]; then \
		echo "\033[1;36mINFO:\033[0m Skipping keygen, ${HOST_OS_DIR}/${KEY} existed"; \
	else \
		mkdir -p "${HOST_OS_DIR}"; \
		${MELANGE} keygen "${HOST_OS_DIR}/${KEY}"; \
	fi

# Enter Wolfi SDK container for OS package development
.PHONY: dev-container
dev-container: ## Enter Wolfi SDK container for package development
	docker run $(DOCKER_PLATFORM_ARG) --pull=always --privileged --rm -it \
		--entrypoint="/bin/bash" \
	    -v "${HOST_OS_DIR}:${HOST_OS_DIR}" \
		-v "${HOST_PACKAGES_OUT_DIR}:${HOST_OS_DIR}/packages" \
		--mount type=bind,source="${ROOT_DIR}/.git",destination="${HOST_OS_DIR}/.git",readonly \
		-v /tmp:/tmp \
		-v /var/run/docker.sock:/var/run/docker.sock \
	    -w "${HOST_OS_DIR}" \
	    -e SOURCE_DATE_EPOCH=$(SOURCE_DATE_EPOCH) \
	    -e HTTP_AUTH \
	    ghcr.io/wolfi-dev/sdk:latest -il

# Test local packages in Wolfi base container
.PHONY: local-wolfi
local-wolfi: keygen ## Test local packages in Wolfi base container
	mkdir -p "${HOST_OS_DIR}/packages"
	$(eval TMP_REPOS_DIR := $(shell mktemp --tmpdir -d "$@.XXXXXX"))
	$(eval TMP_REPOS_FILE := $(TMP_REPOS_DIR)/repositories)
	echo "https://packages.wolfi.dev/os" > $(TMP_REPOS_FILE)
	echo "$(CONTAINER_PACKAGES_DIR)" >> $(TMP_REPOS_FILE)
ifneq ($(LOCAL_WOLFI_EXTRA_REPO),)
	echo "$(LOCAL_WOLFI_EXTRA_REPO)" >> $(TMP_REPOS_FILE)
endif
	docker run $(DOCKER_PLATFORM_ARG) --pull=always --rm -it \
		--entrypoint="/bin/sh" \
		--mount type=bind,source="${HOST_PACKAGES_OUT_DIR}",destination="$(CONTAINER_PACKAGES_DIR)",readonly \
		--mount type=bind,source="${HOST_OS_DIR}/$(KEY).pub",destination="/etc/apk/keys/$(KEY).pub",readonly \
		--mount type=bind,source="$(TMP_REPOS_FILE)",destination="/etc/apk/repositories",readonly \
		-w "$(CONTAINER_PACKAGES_DIR)" \
		cgr.dev/chainguard/wolfi-base:latest -il
	rm "$(TMP_REPOS_FILE)"
	rmdir "$(TMP_REPOS_DIR)"

# Enter Wolfi SDK container for building images with apko
# This is the main container for building OCI images
# Usage: make dev-container-wolfi [HOST_OUT_DIR=/path/to/output]
.PHONY: dev-container-wolfi
dev-container-wolfi: keygen ## Enter Wolfi SDK container for building images (main build environment)
	$(eval TMP_REPOS_DIR := $(shell mktemp --tmpdir -d "$@.XXXXXX"))
	$(eval TMP_REPOS_FILE := $(TMP_REPOS_DIR)/repositories)
	$(eval HOST_OUT_DIR ?= $(shell echo $${HOST_OUT_DIR:-$$(mktemp --tmpdir -d "$@-out.XXXXXX")}))
	@echo "=== Starting Wolfi Build Container ==="
	@echo "Host output directory: ${HOST_OUT_DIR}"
	@echo "Container output directory: $(CONTAINER_OUT_DIR)"
	@echo ""
	echo "https://packages.wolfi.dev/os" > $(TMP_REPOS_FILE)
	echo "$(CONTAINER_PACKAGES_DIR)" >> $(TMP_REPOS_FILE)
ifneq ($(LOCAL_WOLFI_EXTRA_REPO),)
	echo "$(LOCAL_WOLFI_EXTRA_REPO)" >> $(TMP_REPOS_FILE)
endif
	docker run $(DOCKER_PLATFORM_ARG) --pull=always --rm -it \
		--entrypoint="/bin/bash" \
		--mount type=bind,source="${HOST_IMAGES_OUT_DIR}",destination="$(CONTAINER_OUT_DIR)" \
		--mount type=bind,source="${HOST_IMAGES_DIR}",destination="$(CONTAINER_OS_DIR)",readonly \
		--mount type=bind,source="${HOST_PACKAGES_OUT_DIR}",destination="$(CONTAINER_PACKAGES_DIR)",readonly \
		--mount type=bind,source="${HOST_OS_DIR}/$(KEY).pub",destination="/etc/apk/keys/$(KEY).pub",readonly \
		--mount type=bind,source="$(TMP_REPOS_FILE)",destination="/etc/apk/repositories",readonly \
		-w "$(CONTAINER_OS_DIR)" \
		ghcr.io/wolfi-dev/sdk:latest -il
	rm "$(TMP_REPOS_FILE)"
	rmdir "$(TMP_REPOS_DIR)"

