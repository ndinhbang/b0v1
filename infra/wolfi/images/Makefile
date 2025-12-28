# =============================================================================
# Wolfi Images Makefile - apko-based Container Image Building
# =============================================================================
# This Makefile provides targets for building OCI container images using apko.
#
# Common usage:
#   make image name=laravel tag=latest-dev   # Build image
#   make download-image name=laravel         # Download packages for offline build
#   make gen-apkindex                        # Generate APKINDEX from downloaded packages
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

# --- TOOL VALIDATION ---
# Check if required tools are available
APKO ?= $(shell which apko)
ifeq ($(APKO),)
$(error apko is not installed or not in PATH. Install from: https://github.com/chainguard-dev/apko)
endif

# --- DEFAULT VARIABLES ---

# Host directory (on your local machine) - where apko config files are located
IMAGES_DIR ?= /work/os
OUT_DIR ?= /work/out
IMAGE_CACHE_DIR ?= /work/out/.cache

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
.PHONY: validate-params
validate-params:
	@test -n "$(name)" || (echo "Error: name= is required (e.g., name=laravel)"; exit 1)
	@test -n "$(tag)" || (echo "Error: tag= is required (e.g., tag=latest-dev)"; exit 1)
	@test -f "$(IMAGES_DIR)/$(name)/$(tag).apko.yaml" || \
		(echo "Error: Config file not found: $(IMAGES_DIR)/$(name)/$(tag).apko.yaml"; exit 1)

# =============================================================================
# Build Targets
# =============================================================================

# Generate a lock file for the specified apko YAML configuration
# Lock files ensure reproducible builds by pinning package versions
.PHONY: lock
lock: validate-params
	$(eval cache := 0)
	@echo "Generating lock file for $(name):$(tag)..."
	mkdir -p $(OUT_DIR)/$(name)/$(tag) && \
	$(APKO) lock $(IMAGES_DIR)/$(name)/$(tag).apko.yaml \
		--log-level $(log_level) \
		--workdir $(OUT_DIR)/$(name) \
		--output $(OUT_DIR)/$(name)/$(tag)/apko.lock.json \
		$(if $(filter 1,$(cache)),--cache-dir $(IMAGE_CACHE_DIR),)
	@echo "✓ Lock file generated at $(OUT_DIR)/$(name)/$(tag)/apko.lock.json"

# Build a minimal root filesystem using apko
# Useful for creating base images without full OCI image layers
.PHONY: rootfs
rootfs: validate-params
	@echo "Building minimal rootfs for $(name):$(tag)..."
	mkdir -p $(OUT_DIR)/$(name)/$(tag) && \
	$(APKO) build-minirootfs $(IMAGES_DIR)/$(name)/$(tag).apko.yaml $(OUT_DIR)/$(name)/$(tag)/minirootfs.tar.gz \
		--build-arch $(arch) \
		--workdir $(OUT_DIR)/$(name) \
		--log-level $(log_level)
	@echo "✓ Minimal rootfs generated at $(OUT_DIR)/$(name)/$(tag)/minirootfs.tar.gz"

# Build a container image using apko
# This is the main target for building complete OCI images
.PHONY: image
image: validate-params
	$(eval offline := 0)
	$(eval cache := 0)
	@echo "Building image $(registry)/$(name):$(tag)..."
	mkdir -p $(OUT_DIR)/$(name)/$(tag) && \
	$(APKO) build $(IMAGES_DIR)/$(name)/$(tag).apko.yaml $(registry)/$(name):$(tag) $(OUT_DIR)/$(name)/$(tag)/image.tar \
		--log-level $(log_level) \
		--workdir $(OUT_DIR)/$(name) \
		--sbom-path $(OUT_DIR)/$(name)/$(tag) \
		--lockfile $(OUT_DIR)/$(name)/$(tag)/apko.lock.json \
		$(if $(filter 1,$(cache)),--cache-dir $(IMAGE_CACHE_DIR),) \
		$(if $(filter 1,$(offline)),--offline,)
	@echo "✓ Image built successfully: $(registry)/$(name):$(tag)"
	@echo "  - Tarball: $(OUT_DIR)/$(name)/$(tag)/image.tar"
	@echo "  - SBOM: $(OUT_DIR)/$(name)/$(tag)/"

# Show the packages included in the apko YAML configuration
# Useful for debugging and understanding what will be installed
.PHONY: show-packages
show-packages: validate-params
	$(eval offline := 0)
	$(eval cache := 0)
	@echo "Packages for $(name):$(tag):"
	$(APKO) show-packages $(IMAGES_DIR)/$(name)/$(tag).apko.yaml \
		--arch $(arch) \
		--workdir $(OUT_DIR)/$(name) \
		--log-level $(log_level) \
		--format "packagelock-source" \
		$(if $(filter 1,$(cache)),--cache-dir $(IMAGE_CACHE_DIR),) \
		$(if $(filter 1,$(offline)),--offline,)

# Perform the full build process: lock, image, and load
.PHONY: build
build: lock image ## Generate lock file and build image

# Tag and push the image to the Docker registry
.PHONY: publish
publish: lock validate-params
	$(eval local := 0)
	$(eval offline := 0)
	$(eval cache := 0)
	@echo "Publishing image $(registry)/$(name):$(tag)..."
	$(APKO) publish $(IMAGES_DIR)/$(name)/$(tag).apko.yaml $(registry)/$(name):$(tag) $(registry_backup)/$(name):$(tag) \
		--workdir $(OUT_DIR)/$(name) \
		--log-level $(log_level) \
		--lockfile $(OUT_DIR)/$(name)/$(tag)/apko.lock.json \
		--image-refs $(OUT_DIR)/$(name)/$(tag)/.digests \
		$(if $(filter 1,$(cache)),--cache-dir $(IMAGE_CACHE_DIR),) \
		$(if $(filter 1,$(offline)),--offline,) \
		$(if $(filter 1,$(local)),--local,) ; \
	@echo "✓ Image published to:"
	@echo "  - $(registry)/$(name):$(tag)"
	@echo "  - $(registry_backup)/$(name):$(tag)"

# =============================================================================
# Offline Build Support
# =============================================================================

# Download packages for offline builds
# Usage: make download-image name=laravel tag=latest-dev
# This downloads all required packages to build the image without internet access
.PHONY: download-image
download-image: validate-params
	$(eval apko-path := $(IMAGES_DIR)/$(name)/$(tag).apko.yaml)
	$(eval offline := 0)
	$(eval cache := 0)
	$(eval arch := $(shell uname -m | sed 's/amd64/x86_64/;s/arm64/aarch64/'))
	@echo "=== Downloading packages for $(name):$(tag) ==="
	@echo "Architecture: $(arch)"
	@echo "Config: $(apko-path)"
	@echo "Target: $(OUT_DIR)/packages/$(arch)"
	@echo ""
	@echo "Updating package index..."
	apk update
	@echo "Extracting package list..."
	mkdir -p $(OUT_DIR)/packages/$(arch) && \
	$(APKO) show-packages $(apko-path) \
		--arch $(arch) \
		--workdir $(OUT_DIR)/$(name) \
		--log-level $(log_level) \
		--format "packagelock-source" \
		$(if $(filter 1,$(cache)),--cache-dir $(IMAGE_CACHE_DIR),) \
		$(if $(filter 1,$(offline)),--offline,) | \
		sed 's/^- \([^=]*\)=.*/\1/' | \
		xargs apk fetch \
			--repositories-file /etc/apk/repositories \
			--output $(OUT_DIR)/packages/$(arch) \
			--recursive
	@echo ""
	@echo "✓ Packages downloaded to: $(OUT_DIR)/packages/$(arch)"
	@echo "  Run 'make gen-apkindex' to generate the package index"

# Generate APKINDEX from downloaded packages
# This creates a local package repository that can be used for offline builds
.PHONY: gen-apkindex
gen-apkindex:
	$(eval arch := $(shell uname -m | sed 's/amd64/x86_64/;s/arm64/aarch64/'))
	@echo "=== Generating APKINDEX ==="
	@echo "Architecture: $(arch)"
	@echo "Directory: $(OUT_DIR)/packages/$(arch)"
	@echo ""
	@if [ ! -d $(OUT_DIR)/packages/$(arch) ] || [ -z "$$(ls -A $(OUT_DIR)/packages/$(arch)/*.apk 2>/dev/null)" ]; then \
		echo "✗ Error: No APK files found in $(OUT_DIR)/packages/$(arch)"; \
		echo "  Please run 'make download-image name=<name> tag=<tag>' first"; \
		exit 1; \
	fi
	@echo "Step 1/3: Verifying APK packages..."
	@count=0; \
	for apk in $(OUT_DIR)/packages/$(arch)/*.apk; do \
		if [ -f "$$apk" ]; then \
			count=$$((count + 1)); \
			printf "  [%d] %s ... " "$$count" "$$(basename $$apk)"; \
			if apk verify "$$apk" >/dev/null 2>&1; then \
				echo "✓"; \
			else \
				echo "✗ FAILED"; \
				echo ""; \
				echo "✗ Verification failed for $$apk"; \
				exit 1; \
			fi; \
		fi; \
	done; \
	echo "  ✓ All $$count packages verified successfully"
	@echo ""
	@echo "Step 2/3: Generating APKINDEX..."
	@melange index --output $(OUT_DIR)/packages/$(arch)/APKINDEX.tar.gz $(OUT_DIR)/packages/$(arch)/*.apk && \
		echo "  ✓ APKINDEX generated"
	@echo ""
	@echo "Step 3/3: Signing APKINDEX..."
	@melange sign-index --signing-key /etc/apk/keys/local-melange.rsa $(OUT_DIR)/packages/$(arch)/APKINDEX.tar.gz && \
		echo "  ✓ APKINDEX signed"
	@echo ""
	@echo "✓ Complete! Local package repository ready at:"
	@echo "  $(OUT_DIR)/packages/$(arch)/APKINDEX.tar.gz"
	@echo ""
	@echo "You can now use this for offline builds by configuring your apko.yaml"
	@echo "to use the local repository: $(OUT_DIR)/packages/$(arch)"
