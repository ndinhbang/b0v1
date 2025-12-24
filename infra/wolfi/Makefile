USE_CACHE ?= no
ARCH ?= $(shell uname -m)
ifeq (${ARCH}, arm64)
	ARCH = aarch64
endif
ifeq (${TMPDIR}, )
    CACHEDIR = /tmp/melange-cache
else
    CACHEDIR = ${TMPDIR}/melange-cache
endif

MELANGE ?= $(shell which melange)
WOLFICTL ?= $(shell which wolfictl)
KEY ?= local-melange.rsa
REPO ?= $(shell pwd)/packages

GIT_DIR := $(shell git rev-parse --show-toplevel 2>/dev/null || pwd)
SOURCE_DATE_EPOCH := $(shell git -C $(GIT_DIR) --no-pager log -1 --pretty=%ct || echo no-git)
ifeq ($(SOURCE_DATE_EPOCH),no-git)
$(error setting SOURCE_DATE_EPOCH failed - $(SOURCE_DATE_EPOCH))
endif
export SOURCE_DATE_EPOCH

DOCKER_PLATFORM_ARG := $(shell \
  case $(ARCH) in \
	(aarch64) darch=arm64;; \
	(x86_64) darch=amd64;; \
	(*) echo "unknown-docker-platform-arch-$(ARCH)"; exit 1;; \
  esac ; \
  echo "--platform=linux/$$darch" \
)

keygen:
	@if [ -f "${OS_DIR}/${KEY}" ] && [ -f "${OS_DIR}/${KEY}.pub" ]; then \
		echo "\033[1;36mINFO:\033[0m Skipping keygen, ${OS_DIR}/${KEY} existed"; \
	else \
		mkdir -p "${OS_DIR}"; \
		${MELANGE} keygen "${OS_DIR}/${KEY}"; \
	fi

.PHONY: dev-container
dev-container:
	docker run $(DOCKER_PLATFORM_ARG) --pull=always --privileged --rm -it \
		--entrypoint="/bin/bash" \
	    -v "${OS_DIR}:${OS_DIR}" \
		--mount type=bind,source="${ROOT_DIR}/.git",destination="${OS_DIR}/.git",readonly \
		-v /tmp:/tmp \
		-v /var/run/docker.sock:/var/run/docker.sock \
	    -w "${OS_DIR}" \
	    -e SOURCE_DATE_EPOCH=$(SOURCE_DATE_EPOCH) \
	    -e HTTP_AUTH \
	    ghcr.io/wolfi-dev/sdk:latest -il

PACKAGES_CONTAINER_FOLDER ?= /work/packages
# This target spins up a docker container that is helpful for testing local
# changes to the packages. It mounts the local packages folder as a read-only,
# and sets up the necessary keys for you to run `apk add` commands, and then
# test the packages however you see fit.
.PHONY: local-wolfi
local-wolfi: keygen
	mkdir -p "${OS_DIR}/packages"
	$(eval TMP_REPOS_DIR := $(shell mktemp --tmpdir -d "$@.XXXXXX"))
	$(eval TMP_REPOS_FILE := $(TMP_REPOS_DIR)/repositories)
	echo "https://packages.wolfi.dev/os" > $(TMP_REPOS_FILE)
	echo "$(PACKAGES_CONTAINER_FOLDER)" >> $(TMP_REPOS_FILE)
ifneq ($(LOCAL_WOLFI_EXTRA_REPO),)
	echo "$(LOCAL_WOLFI_EXTRA_REPO)" >> $(TMP_REPOS_FILE)
endif
	docker run $(DOCKER_PLATFORM_ARG) --pull=always --rm -it \
		--entrypoint="/bin/sh" \
		--mount type=bind,source="${OS_DIR}/packages",destination="$(PACKAGES_CONTAINER_FOLDER)",readonly \
		--mount type=bind,source="${OS_DIR}/$(KEY).pub",destination="/etc/apk/keys/$(KEY).pub",readonly \
		--mount type=bind,source="$(TMP_REPOS_FILE)",destination="/etc/apk/repositories",readonly \
		-w "$(PACKAGES_CONTAINER_FOLDER)" \
		cgr.dev/chainguard/wolfi-base:latest -il
	rm "$(TMP_REPOS_FILE)"
	rmdir "$(TMP_REPOS_DIR)"

# This target spins up a docker container that is helpful for building images
# using local packages.
# It mounts the:
#  - local packages dir (default: pwd) as a read-only, as /work/packages. This
#    is where the local packages are set up to be fetched from.
#  - local os dir (default: pwd) as a read-only, as /work/os. This is where
#    apko config files should live in. Note that this can be the current
#    directory also.
# Both of these can be overridden with PACKAGES_CONTAINER_FOLDER and OS_DIR
# respectively.
# It sets up the necessary tools, keys, and repositories for you to run
# apko to build images and then test them. Currently, the apko tool requires a
# few flags to get the image built, but we'll work on getting the viper config
# set up to make this easier.
#
# The resulting image will be in the OUT_DIR, and it is best to specify the
# OUT_DIR as a directory in the host system, so that it will persist after the
# container is done, as well as you can test / iterate with the image and run
# tests in the host.
#
# Example invocation for
# mkdir /tmp/out && OUT_DIR=/tmp/out make dev-container-wolfi
# Then in the container, you could build an image like this:
# apko -C /work/out build --keyring-append /etc/apk/keys/wolfi-signing.rsa.pub \
#  --keyring-append /etc/apk/keys/local-melange.rsa.pub --arch host \
# /work/os/conda-IMAGE.yaml conda-test:test /work/out/conda-test.tar
#
# Then from the host you can run:
# docker load -i /tmp/out/conda-test.tar
# docker run -it
OUT_LOCAL_DIR ?= /work/out
OS_LOCAL_DIR ?= /work/os
OS_DIR ?= ${PWD}

.PHONY: dev-container-wolfi
dev-container-wolfi: keygen
	$(eval TMP_REPOS_DIR := $(shell mktemp --tmpdir -d "$@.XXXXXX"))
	$(eval TMP_REPOS_FILE := $(TMP_REPOS_DIR)/repositories)
	$(eval OUT_DIR := $(shell echo $${OUT_DIR:-$$(mktemp --tmpdir -d "$@-out.XXXXXX")}))
	echo "https://packages.wolfi.dev/os" > $(TMP_REPOS_FILE)
	echo "$(PACKAGES_CONTAINER_FOLDER)" >> $(TMP_REPOS_FILE)
ifneq ($(LOCAL_WOLFI_EXTRA_REPO),)
	echo "$(LOCAL_WOLFI_EXTRA_REPO)" >> $(TMP_REPOS_FILE)
endif
	docker run $(DOCKER_PLATFORM_ARG) --pull=always --rm -it \
		--entrypoint="/bin/bash" \
		--mount type=bind,source="${OUT_DIR}",destination="$(OUT_LOCAL_DIR)" \
		--mount type=bind,source="${IMAGES_DIR}",destination="$(OS_LOCAL_DIR)",readonly \
		--mount type=bind,source="${OS_DIR}/packages",destination="$(PACKAGES_CONTAINER_FOLDER)",readonly \
		--mount type=bind,source="${OS_DIR}/$(KEY).pub",destination="/etc/apk/keys/$(KEY).pub",readonly \
		--mount type=bind,source="$(TMP_REPOS_FILE)",destination="/etc/apk/repositories",readonly \
		-w "$(OS_LOCAL_DIR)" \
		ghcr.io/wolfi-dev/sdk:latest -il
	rm "$(TMP_REPOS_FILE)"
	rmdir "$(TMP_REPOS_DIR)"


# authget = tok=$$(chainctl auth token --audience=$(1)) || \
#   { echo "failed token from $(1) for target $@"; exit 1; }; \
#   mkdir -p $$(dirname $(2)) && \
#   echo "auth-download[$(1)] to $(2) from $(3)" && \
#   curl --fail -LS --silent -o $(2).tmp --user "user:$$tok" $(3) && \
# 	mv "$(2).tmp" "$(2)"

