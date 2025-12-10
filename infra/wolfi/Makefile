
# Makefile for building and managing Wolfi-based images
# Usage:
#   make wolfi          # Run Wolfi base image
#   make apko           # Run apko image
#   make melange       # Run melange image
#   make sdk            # Run Wolfi SDK image
#   make laravel        # Run Chainguard Laravel image
#   make lock           # Generate lock file for laravel.yaml
#   make build-image   # Build the laravel image
#   make load-image    # Load the built laravel image into Docker
#   make test-image    # Test the built laravel image

WOLFI_IMAGE=cgr.dev/chainguard/wolfi-base@sha256:0d8efc73b806c780206b69d62e1b8cb10e9e2eefa0e4452db81b9fa00b1a5175
APKO_IMAGE=cgr.dev/chainguard/apko@sha256:04d478ff9e94a537a5eaddfdff00735a5e797fb46e201fc015355bdaaa77326f
MELANGE_IMAGE=cgr.dev/chainguard/melange@sha256:ab0e53ec9bb1f953141cc699ee9ae19741ff2d52397acf3e337f5998001c856b
SDK_IMAGE=ghcr.io/wolfi-dev/sdk@sha256:5866033aff23f88676d20ced03a4113f24d5957bff60e7e629f54563094c5dfd
CRANE_IMAGE=cgr.dev/chainguard/crane@sha256:19921119ab4aa92e341cee3070039759c6e627913a3de51eb286144e01cad311

# Default variables (can be overridden by user)
tag ?= latest-dev
name ?= laravel
cache_dir ?= $(PWD)/.cache
log_level ?= debug
# Detect host architecture (amd64, arm64, etc.)
# Ex: make arch=amd64,arm64)
arch ?= amd64
registry ?= ghcr.io/ndinhbang

# Clean up Docker system and volumes to free up space. Be careful when using this!
.PHONY: clean
clean:
	docker system prune -af && \
	docker volume prune -af

.PHONY: digests
digests:
	docker images --digests > digests.txt

.PHONY: wolfi
wolfi:
	docker run -it --rm --pull=always cgr.dev/chainguard/wolfi-base

.PHONY: apko
apko:
	docker run --rm --pull=always cgr.dev/chainguard/apko version

.PHONY: melange
melange:
	docker run --rm --pull=always cgr.dev/chainguard/melange version

.PHONY: sdk
sdk:
	docker run --rm --pull=always ghcr.io/wolfi-dev/sdk

.PHONY: crane
crane:
	docker run --rm --pull=always cgr.dev/chainguard/crane version

.PHONY: laravel
laravel:
	docker run -it --rm --pull=always cgr.dev/chainguard/laravel:latest-dev

.PHONY: nginx
nginx:
	docker run -it --rm --pull=always cgr.dev/chainguard/nginx:latest-dev

.PHONY: lock
lock:
	$(eval cache := 0)

	mkdir -p $(PWD)/apko/$(name)/$(tag) && \
	apko lock $(PWD)/apko/$(name)/$(tag).apko.yaml \
		--arch $(arch) \
		--log-level $(log_level) \
		--workdir $(PWD)/apko/$(name) \
		--output $(PWD)/apko/$(name)/$(tag)/apko.lock.json \
		$(if $(filter 1,$(cache)),--cache-dir $(cache_dir),) \

.PHONY: rootfs
rootfs:
	mkdir -p $(PWD)/apko/$(name)/$(tag) && \
	apko build-minirootfs $(PWD)/apko/$(name)/$(tag).apko.yaml $(PWD)/apko/$(name)/$(tag)/minirootfs.tar.gz \
		--build-arch $(arch) \
		--workdir $(PWD)/apko/$(name) \
		--log-level $(log_level) \

.PHONY: image
image:
	$(eval offline := 0)
	$(eval cache := 0)

	mkdir -p $(PWD)/apko/$(name)/$(tag) && \
	apko build $(PWD)/apko/$(name)/$(tag).apko.yaml $(name):$(tag) $(PWD)/apko/$(name)/$(tag)/image.tar \
		--arch $(arch) \
		--log-level $(log_level) \
		--workdir $(PWD)/apko/$(name) \
		--sbom-path $(PWD)/apko/$(name)/$(tag) \
		--lockfile $(PWD)/apko/$(name)/$(tag)/apko.lock.json \
		$(if $(filter 1,$(cache)),--cache-dir $(cache_dir),) \
		$(if $(filter 1,$(offline)),--offline,) ; \

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
		$(if $(filter 1,$(offline)),--offline,) ; \

.PHONY: load
load:
	docker load -i $(PWD)/apko/$(name)/$(tag)/image.tar

.PHONY: test
test:
	docker run -it --rm $(name):$(tag)-$(arch)

.PHONY: build
build: lock image load

.PHONY: publish
publish:
	docker tag $(name):$(tag)-$(arch) $(registry)/$(name):$(tag)
	docker push $(registry)/$(name):$(tag)

.PHONY: show-fs
show-fs:
	crane export $(registry)/$(name):$(tag) - | tar -tvf -
