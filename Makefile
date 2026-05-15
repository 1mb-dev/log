# Makefile -- 1mb-dev/log reference deployment of markgo at log.1mb.dev.
#
# Targets:
#   help          Show this message.
#   fetch-markgo  Build the markgo binary into ./build/markgo.
#   build         Verify the deploy bundle is ready.
#   deploy        (Stub -- M1 implements.) Push to a VPS and reload systemd.
#   clean         Remove build artifacts.
#
# Tunables (env vars or make variables):
#   MARKGO_REF    Git ref of markgo to clone (only used when MARKGO_SRC is absent).
#                 Default: v3.7.0.
#   MARKGO_SRC    Path to a local markgo checkout. If present, builds the currently
#                 checked-out ref; if absent, MARKGO_REF is cloned to build/markgo-src.
#                 Default: ../markgo.
#   GOOS, GOARCH  Build target. Default: linux/amd64.
#   DOMAIN        Deploy target (required by `make deploy`). Example: log.1mb.dev.
#
# Note: markgo's GitHub releases are tag-only (no binary artifacts attached as of
# v3.7.0). Once artifacts ship, this Makefile can switch to a curl-based fetch.

MARKGO_REF  ?= v3.7.0
MARKGO_SRC  ?= ../markgo
GOOS        ?= linux
GOARCH      ?= amd64
BUILD_DIR   := build
BINARY      := $(BUILD_DIR)/markgo

.PHONY: help fetch-markgo build deploy clean

help: ## Show this help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

fetch-markgo: ## Build the markgo binary for $(GOOS)/$(GOARCH)
	@mkdir -p $(BUILD_DIR)
	@if [ -d "$(MARKGO_SRC)" ]; then \
		echo "==> Using local markgo checkout at $(MARKGO_SRC) (current ref)"; \
		GOOS=$(GOOS) GOARCH=$(GOARCH) $(MAKE) -C $(MARKGO_SRC) build; \
		cp $(MARKGO_SRC)/build/markgo $(BINARY); \
	else \
		echo "==> Cloning markgo $(MARKGO_REF) into $(BUILD_DIR)/markgo-src"; \
		rm -rf $(BUILD_DIR)/markgo-src; \
		git clone --depth 1 --branch $(MARKGO_REF) https://github.com/1mb-dev/markgo.git $(BUILD_DIR)/markgo-src; \
		GOOS=$(GOOS) GOARCH=$(GOARCH) $(MAKE) -C $(BUILD_DIR)/markgo-src build; \
		cp $(BUILD_DIR)/markgo-src/build/markgo $(BINARY); \
	fi
	@echo "==> Built $(BINARY) ($(GOOS)/$(GOARCH))"

build: fetch-markgo ## Verify the deploy bundle is ready
	@test -x $(BINARY) || { echo "missing $(BINARY); run make fetch-markgo"; exit 1; }
	@ls articles/*.md >/dev/null 2>&1 || echo "warn: articles/ is empty -- replace _example.md before deploy"
	@echo "==> Ready: $(BINARY) + articles/ + static/"

deploy: build ## Deploy to DOMAIN (stub -- M1 implements)
	@test -n "$(DOMAIN)" || { echo "usage: make deploy DOMAIN=your.domain.example"; exit 1; }
	@echo "==> deploy: not yet implemented (M1 wires this up)"
	@echo "==> Intended flow: rsync $(BINARY) articles/ static/ deploy/ -> $(DOMAIN):/opt/log.1mb.dev/"
	@echo "                  ssh $(DOMAIN) sudo systemctl restart log.service"
	@exit 1

clean: ## Remove build artifacts
	rm -rf $(BUILD_DIR)
