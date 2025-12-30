# =============================================================================
# Wolfi Images Makefile - apko-based Container Image Building
# =============================================================================
# This Makefile provides targets for building OCI container images using apko.
#
# Common usage:
#   make image/image name=laravel tag=latest-dev   # Build image
#   make image/download-packages name=laravel         # Download packages for offline build
#   make image/gen-apkindex                        # Generate APKINDEX from downloaded packages
#
# Required parameters for most targets:
#   name  - Image name (e.g., laravel, nginx)
#   tag   - Image tag (e.g., latest-dev, v1.0.0)
#
# Optional parameters:
#   arch       - Target architecture (default: auto-detected)
#   registry   - Docker registry (default: ghcr.io/ndinhbang)
#   log_level  - Log verbosity (default: debug)
#   cache      - Enable cache (0 or 1, default: 0)
#   offline    - Offline mode (0 or 1, default: 0)
# =============================================================================

##@ Wolfi Images
.PHONY: help
help: ## Show this help message
	@echo 'Available targets:'
	@awk '$$0 ~ "^[a-zA-Z_/-][a-zA-Z0-9_/-]*:.*##" { split($$0, a, ": .*## "); printf "  \033[36m%-25s\033[0m %s\n", a[1], a[2] }' $(MAKEFILE_LIST)

# --- TOOL VALIDATION ---
# Check if required tools are available
APKO ?= $(shell which apko)
ifeq ($(APKO),)
$(error apko is not installed or not in PATH. Install from: https://github.com/chainguard-dev/apko)
endif

# --- DEFAULT VARIABLES ---

# Host directory (on your local machine) - where apko config files are located
IMAGES_DIR ?= /work/images
OUT_DIR ?= /work/out
IMAGES_OUT_DIR ?= ${OUT_DIR}/images
IMAGE_CACHE_DIR ?= ${OUT_DIR}/.cache
PACKAGES_OUT_DIR ?= ${OUT_DIR}/packages

# Default values for image building (can be overridden via command line)
# Example: make image name=nginx tag=v1.0 arch=arm64
tag ?= latest-dev
name ?= laravel
log_level ?= debug

# Detect host architecture and convert to Docker/apko format
# x86_64 -> amd64, aarch64 -> arm64
arch ?= $(shell uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')

# Docker registry configuration
registry ?= ghcr.io/ndinhbang
registry_backup ?= docker.io/ndinhbang

# =============================================================================
# Helper Targets
# =============================================================================

# Validate required parameters
.PHONY: image/validate-params
image/validate-params:
	@test -n "$(name)" || (echo "Error: name= is required (e.g., name=laravel)"; exit 1)
	@test -n "$(tag)" || (echo "Error: tag= is required (e.g., tag=latest-dev)"; exit 1)
	@test -f "$(IMAGES_DIR)/$(name)/$(tag).apko.yaml" || \
		(echo "Error: Config file not found: $(IMAGES_DIR)/$(name)/$(tag).apko.yaml"; exit 1)

# =============================================================================
# Build Targets
# =============================================================================

# Generate a lock file for the specified apko YAML configuration
# Lock files ensure reproducible builds by pinning package versions
.PHONY: image/lock
image/lock: image/validate-params ## Generate lock file for reproducible builds (requires name= tag=)
	$(eval cache := 0)
	@echo "Generating lock file for $(name):$(tag)..."
	mkdir -p $(IMAGES_OUT_DIR)/$(name)/$(tag) && \
	$(APKO) lock $(IMAGES_DIR)/$(name)/$(tag).apko.yaml \
		--log-level $(log_level) \
		--workdir $(IMAGES_OUT_DIR)/$(name) \
		--output $(IMAGES_OUT_DIR)/$(name)/$(tag)/apko.lock.json \
		$(if $(filter 1,$(cache)),--cache-dir $(IMAGE_CACHE_DIR),)
	@echo "✓ Lock file generated at $(IMAGES_OUT_DIR)/$(name)/$(tag)/apko.lock.json"

# Build a minimal root filesystem using apko
# Useful for creating base images without full OCI image layers
.PHONY: image/rootfs
image/rootfs: image/validate-params ## Build minimal root filesystem (requires name= tag=)
	@echo "Building minimal rootfs for $(name):$(tag)..."
	mkdir -p $(IMAGES_OUT_DIR)/$(name)/$(tag) && \
	$(APKO) build-minirootfs $(IMAGES_DIR)/$(name)/$(tag).apko.yaml $(IMAGES_OUT_DIR)/$(name)/$(tag)/minirootfs.tar.gz \
		--build-arch $(arch) \
		--workdir $(IMAGES_OUT_DIR)/$(name) \
		--log-level $(log_level)
	@echo "✓ Minimal rootfs generated at $(IMAGES_OUT_DIR)/$(name)/$(tag)/minirootfs.tar.gz"

# Build a container image using apko
# This is the main target for building complete OCI images
.PHONY: image/image
image/image: image/validate-params ## Build container image (requires name= tag=)
	$(eval offline := 0)
	$(eval cache := 0)
	@echo "Building image $(registry)/$(name):$(tag)..."
	mkdir -p $(IMAGES_OUT_DIR)/$(name)/$(tag) && \
	$(APKO) build $(IMAGES_DIR)/$(name)/$(tag).apko.yaml $(registry)/$(name):$(tag) $(IMAGES_OUT_DIR)/$(name)/$(tag)/image.tar \
		--log-level $(log_level) \
		--workdir $(IMAGES_OUT_DIR)/$(name) \
		--sbom-path $(IMAGES_OUT_DIR)/$(name)/$(tag) \
		--lockfile $(IMAGES_OUT_DIR)/$(name)/$(tag)/apko.lock.json \
		$(if $(filter 1,$(cache)),--cache-dir $(IMAGE_CACHE_DIR),) \
		$(if $(filter 1,$(offline)),--offline,)
	@echo "✓ Image built successfully: $(registry)/$(name):$(tag)"
	@echo "  - Tarball: $(IMAGES_OUT_DIR)/$(name)/$(tag)/image.tar"
	@echo "  - SBOM: $(IMAGES_OUT_DIR)/$(name)/$(tag)/"

# Show the packages included in the apko YAML configuration
# Useful for debugging and understanding what will be installed
.PHONY: image/show-packages
image/show-packages: image/validate-params ## Show packages in apko config (requires name= tag=)
	$(eval offline := 0)
	$(eval cache := 0)
	@echo "Packages for $(name):$(tag):"
	$(APKO) show-packages $(IMAGES_DIR)/$(name)/$(tag).apko.yaml \
		--arch $(arch) \
		--workdir $(IMAGES_OUT_DIR)/$(name) \
		--log-level $(log_level) \
		--format "packagelock-source" \
		$(if $(filter 1,$(cache)),--cache-dir $(IMAGE_CACHE_DIR),) \
		$(if $(filter 1,$(offline)),--offline,)

# Perform the full build process: lock, image, and download packages
.PHONY: image/build
image/build: image/lock image/image image/download-packages## Generate lock file and build image

# Tag and push the image to the Docker registry
.PHONY: image/publish
image/publish: image/lock image/validate-params ## Publish image to registry (requires name= tag=)
	$(eval local := 0)
	$(eval offline := 0)
	$(eval cache := 0)
	@echo "Publishing image $(registry)/$(name):$(tag)..."
	$(APKO) publish $(IMAGES_DIR)/$(name)/$(tag).apko.yaml $(registry)/$(name):$(tag) $(registry_backup)/$(name):$(tag) \
		--workdir $(IMAGES_OUT_DIR)/$(name) \
		--log-level $(log_level) \
		--lockfile $(IMAGES_OUT_DIR)/$(name)/$(tag)/apko.lock.json \
		--image-refs $(IMAGES_OUT_DIR)/$(name)/$(tag)/.digests \
		$(if $(filter 1,$(cache)),--cache-dir $(IMAGE_CACHE_DIR),) \
		$(if $(filter 1,$(offline)),--offline,) \
		$(if $(filter 1,$(local)),--local,) ; \
	@echo "✓ Image published to:"
	@echo "  - $(registry)/$(name):$(tag)"
	@echo "  - $(registry_backup)/$(name):$(tag)"

