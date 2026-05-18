# Makefile -- 1mb-dev/log reference deployment of markgo at log.1mb.dev.
#
# Targets:
#   help          Show this message.
#   fetch-markgo  Build the markgo binary into ./build/markgo.
#   build         Verify the deploy bundle is ready.
#   deploy        Push to a VPS, install systemd unit, restart, smoke-test.
#   verify        Run scripts/verify-deploy.sh against DOMAIN.
#   clean         Remove build artifacts.
#
# Tunables (env vars or make variables):
#   MARKGO_REF    Git ref of markgo to clone (only used when MARKGO_SRC is absent).
#                 Default: v3.14.0.
#   MARKGO_SRC    Path to a local markgo checkout. If present, builds the currently
#                 checked-out ref; if absent, MARKGO_REF is cloned to build/markgo-src.
#                 Default: ../markgo.
#   GOOS, GOARCH  Build target. Default: linux/amd64.
#
# Deploy tunables -- defaults match log.1mb.dev's production. Forkers override.
#   DOMAIN        Required. Public hostname. Example: log.1mb.dev.
#   SSH_TARGET    SSH destination for privileged ops. Default: root@$(DOMAIN).
#   DEPLOY_USER   System user that owns the deploy tree and runs markgo.
#                 Default: loguser. Forkers often pick `markgo` instead.
#   DEPLOY_PATH   Install prefix on the VPS. Default: /opt/$(DOMAIN).
#   SERVICE_NAME  Systemd unit basename. Default: log (=> log.service).
#
# Note: markgo releases ship linux/amd64, darwin/amd64, and windows/amd64
# binaries as of v3.14.0. This Makefile still builds from source so forkers can
# pin to any tag or commit and inspect the build line. A curl-based fetch of
# the published artifacts is a future simplification.

MARKGO_REF   ?= v3.14.0
MARKGO_SRC   ?= ../markgo
GOOS         ?= linux
GOARCH       ?= amd64
BUILD_DIR    := build
BINARY       := $(BUILD_DIR)/markgo

DOMAIN       ?=
SSH_TARGET   ?= root@$(DOMAIN)
DEPLOY_USER  ?= loguser
DEPLOY_PATH  ?= /opt/$(DOMAIN)
SERVICE_NAME ?= log

.PHONY: help fetch-markgo build deploy verify clean

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

deploy: build ## Deploy to DOMAIN: push binary + content + .env, install unit, restart, verify
	@test -n "$(DOMAIN)" || { echo "usage: make deploy DOMAIN=your.domain.example"; exit 1; }
	@test -f .env || { echo "missing .env -- cp .env.example .env, fill in values, then retry"; exit 1; }
	@echo "==> deploy: $(SSH_TARGET):$(DEPLOY_PATH) (user=$(DEPLOY_USER), service=$(SERVICE_NAME))"
	@mkdir -p $(BUILD_DIR)
	@sed -e 's|/opt/log.1mb.dev|$(DEPLOY_PATH)|g' \
	     -e 's|^User=markgo|User=$(DEPLOY_USER)|' \
	     -e 's|^Group=markgo|Group=$(DEPLOY_USER)|' \
	     -e 's|^SyslogIdentifier=log|SyslogIdentifier=$(SERVICE_NAME)|' \
	     deploy/log.service.example > $(BUILD_DIR)/$(SERVICE_NAME).service
	@echo "==> Provision (idempotent)"
	@ssh $(SSH_TARGET) " \
	  id $(DEPLOY_USER) >/dev/null 2>&1 || useradd --system --no-create-home --shell /bin/false $(DEPLOY_USER); \
	  mkdir -p $(DEPLOY_PATH)/articles $(DEPLOY_PATH)/static $(DEPLOY_PATH)/uploads $(DEPLOY_PATH)/logs; \
	  mkdir -p /tmp/$(SERVICE_NAME)-bundle"
	@echo "==> Sync binary + .env + unit"
	@rsync -a $(BINARY) .env $(BUILD_DIR)/$(SERVICE_NAME).service $(SSH_TARGET):/tmp/$(SERVICE_NAME)-bundle/
	@echo "==> Sync content (articles additive; static mirrored)"
	@rsync -a articles/ $(SSH_TARGET):$(DEPLOY_PATH)/articles/
	@rsync -a --delete static/ $(SSH_TARGET):$(DEPLOY_PATH)/static/
	@echo "==> Install + restart"
	@ssh $(SSH_TARGET) " \
	  install -o $(DEPLOY_USER) -g $(DEPLOY_USER) -m 0755 /tmp/$(SERVICE_NAME)-bundle/markgo $(DEPLOY_PATH)/markgo && \
	  install -o $(DEPLOY_USER) -g $(DEPLOY_USER) -m 0600 /tmp/$(SERVICE_NAME)-bundle/.env $(DEPLOY_PATH)/.env && \
	  chown -R $(DEPLOY_USER):$(DEPLOY_USER) $(DEPLOY_PATH) && \
	  install -m 0644 /tmp/$(SERVICE_NAME)-bundle/$(SERVICE_NAME).service /etc/systemd/system/$(SERVICE_NAME).service && \
	  systemctl daemon-reload && \
	  systemctl enable $(SERVICE_NAME) >/dev/null 2>&1 && \
	  systemctl restart $(SERVICE_NAME) && \
	  systemctl is-active $(SERVICE_NAME) >/dev/null && \
	  rm -rf /tmp/$(SERVICE_NAME)-bundle"
	@echo "==> Verify"
	@sleep 2
	@./scripts/verify-deploy.sh $(DOMAIN)

verify: ## Run smoke tests against DOMAIN
	@test -n "$(DOMAIN)" || { echo "usage: make verify DOMAIN=your.domain.example"; exit 1; }
	@./scripts/verify-deploy.sh $(DOMAIN)

clean: ## Remove build artifacts
	rm -rf $(BUILD_DIR)
