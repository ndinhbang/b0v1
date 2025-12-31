# =============================================================================
# Help Target - Display all available make commands
# =============================================================================
.PHONY: help
help: ## Show this help message
	@echo 'Available targets:'
	@awk '$$0 ~ "^[a-zA-Z_/-][a-zA-Z0-9_/-]*:.*##" { split($$0, a, ": .*## "); printf "  \033[36m%-25s\033[0m %s\n", a[1], a[2] } $$0 ~ "[a-zA-Z_/-][a-zA-Z0-9_/-]*/%:.*##" { match($$0, "[a-zA-Z_/-][a-zA-Z0-9_/-]*/%"); target = substr($$0, RSTART, RLENGTH); split($$0, a, ": .*## "); printf "  \033[36m%-25s\033[0m %s\n", target, a[2] }' $(MAKEFILE_LIST)

# =============================================================================
# Package Build Configuration
# =============================================================================
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
PARALLEL_JOBS ?= 4
# TARGETDIR = packages/${ARCH}

APKO ?= $(shell which apko)
MELANGE ?= $(shell which melange)
WOLFICTL ?= $(shell which wolfictl)
KEY ?= local-melange.rsa
REPO ?= /work/out/packages
IMAGES_DIR ?= /work/images
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

# =============================================================================
# Package Build Targets
# =============================================================================

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

# =============================================================================
# Offline Build Support
# =============================================================================

# 1. Download Packages
.PHONY: pkg/download
pkg/download: ## Download packages from apko config file (specify arch=<arch> or download both)
	$(eval name ?= laravel)
	$(eval tag ?= latest-dev)
	$(eval apko-path := $(IMAGES_DIR)/$(name)/$(tag).apko.yaml)
	$(eval arch_normalized := $(if $(arch),$(shell echo $(arch) | sed 's/amd64/x86_64/;s/arm64/aarch64/'),))
	$(eval archs := $(if $(arch_normalized),$(arch_normalized),x86_64 aarch64))
	@test -f "$(IMAGES_DIR)/$(name)/$(tag).apko.yaml" || \
		(echo "Error: Config file not found: $(IMAGES_DIR)/$(name)/$(tag).apko.yaml"; exit 1)
	@echo "=== Downloading packages for $(name):$(tag) ==="
	@echo "Config: $(apko-path)"
	@for arch in $(archs); do \
		echo ""; \
		echo ">>> Architecture: $$arch"; \
		echo "Target: $(REPO)/$$arch"; \
		\
		echo "Step 1/4: Updating remote index..."; \
		apk update; \
		\
		echo "Step 2/4: Installing GNU parallel if needed..."; \
		command -v parallel >/dev/null 2>&1 || apk add parallel; \
		\
		echo "Step 3/4: Fetching packages..."; \
		mkdir -p $(REPO)/$$arch; \
		( tmpf=$$(mktemp); \
		  tmpf_urls=$$(mktemp); \
		  $(APKO) show-packages $(apko-path) --arch $$arch --format "packagelock-source" > $$tmpf_urls; \
		  sed 's/^- \([^=]*\)=.*/\1/' $$tmpf_urls > $$tmpf; \
		  cat $$tmpf | parallel --will-cite --no-notice -j${PARALLEL_JOBS} --halt never --bar \
		    "apk fetch --repositories-file /etc/apk/repositories --output $(REPO)/$$arch {} >/dev/null 2>&1"; \
		  rm -f $$tmpf $$tmpf_urls; \
		); \
		echo "✓ Download complete"; \
		\
		echo "Step 4/4: Generating checksum file..."; \
		(cd $(REPO)/$$arch && \
		  sha256sum *.apk 2>/dev/null | sort -k2 > checksum.txt); \
		); \
		echo "✓ Download complete. Checksum file created at $(REPO)/$$arch/checksum.txt"; \
		\
		echo "Step 5/4: Generating APKINDEX..."; \
		$(MAKE) --no-print-directory pkg/index arch=$$arch || exit 1; \
	done
	@echo ""
	@echo "=== Download completed for: $(archs) ==="

.PHONY: pkg/collect
pkg/collect: ## Collect and deduplicate packages from all apko configs (specify arch=<arch> or collect both)
	$(eval arch_normalized := $(if $(arch),$(shell echo $(arch) | sed 's/amd64/x86_64/;s/arm64/aarch64/'),))
	$(eval archs := $(if $(arch_normalized),$(arch_normalized),x86_64 aarch64))
	@if [ ! -d "$(IMAGES_DIR)" ]; then \
		echo "Error: Images directory not found: $(IMAGES_DIR)"; \
		exit 1; \
	fi
	@command -v parallel >/dev/null 2>&1 || { \
		echo "Installing GNU parallel..."; \
		apk add parallel; \
	}
	@for arch in $(archs); do \
		echo ""; \
		echo ">>> Architecture: $$arch"; \
		mkdir -p $(REPO)/$$arch; \
		rm -f $(REPO)/$$arch/packages.lock; \
		tmpdir=$$(mktemp -d); \
		success_dir=$$(mktemp -d); \
		find $(IMAGES_DIR) -type f -name "*.apko.yaml" > $$tmpdir/all_configs.txt; \
		cat $$tmpdir/all_configs.txt | \
			parallel --will-cite --no-notice -j${PARALLEL_JOBS} --halt never --bar \
				"if $(APKO) show-packages {} --arch $$arch --format packagelock-source > $$tmpdir/{#}.lock 2>/dev/null; then touch $$success_dir/{#}.ok; fi"; \
		cat $$tmpdir/*.lock 2>/dev/null | sort -u > $(REPO)/$$arch/packages.lock; \
		pkg_count=$$(wc -l < $(REPO)/$$arch/packages.lock); \
		echo "✓ Collection complete: $$pkg_count unique packages for $$arch"; \
		echo "Lock file: $(REPO)/$$arch/packages.lock"; \
		total_configs=$$(wc -l < $$tmpdir/all_configs.txt); \
		success_count=$$(ls -1 $$success_dir/*.ok 2>/dev/null | wc -l); \
		failed_count=$$((total_configs - success_count)); \
		if [ $$failed_count -gt 0 ]; then \
			echo ""; \
			echo "⚠ Warning: $$failed_count config(s) failed:"; \
			config_num=0; \
			while IFS= read -r config_file; do \
				config_num=$$((config_num + 1)); \
				if [ ! -f "$$success_dir/$$config_num.ok" ]; then \
					rel_path=$${config_file#$(IMAGES_DIR)/}; \
					echo "  - $$rel_path"; \
				fi; \
			done < $$tmpdir/all_configs.txt; \
		fi; \
		rm -rf $$tmpdir $$success_dir; \
	done

.PHONY: pkg/download-all
pkg/download-all: ## Download packages from all apko config files (specify arch=<arch> or download both, force=1 to re-download existing)
	$(eval arch_normalized := $(if $(arch),$(shell echo $(arch) | sed 's/amd64/x86_64/;s/arm64/aarch64/'),))
	$(eval archs := $(if $(arch_normalized),$(arch_normalized),x86_64 aarch64))
	$(eval force := $(if $(force),$(force),0))
	@echo "Architectures: $(archs)"
	@echo "Force mode: $(force) (0=skip existing, 1=re-download all)"
	@if [ ! -d "$(IMAGES_DIR)" ]; then \
		echo "Error: Images directory not found: $(IMAGES_DIR)"; \
		exit 1; \
	fi
	@command -v parallel >/dev/null 2>&1 || { \
		echo "Installing GNU parallel..."; \
		apk add parallel; \
	}
	@echo ""
	@echo "=== Phase 1: Collecting packages ==="
	@for arch in $(archs); do \
		$(MAKE) --no-print-directory pkg/collect arch=$$arch; \
	done
	@echo ""
	@echo "=== Phase 2: Downloading and indexing ==="
	@for arch in $(archs); do \
		echo ""; \
		echo ">>> Architecture: $$arch"; \
		echo "Target: $(REPO)/$$arch"; \
		\
		echo "Step 1/4: Updating remote index..."; \
		apk update; \
		\
		echo "Step 2/4: Fetching packages from $(REPO)/$$arch/packages.lock..."; \
		mkdir -p $(REPO)/$$arch; \
		downloaded_count=0; \
		( tmpf=$$(mktemp); \
		  tmpf_needed=$$(mktemp); \
		  tmpf_filtered=$$(mktemp); \
		  tmpf_existing=$$(mktemp); \
		  sed 's/^- \([^=]*\)=\([^ ]*\).*/\1-\2/' $(REPO)/$$arch/packages.lock > $$tmpf_needed; \
		  sed 's/^- \([^=]*\)=.*/\1/' $(REPO)/$$arch/packages.lock > $$tmpf; \
		  if [ "$(force)" = "0" ]; then \
		    echo "  Filtering already downloaded packages..."; \
		    ls $(REPO)/$$arch/*.apk 2>/dev/null | xargs -n1 basename 2>/dev/null | sed 's/\.apk$$//' | sort -u > $$tmpf_existing; \
		    comm -23 <(sort $$tmpf_needed) $$tmpf_existing | sed 's/-[^-]*-r[^-]*$$//' > $$tmpf_filtered; \
		    total=$$(wc -l < $$tmpf); \
		    to_download=$$(wc -l < $$tmpf_filtered 2>/dev/null || echo 0); \
		    skipped=$$((total - to_download)); \
		    echo "  Total: $$total packages, Skipped: $$skipped, To download: $$to_download"; \
		    if [ $$to_download -gt 0 ]; then \
		      cat $$tmpf_filtered | parallel --will-cite --no-notice -j${PARALLEL_JOBS} --halt never --bar \
		        "apk fetch --repositories-file /etc/apk/repositories --output $(REPO)/$$arch {} >/dev/null 2>&1"; \
		      downloaded_count=$$to_download; \
		    fi; \
		  else \
		    echo "  Downloading all packages (force mode)..."; \
		    cat $$tmpf | parallel --will-cite --no-notice -j${PARALLEL_JOBS} --halt never --bar \
		      "apk fetch --repositories-file /etc/apk/repositories --output $(REPO)/$$arch {} >/dev/null 2>&1"; \
		    downloaded_count=$$(wc -l < $$tmpf); \
		  fi; \
		  rm -f $$tmpf $$tmpf_needed $$tmpf_filtered $$tmpf_existing; \
		); \
		echo "✓ Download complete"; \
		\
		if [ $$downloaded_count -gt 0 ]; then \
		  echo "Step 3/4: Generating checksum file..."; \
		  (cd $(REPO)/$$arch && \
		    sha256sum *.apk 2>/dev/null | sort -k2 > checksum.txt); \
		  echo "✓ Checksum file created at $(REPO)/$$arch/checksum.txt"; \
		  \
		  echo "Step 4/4: Generating APKINDEX..."; \
		  $(MAKE) --no-print-directory pkg/index arch=$$arch || exit 1; \
		else \
		  echo "Step 3/4: Skipping checksum generation (no new packages)"; \
		  echo "Step 4/4: Skipping APKINDEX generation (no new packages)"; \
		fi; \
	done
	@echo ""
	@echo "✓ All packages downloaded successfully"

# 2. Verify Package Integrity
.PHONY: pkg/verify
pkg/verify: ## Verify integrity of downloaded packages using checksum.txt
	$(eval arch := $(shell uname -m | sed 's/amd64/x86_64/;s/arm64/aarch64/'))
	@if [ ! -f "$(REPO)/$(arch)/checksum.txt" ]; then \
		echo "✗ Error: checksum.txt not found. Run 'make pkg/download' first."; \
		exit 1; \
	fi
	@cd $(REPO)/$(arch) && \
		sha256sum -c checksum.txt 2>&1 | \
		awk '/OK$$/ {ok++} /FAILED$$/ {fail++; printf "  ✗ FAILED: %s\n", $$1} END { \
			if(ok>0) print "✓ Verified: " ok " packages"; \
			if(fail>0) { print "✗ Failed: " fail " packages"; exit 1 } \
			else if(ok==0) { print "⚠ No files to verify"; } \
		}';

# 3. Generate APKINDEX
.PHONY: pkg/index
pkg/index: pkg/verify ## Verify packages then generate APKINDEX
	$(eval arch := $(shell uname -m | sed 's/amd64/x86_64/;s/arm64/aarch64/'))
	@echo "=== Generating APKINDEX ==="
	$(MELANGE) index --output $(REPO)/$(arch)/APKINDEX.tar.gz $(REPO)/$(arch)/*.apk
	$(MELANGE) sign-index --signing-key /etc/apk/keys/local-melange.rsa $(REPO)/$(arch)/APKINDEX.tar.gz
	@echo "✓ APKINDEX generated at $(REPO)/$(arch)/APKINDEX.tar.gz"

# =============================================================================

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

