
# BEGIN: lint-install .
# http://github.com/tinkerbell/lint-install

.PHONY: lint
lint: _lint

LINT_ARCH := $(shell uname -m)
LINT_OS := $(shell uname)
LINT_OS_LOWER := $(shell echo $(LINT_OS) | tr '[:upper:]' '[:lower:]')
LINT_ROOT := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

# shellcheck and hadolint lack arm64 native binaries: rely on x86-64 emulation
ifeq ($(LINT_OS),Darwin)
	ifeq ($(LINT_ARCH),arm64)
		LINT_ARCH=x86_64
	endif
endif

SHELLCHECK_VERSION ?= v0.7.2
SHELLCHECK_BIN := out/linters/shellcheck-$(SHELLCHECK_VERSION)-$(LINT_ARCH)
$(SHELLCHECK_BIN):
	mkdir -p out/linters
	rm -rf out/linters/shellcheck-*
	curl -sSfL https://github.com/koalaman/shellcheck/releases/download/$(SHELLCHECK_VERSION)/shellcheck-$(SHELLCHECK_VERSION).$(LINT_OS_LOWER).$(LINT_ARCH).tar.xz | tar -C out/linters -xJf -
	mv out/linters/shellcheck-$(SHELLCHECK_VERSION)/shellcheck $@
	rm -rf out/linters/shellcheck-$(SHELLCHECK_VERSION)/shellcheck
HADOLINT_VERSION ?= v2.7.0
HADOLINT_BIN := out/linters/hadolint-$(HADOLINT_VERSION)-$(LINT_ARCH)
$(HADOLINT_BIN):
	mkdir -p out/linters
	rm -rf out/linters/hadolint-*
	curl -sfL https://github.com/hadolint/hadolint/releases/download/v2.6.1/hadolint-$(LINT_OS)-$(LINT_ARCH) > $@
	chmod u+x $@
GOLANGCI_LINT_CONFIG := $(LINT_ROOT)/.golangci.yml
GOLANGCI_LINT_VERSION ?= v1.42.1
GOLANGCI_LINT_BIN := out/linters/golangci-lint-$(GOLANGCI_LINT_VERSION)-$(LINT_ARCH)
$(GOLANGCI_LINT_BIN):
	mkdir -p out/linters
	rm -rf out/linters/golangci-lint-*
	curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b out/linters $(GOLANGCI_LINT_VERSION)
	mv out/linters/golangci-lint $@
YAMLLINT_VERSION ?= 1.26.3
YAMLLINT_ROOT := out/linters/yamllint-$(YAMLLINT_VERSION)
YAMLLINT_BIN := $(YAMLLINT_ROOT)/dist/bin/yamllint
$(YAMLLINT_BIN):
	mkdir -p out/linters
	rm -rf out/linters/yamllint-*
	curl -sSfL https://github.com/adrienverge/yamllint/archive/refs/tags/v$(YAMLLINT_VERSION).tar.gz | tar -C out/linters -zxf -
	cd $(YAMLLINT_ROOT) && pip3 install --target dist .
.PHONY: _lint
_lint: $(SHELLCHECK_BIN) $(HADOLINT_BIN) $(GOLANGCI_LINT_BIN) $(YAMLLINT_BIN)
	$(GOLANGCI_LINT_BIN) run
	$(HADOLINT_BIN) $(shell find . -name "*Dockerfile")
	$(SHELLCHECK_BIN) $(shell find . -name "*.sh")
	PYTHONPATH=$(YAMLLINT_ROOT)/dist $(YAMLLINT_ROOT)/dist/bin/yamllint .

.PHONY: fix
fix: $(SHELLCHECK_BIN) $(GOLANGCI_LINT_BIN)
	$(GOLANGCI_LINT_BIN) run --fix
	$(SHELLCHECK_BIN) $(shell find . -name "*.sh") -f diff | { read -t 1 line || exit 0; { echo "$$line" && cat; } | git apply -p2; }

# END: lint-install .
