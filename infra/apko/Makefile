
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

WOLFI_IMAGE=cgr.dev/chainguard/wolfi-base@sha256:42012fa027adc864efbb7cf68d9fc575ea45fe1b9fb0d16602e00438ce3901b1
APKO_IMAGE=cgr.dev/chainguard/apko@sha256:bf25bc53dec335d5dd30f8375a8b7a89b75074638e15e3399e58e9d1228e8eed
MELANGE_IMAGE=cgr.dev/chainguard/melange@sha256:3b276bcb5683bde86f95a7eebc6d7bc9ed1f71a9f8813f22b991ad0ed345133f
SDK_IMAGE=ghcr.io/wolfi-dev/sdk@sha256:5866033aff23f88676d20ced03a4113f24d5957bff60e7e629f54563094c5dfd

tag ?= latest-dev
name ?= laravel
cache_dir ?= $(PWD)/.cache
log_level ?= debug

.PHONY: digests
digests:
	docker images --digests > docker-images.txt

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

.PHONY: laravel
laravel:
	docker run -it --rm --pull=always cgr.dev/chainguard/laravel:latest-dev

.PHONY: lock
lock:
	apko lock $(PWD)/$(name)/$(tag).apko.yaml \
		--log-level $(log_level) \
		--workdir $(PWD)/$(name) \
		--cache-dir $(cache_dir) \
		--output $(PWD)/$(name)/$(tag).lock.json

.PHONY: build-image
build-image:
	$(eval offline := 1)
	mkdir -p $(PWD)/$(name)/$(tag) && \
	apko build $(PWD)/$(name)/$(tag).apko.yaml $(name):$(tag) $(PWD)/$(name)/$(tag)/image.tar \
		--log-level $(log_level) \
		--workdir $(PWD)/$(name) \
		--cache-dir $(cache_dir) \
		--sbom-path $(PWD)/$(name)/$(tag) \
		--lockfile $(PWD)/$(name)/$(tag).lock.json \
		$(if $(filter 1,$(offline)),--offline,) ; \

.PHONY: load-image
load-image:
	docker load -i $(PWD)/$(name)/$(tag)/image.tar

show-packages:
	apko show-packages $(PWD)/laravel.yaml

.PHONY: test-image
test-image:
	docker run -it --rm $(name):$(tag)-amd64
