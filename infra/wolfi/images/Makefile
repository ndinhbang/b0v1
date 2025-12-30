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
IMAGES_DIR ?= /work/os
OUT_DIR ?= /work/out
IMAGE_CACHE_DIR ?= /work/out/.cache
PACKAGES_DIR ?= /work/packages

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
	mkdir -p $(OUT_DIR)/$(name)/$(tag) && \
	$(APKO) lock $(IMAGES_DIR)/$(name)/$(tag).apko.yaml \
		--log-level $(log_level) \
		--workdir $(OUT_DIR)/$(name) \
		--output $(OUT_DIR)/$(name)/$(tag)/apko.lock.json \
		$(if $(filter 1,$(cache)),--cache-dir $(IMAGE_CACHE_DIR),)
	@echo "✓ Lock file generated at $(OUT_DIR)/$(name)/$(tag)/apko.lock.json"

# Build a minimal root filesystem using apko
# Useful for creating base images without full OCI image layers
.PHONY: image/rootfs
image/rootfs: image/validate-params ## Build minimal root filesystem (requires name= tag=)
	@echo "Building minimal rootfs for $(name):$(tag)..."
	mkdir -p $(OUT_DIR)/$(name)/$(tag) && \
	$(APKO) build-minirootfs $(IMAGES_DIR)/$(name)/$(tag).apko.yaml $(OUT_DIR)/$(name)/$(tag)/minirootfs.tar.gz \
		--build-arch $(arch) \
		--workdir $(OUT_DIR)/$(name) \
		--log-level $(log_level)
	@echo "✓ Minimal rootfs generated at $(OUT_DIR)/$(name)/$(tag)/minirootfs.tar.gz"

# Build a container image using apko
# This is the main target for building complete OCI images
.PHONY: image/image
image/image: image/validate-params ## Build container image (requires name= tag=)
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
.PHONY: image/show-packages
image/show-packages: image/validate-params ## Show packages in apko config (requires name= tag=)
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

# 1. Download Packages
.PHONY: image/download-packages
image/download-packages: image/validate-params ## Download packages & create checksum file
	$(eval apko-path := $(IMAGES_DIR)/$(name)/$(tag).apko.yaml)
	$(eval arch := $(shell uname -m | sed 's/amd64/x86_64/;s/arm64/aarch64/'))
	@echo "=== Downloading packages for $(name):$(tag) ==="
	@echo "Config: $(apko-path)"
	@echo "Target: $(PACKAGES_DIR)/$(arch)"

	@# Step 1: Update index
	@echo "Step 1/4: Updating remote index..."
	@apk update

	@# Step 2: Fetch packages
	@echo "Step 2/4: Fetching packages..."
	@mkdir -p $(PACKAGES_DIR)/$(arch)
	$(APKO) show-packages $(apko-path) --arch $(arch) --format "packagelock-source" | \
		sed 's/^- \([^=]*\)=.*/\1/' | \
		xargs apk fetch --repositories-file /etc/apk/repositories --output $(PACKAGES_DIR)/$(arch) --recursive

	@# Step 3: Generate checksums
	@echo "Step 3/4: Generating checksum file..."
	@cd $(PACKAGES_DIR)/$(arch) && \
		find . -maxdepth 1 -name "*.apk" -type f -exec sha256sum {} \; | sort -k2 > checksum.txt
	@echo "✓ Download complete. Checksum file created at $(PACKAGES_DIR)/$(arch)/checksum.txt"
	@echo "Step 4/4: Generating APKINDEX..."
	$(MAKE) image/gen-apkindex name=$(name) tag=$(tag) arch=$(arch)

# 2. Verify Package Integrity
.PHONY: image/verify-packages
image/verify-packages: ## Verify integrity of downloaded packages using checksum.txt
	$(eval arch := $(shell uname -m | sed 's/amd64/x86_64/;s/arm64/aarch64/'))
	@echo "=== Verifying Package Integrity ==="
	@if [ ! -f "$(PACKAGES_DIR)/$(arch)/checksum.txt" ]; then \
		echo "✗ Error: checksum.txt not found. Run 'make image/download-packages' first."; \
		exit 1; \
	fi
	@cd $(PACKAGES_DIR)/$(arch) && \
		sha256sum -c checksum.txt 2>&1 | \
		awk '/OK$$/ {ok++} /FAILED$$/ {fail++; printf "  ✗ FAILED: %s\n", $$1} END { \
			if(ok>0) print "✓ Verified: " ok " packages"; \
			if(fail>0) { print "✗ Failed: " fail " packages"; exit 1 } \
			else if(ok==0) { print "⚠ No files to verify"; } \
		}'

# 3. Generate APKINDEX
.PHONY: image/gen-apkindex
image/gen-apkindex: image/verify-packages ## Verify packages then generate APKINDEX
	$(eval arch := $(shell uname -m | sed 's/amd64/x86_64/;s/arm64/aarch64/'))
	@echo "=== Generating APKINDEX ==="
	@melange index --output $(PACKAGES_DIR)/$(arch)/APKINDEX.tar.gz $(PACKAGES_DIR)/$(arch)/*.apk
	@melange sign-index --signing-key /etc/apk/keys/local-melange.rsa $(PACKAGES_DIR)/$(arch)/APKINDEX.tar.gz
	@echo "✓ APKINDEX generated at $(PACKAGES_DIR)/$(arch)/APKINDEX.tar.gz"
