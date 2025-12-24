# Makefile for building and managing Wolfi-based images
# Usage:
#   make <target>
# Example:
#   make wolfi          # Run Wolfi base image
#   make build          # Build the laravel image
#   make publish        # Publish the built image to the registry

# --- IMAGE DIGESTS ---
# Predefined image digests for various tools
WOLFI_IMAGE=cgr.dev/chainguard/wolfi-base@sha256:0d8efc73b806c780206b69d62e1b8cb10e9e2eefa0e4452db81b9fa00b1a5175
APKO_IMAGE=cgr.dev/chainguard/apko@sha256:04d478ff9e94a537a5eaddfdff00735a5e797fb46e201fc015355bdaaa77326f
MELANGE_IMAGE=cgr.dev/chainguard/melange@sha256:ab0e53ec9bb1f953141cc699ee9ae19741ff2d52397acf3e337f5998001c856b
SDK_IMAGE=ghcr.io/wolfi-dev/sdk@sha256:5866033aff23f88676d20ced03a4113f24d5957bff60e7e629f54563094c5dfd
CRANE_IMAGE=cgr.dev/chainguard/crane@sha256:19921119ab4aa92e341cee3070039759c6e627913a3de51eb286144e01cad311

# --- DEFAULT VARIABLES ---
# Default values for variables, can be overridden by the user
tag ?= latest-dev
name ?= laravel
IMAGE_CACHE_DIR ?= $(PWD)/.cache
log_level ?= debug
# Detect host architecture (amd64, arm64, etc.)
# Ex: make arch=amd64,arm64)
arch ?= $(shell uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
# Docker registry to push images to (default: Docker Hub)
registry ?= ghcr.io/ndinhbang
registry_backup ?= docker.io/ndinhbang

# --- TARGETS ---
APKO ?= $(shell which apko)
IMAGES_DIR ?= $(PWD)

# Generate a lock file for the specified apko YAML configuration
.PHONY: lock
lock:
	$(eval cache := 0)

	mkdir -p $(IMAGES_DIR)/$(name)/$(tag) && \
	$(APKO) lock $(IMAGES_DIR)/$(name)/$(tag).apko.yaml \
		--log-level $(log_level) \
		--workdir $(IMAGES_DIR)/$(name) \
		--output $(IMAGES_DIR)/$(name)/$(tag)/apko.lock.json \
		$(if $(filter 1,$(cache)),--cache-dir $(IMAGE_CACHE_DIR),)

# Build a minimal root filesystem using apko
.PHONY: rootfs
rootfs:
	mkdir -p $(IMAGES_DIR)/$(name)/$(tag) && \
	$(APKO) build-minirootfs $(IMAGES_DIR)/$(name)/$(tag).apko.yaml $(IMAGES_DIR)/$(name)/$(tag)/minirootfs.tar.gz \
		--build-arch $(arch) \
		--workdir $(IMAGES_DIR)/$(name) \
		--log-level $(log_level)

# Build a container image using apko
.PHONY: image
image:
	$(eval offline := 0)
	$(eval cache := 0)

	mkdir -p $(IMAGES_DIR)/$(name)/$(tag) && \
	$(APKO) build $(IMAGES_DIR)/$(name)/$(tag).apko.yaml $(registry)/$(name):$(tag) $(IMAGES_DIR)/$(name)/$(tag)/image.tar \
		--log-level $(log_level) \
		--workdir $(IMAGES_DIR)/$(name) \
		--sbom-path $(IMAGES_DIR)/$(name)/$(tag) \
		--lockfile $(IMAGES_DIR)/$(name)/$(tag)/apko.lock.json \
		$(if $(filter 1,$(cache)),--cache-dir $(IMAGE_CACHE_DIR),) \
		$(if $(filter 1,$(offline)),--offline,)

# Show the packages included in the apko YAML configuration
.PHONY: show-packages
show-packages:
	$(eval offline := 0)
	$(eval cache := 0)

	$(APKO) show-packages $(IMAGES_DIR)/$(name)/$(tag).apko.yaml \
		--arch $(arch) \
		--workdir $(IMAGES_DIR)/$(name) \
		--log-level $(log_level) \
		--format "{{ .Name }}={{ .Version }}" \
		$(if $(filter 1,$(cache)),--cache-dir $(IMAGE_CACHE_DIR),) \
		$(if $(filter 1,$(offline)),--offline,)

# Perform the full build process: lock, image, and load
.PHONY: build
build: lock image

# Tag and push the image to the Docker registry
.PHONY: publish
publish: lock
	$(eval local := 0)
	$(eval offline := 0)

	$(APKO) publish $(IMAGES_DIR)/$(name)/$(tag).apko.yaml $(registry)/$(name):$(tag) $(registry_backup)/$(name):$(tag) \
		--workdir $(IMAGES_DIR)/$(name) \
		--log-level $(log_level) \
		--lockfile $(IMAGES_DIR)/$(name)/$(tag)/apko.lock.json \
		--image-refs $(IMAGES_DIR)/$(name)/$(tag)/.digests \
		$(if $(filter 1,$(cache)),--cache-dir $(IMAGE_CACHE_DIR),) \
		$(if $(filter 1,$(offline)),--offline,) \
		$(if $(filter 1,$(local)),--local,) ; \



# .PHONY: gen-apkindex
# regen-index:
# 	$(eval arch := $(shell uname -m | sed 's/amd64/x86_64/;s/arm64/aarch64/'))
# 	melange index --output $(PWD)/os/packages/$(arch)/APKINDEX.tar.gz $(PWD)/os/packages/$(arch)/*.apk
# 	melange sign-index --signing-key local-melange.rsa $(PWD)/os/packages/$(arch)/APKINDEX.tar.gz


