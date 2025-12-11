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
cache_dir ?= $(PWD)/.cache
log_level ?= debug
# Detect host architecture (amd64, arm64, etc.)
# Ex: make arch=amd64,arm64)
arch ?= $(shell uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
# Docker registry to push images to (default: Docker Hub)
registry ?= ghcr.io/ndinhbang
registry_backup ?= docker.io/ndinhbang

# --- TARGETS ---

# Remove all unused Docker data (containers, images, volumes, etc.)
.PHONY: clean
clean:
	docker system prune -af && \
	docker volume prune -af

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

# Generate a lock file for the specified apko YAML configuration
.PHONY: lock
lock:
	$(eval cache := 0)

	mkdir -p $(PWD)/apko/$(name)/$(tag) && \
	apko lock $(PWD)/apko/$(name)/$(tag).apko.yaml \
		--log-level $(log_level) \
		--workdir $(PWD)/apko/$(name) \
		--output $(PWD)/apko/$(name)/$(tag)/apko.lock.json \
		$(if $(filter 1,$(cache)),--cache-dir $(cache_dir),)

# Build a minimal root filesystem using apko
.PHONY: rootfs
rootfs:
	mkdir -p $(PWD)/apko/$(name)/$(tag) && \
	apko build-minirootfs $(PWD)/apko/$(name)/$(tag).apko.yaml $(PWD)/apko/$(name)/$(tag)/minirootfs.tar.gz \
		--build-arch $(arch) \
		--workdir $(PWD)/apko/$(name) \
		--log-level $(log_level)

# Build a container image using apko
.PHONY: image
image:
	$(eval offline := 0)
	$(eval cache := 0)

	mkdir -p $(PWD)/apko/$(name)/$(tag) && \
	apko build $(PWD)/apko/$(name)/$(tag).apko.yaml $(registry)/$(name):$(tag) $(PWD)/apko/$(name)/$(tag)/image.tar \
		--log-level $(log_level) \
		--workdir $(PWD)/apko/$(name) \
		--sbom-path $(PWD)/apko/$(name)/$(tag) \
		--lockfile $(PWD)/apko/$(name)/$(tag)/apko.lock.json \
		$(if $(filter 1,$(cache)),--cache-dir $(cache_dir),) \
		$(if $(filter 1,$(offline)),--offline,)

# Show the packages included in the apko YAML configuration
.PHONY: show-packages
show-packages:
	$(eval offline := 0)
	$(eval cache := 0)

	apko show-packages $(PWD)/apko/$(name)/$(tag).apko.yaml \
		--arch $(arch) \
		--workdir $(PWD)/apko/$(name) \
		--log-level $(log_level) \
		--format "{{ .Name }}={{ .Version }}" \
		$(if $(filter 1,$(cache)),--cache-dir $(cache_dir),) \
		$(if $(filter 1,$(offline)),--offline,)

# Load the built image tarball into Docker
.PHONY: load
load:
	docker load -i $(PWD)/apko/$(name)/$(tag)/image.tar

.PHONY: run
run:
	docker run -it --rm $(registry)/$(name):$(tag)

# Run tests for the built image
.PHONY: test
test:
	./apko/$(name)/tests/run.sh $(registry)/$(name):$(tag)

# Perform the full build process: lock, image, and load
.PHONY: build
build: lock image load

# Tag and push the image to the Docker registry
.PHONY: publish
publish: lock
	$(eval local := 0)
	$(eval offline := 0)

	apko publish $(PWD)/apko/$(name)/$(tag).apko.yaml $(registry)/$(name):$(tag) $(registry_backup)/$(name):$(tag) \
		--workdir $(PWD)/apko/$(name) \
		--log-level $(log_level) \
		--lockfile $(PWD)/apko/$(name)/$(tag)/apko.lock.json \
		--image-refs $(PWD)/apko/$(name)/$(tag)/.digests \
		$(if $(filter 1,$(cache)),--cache-dir $(cache_dir),) \
		$(if $(filter 1,$(offline)),--offline,) \
		$(if $(filter 1,$(local)),--local,) ; \

# Show the filesystem contents of the built image
.PHONY: show-fs
show-fs:
	crane export $(registry)/$(name):$(tag) - | tar -tvf -
