# =============================================================================
# Help Target - Display all available make commands
# =============================================================================
.PHONY: help
help: ## Show this help message
	@echo 'Available targets:'
	@awk '$$0 ~ "^[a-zA-Z_/-][a-zA-Z0-9_/-]*:.*##" { split($$0, a, ": .*## "); printf "  \033[36m%-25s\033[0m %s\n", a[1], a[2] } $$0 ~ "[a-zA-Z_/-][a-zA-Z0-9_/-]*/%:.*##" { match($$0, "[a-zA-Z_/-][a-zA-Z0-9_/-]*/%"); target = substr($$0, RSTART, RLENGTH); split($$0, a, ": .*## "); printf "  \033[36m%-25s\033[0m %s\n", target, a[2] }' $(MAKEFILE_LIST)

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
# TARGETDIR = packages/${ARCH}

MELANGE ?= $(shell which melange)
WOLFICTL ?= $(shell which wolfictl)
KEY ?= local-melange.rsa
REPO ?= /work/packages
# QEMU_KERNEL_REPO := https://apk.cgr.dev/chainguard-private/

# MELANGE_RUNNER ?= qemu
# MELANGE_OPTS += --runner=${MELANGE_RUNNER}
# MELANGE_TEST_OPTS += --runner=${MELANGE_RUNNER}
# QEMU_KERNEL_IMAGE ?= kernel/$(ARCH)/vmlinuz
# ifeq (${MELANGE_RUNNER},qemu)
# 	QEMU_KERNEL_DEP = ${QEMU_KERNEL_IMAGE}
# 	export QEMU_KERNEL_IMAGE
# endif

MELANGE_OPTS += --repository-append ${REPO}
MELANGE_OPTS += --out-dir ${REPO}
MELANGE_OPTS += --keyring-append ${KEY}.pub
MELANGE_OPTS += --signing-key ${KEY}
MELANGE_OPTS += --arch ${ARCH}
MELANGE_OPTS += --env-file build-${ARCH}.env
MELANGE_OPTS += --namespace wolfi
MELANGE_OPTS += --license 'Apache-2.0'
MELANGE_OPTS += --git-repo-url 'https://github.com/ndinhbang/os'
MELANGE_OPTS += --cache-dir ${CACHEDIR}
MELANGE_OPTS += --pipeline-dir ./pipelines/
MELANGE_OPTS += ${MELANGE_EXTRA_OPTS}

# Enter interactive mode on failure for debug
MELANGE_DEBUG_OPTS += --interactive
MELANGE_DEBUG_OPTS += --debug
MELANGE_DEBUG_OPTS += --package-append apk-tools
MELANGE_DEBUG_OPTS += ${MELANGE_OPTS}

# Enter interactive mode on test failure for debug
MELANGE_DEBUG_TEST_OPTS += --interactive

# These are separate from MELANGE_OPTS because for building we need additional
# ones that are not defined for tests.
MELANGE_TEST_OPTS += --repository-append ${REPO}
MELANGE_TEST_OPTS += --keyring-append ${KEY}.pub
MELANGE_TEST_OPTS += --arch ${ARCH}
MELANGE_TEST_OPTS += --pipeline-dirs ./pipelines/
MELANGE_TEST_OPTS += --repository-append https://packages.wolfi.dev/os
MELANGE_TEST_OPTS += --keyring-append https://packages.wolfi.dev/os/wolfi-signing.rsa.pub
MELANGE_TEST_OPTS += --test-package-append wolfi-base
MELANGE_TEST_OPTS += --debug
MELANGE_TEST_OPTS += ${MELANGE_EXTRA_OPTS}

ifeq (${LINT}, yes)
	MELANGE_OPTS += --fail-on-lint-warning
endif

WOLFI_REPO ?= https://packages.wolfi.dev/os
WOLFI_KEY ?= https://packages.wolfi.dev/os/wolfi-signing.rsa.pub

MELANGE_OPTS += -k ${WOLFI_KEY}
MELANGE_OPTS += -r ${WOLFI_REPO}

${KEY}:
	${MELANGE} keygen ${KEY}

.PHONY: pkg/cache
pkg/cache: ## Create melange cache directory
	mkdir -p ${CACHEDIR}

.PHONY: pkg/clean
pkg/clean: ## Clean built packages and kernel artifacts
	rm -rf packages/${ARCH}
	rm -rf kernel/

.PHONY: pkg/clean-cache
pkg/clean-cache: ## Clean melange build cache
	rm -rf ${CACHEDIR}

.PHONY: pkg/fetch-url
pkg/fetch-url: ## Fetch and download APK from URL to /work/packages/$(ARCH)
	@if [ -z "$(URL)" ]; then URL=$(filter-out $@, $(MAKECMDGOALS)); fi
	@if [ -z "$(URL)" ]; then echo "Usage: make pkg/fetch-url <url> or make pkg/fetch-url URL=<url>"; exit 1; fi
	mkdir -p $(REPO)/$(ARCH)
	curl -L -o $(REPO)/$(ARCH)/$(shell basename $(URL)) $(URL)

%:
	@:

# ${CACHEDIR}/.libraries_token.txt: pkg/cache
# 	tmpf=$(shell mktemp); \
# 	chainctl auth login --audience libraries.cgr.dev; \
# 	chainctl auth token --audience libraries.cgr.dev > $${tmpf}; \
# 	mv $${tmpf} ${CACHEDIR}/.libraries_token.txt

# .PHONY: lib-token
# lib-token: ${CACHEDIR}/.libraries_token.txt

# .PHONY: fetch-kernel
# fetch-kernel:
# 	rm -rf kernel/$(ARCH)
# 	$(MAKE) kernel/$(ARCH)/vmlinuz

# kernel/%/APKINDEX.tar.gz:
# 	@$(call authget,apk.cgr.dev,$@,$(QEMU_KERNEL_REPO)/$(ARCH)/APKINDEX.tar.gz)

# kernel/%/APKINDEX: kernel/%/APKINDEX.tar.gz
# 	tar -x -C kernel --to-stdout -f $< APKINDEX > $@.tmp.$$$$ && mv $@.tmp.$$$$ $@
# 	touch $@

# kernel/%/chosen: kernel/%/APKINDEX
# 	# Extract lines with 'P:linux-qemu-generic' and the following line that contains the version
# 	# This approach is compatible with both GNU and BSD sed
# 	awk '/^P:linux-qemu-generic$$/ {print; getline; print}' $< > kernel/$*/available
# 	grep '^V:' kernel/$*/available | sed 's/V://' | \
# 	  sort -V | tail -n1 > $@.tmp
# 	# Sanity check that this looks like an apk version
# 	grep -E '^([0-9]+\.)+[0-9]+-r[0-9]+$$' $@.tmp
# 	mv $@.tmp $@

# kernel/%/linux.apk: kernel/%/chosen
# 	@$(call authget,apk.cgr.dev,$@,$(QEMU_KERNEL_REPO)/$*/linux-qemu-generic-$(shell cat kernel/$*/chosen).apk)

# kernel/%/vmlinuz: kernel/%/linux.apk
# 	tmpd=kernel/.$$$$ && mkdir -p $$tmpd $(dir $@) && \
# 		tar -x -C $$tmpd -f $< boot/ 2> /dev/null && \
# 		[ -f $$tmpd/boot/vmlinuz ] && mv $$tmpd/boot/* $(dir $@) && \
# 		rc=$$?; rm -Rf $$tmpd; exit $$rc
# 	touch $@

yamls := $(wildcard *.yaml)
pkgs := $(subst .yaml,,$(yamls))
pkg_targets = $(foreach name,$(pkgs),package/$(name))
$(pkg_targets): package/%: pkg/cache ## Build a specific package from YAML file (e.g., package/php)
	$(eval yamlfile := $*.yaml)
	$(eval pkgver := $(shell $(MELANGE) package-version $(yamlfile)))
	@printf "Building package $* with version $(pkgver) from file $(yamlfile)\n"
	$(MAKE) yamlfile=$(yamlfile) pkgname=$* packages/$(ARCH)/$(pkgver).apk

packages/$(ARCH)/%.apk: $(KEY) $(QEMU_KERNEL_DEP) $(yamlfile)
	@[ -n "$(pkgname)" ] || { echo "$@: pkgname is not set"; exit 1; }
	@[ -n "$(yamlfile)" ] || { echo "$@: yamlfile is not set"; exit 1; }
	mkdir -p ./$(pkgname)/
	$(MELANGE) build $(yamlfile) $(MELANGE_OPTS) --source-dir ./$(pkgname)/

docker_pkg_targets = $(foreach name,$(pkgs),docker-package/$(name))
$(docker_pkg_targets): docker-package/%: ## Build package using docker runner (e.g., docker-package/php)
	@echo "Building using docker runner"
	MELANGE_RUNNER=docker make package/$*

dbg_targets = $(foreach name,$(pkgs),debug/$(name))
$(dbg_targets): debug/%: pkg/cache $(KEY) $(QEMU_KERNEL_DEP) ## Build package in interactive debug mode (e.g., debug/php)
	$(eval yamlfile := $*.yaml)
	$(eval pkgver := $(shell $(MELANGE) package-version $(yamlfile)))
	@printf "Building package $* with version $(pkgver) from file $(yamlfile)\n"
	mkdir -p ./"$*"/
	$(call set_source_date_epoch $(yamlfile))
	$(MELANGE) build $(yamlfile) $(MELANGE_DEBUG_OPTS) --source-dir ./$(*)/

test_targets = $(foreach name,$(pkgs),test/$(name))
$(test_targets): test/%: pkg/cache $(KEY) $(QEMU_KERNEL_DEP) ## Run tests for a package (e.g., test/php)
	mkdir -p ./$(*)/
	$(eval yamlfile := $*.yaml)
	$(eval pkgver := $(shell $(MELANGE) package-version $(yamlfile)))
	@printf "Testing package $* with version $(pkgver) from file $(yamlfile)\n"
	$(MELANGE) test $(yamlfile) $(MELANGE_TEST_OPTS) --source-dir ./$(*)/

docker_test_targets = $(foreach name,$(pkgs),docker-test/$(name))
$(docker_test_targets): docker-test/%: ## Run tests using docker runner (e.g., docker-test/php)
	@echo "Testing using docker runner"
	MELANGE_RUNNER=docker make test/$*

testdbg_targets = $(foreach name,$(pkgs),test-debug/$(name))
$(testdbg_targets): test-debug/%: pkg/cache $(KEY) $(QEMU_KERNEL_DEP) ## Run tests in interactive debug mode (e.g., test-debug/php)
	mkdir -p ./$(*)/
	$(eval yamlfile := $*.yaml)
	$(eval pkgver := $(shell $(MELANGE) package-version $(yamlfile)))
	@printf "Testing package $* with version $(pkgver) from file $(yamlfile)\n"
	$(MELANGE) test $(yamlfile) $(MELANGE_TEST_OPTS) $(MELANGE_DEBUG_TEST_OPTS) --source-dir ./$(*)/

# Please do not print any additional content via this target
# so that we can parse output directly with jq
compile_targets = $(foreach name,$(pkgs),compile/$(name))
$(compile_targets): compile/%: ## Compile package configuration (e.g., compile/php)
	@$(MAKE) $(KEY) >/dev/null 2>&1
	@mkdir -p ./$(*)/
	$(eval yamlfile := $*.yaml)
	@$(MELANGE) compile $(yamlfile) $(MELANGE_OPTS) --source-dir ./$(*)/

