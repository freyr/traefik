.DEFAULT_GOAL := help

# Load .env if it exists
ifneq (,$(wildcard .env))
include .env
export
endif

COMPOSE      := docker compose
DEMO_STACKS  := alpha beta gamma
DEMO_COMPOSE := examples/isolated-stacks/compose.yaml
DEMO_ENV     = STACK=$$s CA_FILE=$(abspath $(or $(SSL_DIR),./ssl))/rootCA.pem

help:  ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Setup
create: check-env install-deps certs start dns ## First-time setup: tools, CA + certificate, start, DNS

check-env: ## Create .env from .env.example when it is missing
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo "✓ Created .env from .env.example (DOMAIN=$$(grep '^DOMAIN=' .env | cut -d= -f2))"; \
	else \
		echo "✓ .env found (DOMAIN=$$(grep '^DOMAIN=' .env | cut -d= -f2))"; \
	fi

install-deps: ## Install mkcert (and nss for Firefox) with Homebrew on macOS
	@if command -v mkcert >/dev/null 2>&1; then \
		echo "✓ mkcert $$(mkcert -version 2>/dev/null) found"; \
	elif [ "$$(uname)" = "Darwin" ] && command -v brew >/dev/null 2>&1; then \
		brew install mkcert nss; \
	else \
		echo "❌ mkcert not found. Install it: https://github.com/FiloSottile/mkcert#installation"; \
		exit 1; \
	fi

certs: check-env ## Create the local CA and the *.DOMAIN certificate (skips when valid)
	@./scripts/certs/generate.sh

renew-certs: check-env ## Replace the certificate and reload Traefik
	@./scripts/certs/generate.sh --force
	@if [ -n "$$($(COMPOSE) ps -q traefik 2>/dev/null)" ]; then \
		$(COMPOSE) restart traefik >/dev/null && echo "✓ Traefik restarted with the new certificate"; \
	fi

cert-info: ## Show the names and expiry of the certificate
	@openssl x509 -in $${SSL_DIR:-./ssl}/local.crt -noout -subject -enddate
	@openssl x509 -in $${SSL_DIR:-./ssl}/local.crt -noout -text | grep -o 'DNS:[^,]*' | sed 's/^/  /'

dns: check-env ## Send *.DOMAIN queries to the dns container (sudo)
	@./scripts/dns/setup.sh

remove-dns: check-env ## Remove the resolver configuration (sudo)
	@./scripts/dns/remove.sh

##@ Proxy
start: ## Start Traefik, dns and network-sync
	$(COMPOSE) up -d --build --wait

stop: ## Stop the containers (keeps state)
	$(COMPOSE) stop

restart: ## Restart the containers
	$(COMPOSE) restart

destroy: ## Stop and remove the containers and the proxy network
	$(COMPOSE) down

logs: ## Follow the logs of all services
	$(COMPOSE) logs -f

status: ## Show the containers and the networks Traefik is connected to
	@$(COMPOSE) ps
	@echo
	@$(COMPOSE) exec -T network-sync sh /usr/local/bin/sync-networks status

sync-networks: ## Connect Traefik to edge networks now (normally automatic)
	@$(COMPOSE) exec -T network-sync sh /usr/local/bin/sync-networks once

##@ Demo
demo-up: ## Start 3 isolated nginx stacks (alpha, beta, gamma) on port 80
	@for s in $(DEMO_STACKS); do \
		$(DEMO_ENV) $(COMPOSE) -p $$s -f $(DEMO_COMPOSE) up -d --wait || exit 1; \
	done
	@echo; for s in $(DEMO_STACKS); do echo "  https://$$s.$(DOMAIN)"; done

demo-test: ## Check DNS, HTTPS and isolation of the demo stacks
	@./scripts/demo/test.sh

demo-down: ## Remove the demo stacks
	@for s in $(DEMO_STACKS); do $(DEMO_ENV) $(COMPOSE) -p $$s -f $(DEMO_COMPOSE) down; done

##@ Migration
remove-legacy: ## Remove the loopback alias and certbot renewal of the old setup (sudo)
	sudo LOOPBACK_IP=$${LOOPBACK_IP:-172.16.123.1} ./scripts/legacy/remove-legacy.sh

.PHONY: help create check-env install-deps certs renew-certs cert-info dns remove-dns \
	start stop restart destroy logs status sync-networks demo-up demo-test demo-down remove-legacy
