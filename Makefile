.DEFAULT_GOAL := help

# Load .env file if it exists
ifneq (,$(wildcard .env))
include .env
export
endif

help:  ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Setup
check-env: ## Verify .env file exists and is configured
	@if [ ! -f .env ]; then \
		echo "❌ Error: .env file not found"; \
		echo ""; \
		echo "Please copy .env.example to .env and configure it:"; \
		echo "  cp .env.example .env"; \
		echo "  nano .env  # Edit configuration"; \
		echo ""; \
		exit 1; \
	fi
	@echo "✓ .env file found"
	@./scripts/setup/generate-configs.sh

init: check-env ## Initialize the project (first-time setup)
	@echo "✓ Project initialized"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Configure DNS: *.${DOMAIN} → ${LOOPBACK_IP}"
	@echo "  2. Generate SSL certificate: make help-ssl"
	@echo "  3. Copy certificates: make setup-certs"
	@echo "  4. Start Traefik: make create"

help-ssl: ## Display SSL certificate generation instructions
	@echo ""
	@echo "SSL Certificate Generation:"
	@echo ""
	@echo "Option 1: Manual DNS challenge (requires manual TXT record updates)"
	@echo "  sudo certbot certonly --manual --preferred-challenges dns \\"
	@echo "    -d '*.${DOMAIN}' -d '${DOMAIN}'"
	@echo ""
	@echo "Option 2: Automated with Cloudflare DNS (recommended)"
	@echo "  # Install plugin"
	@echo "  python3 -m pip install --break-system-packages certbot-dns-cloudflare"
	@echo ""
	@echo "  # Create credentials file"
	@echo "  mkdir -p ~/.secrets"
	@echo "  echo 'dns_cloudflare_api_token = YOUR_TOKEN' > ~/.secrets/cloudflare.ini"
	@echo "  chmod 600 ~/.secrets/cloudflare.ini"
	@echo ""
	@echo "  # Generate certificate"
	@echo "  sudo certbot certonly --dns-cloudflare \\"
	@echo "    --dns-cloudflare-credentials ~/.secrets/cloudflare.ini \\"
	@echo "    -d '*.${DOMAIN}' -d '${DOMAIN}'"
	@echo ""

##@ Application commands
create: check-env create-loopback create-network start ## Create application from scratch (one-time only command)

destroy: ## Stop application and remove all volumes and networks
	docker compose down -v
start: ## Start application (application must be created before)
	docker compose up -d
stop: ## Stop application (will preserve state of the application)
	docker compose stop

create-network: ## create custom gr-dev network if now exist (it is required to gr-dev.me domain to work properly)
	docker network ls|grep local > /dev/null || docker network create local

create-loopback: ## Setup network loopback for mac environments
	@if [ "$$(uname)" = "Darwin" ]; then \
		sudo ./scripts/loopback/add-alias.sh; \
	else \
		./scripts/loopback/add-alias-linux.sh; \
	fi

remove-loopback: ## Remove network loopback alias (mac only)
	@if [ "$$(uname)" = "Darwin" ]; then \
		sudo ./scripts/loopback/remove-alias.sh; \
	else \
		echo "This target is only for macOS"; \
	fi

##@ Certificate management
setup-certs: ## Copy Let's Encrypt certificates to Traefik (requires sudo)
	sudo ./scripts/certificates/setup-certificates.sh

install-renew-hook: ## Install automatic renewal hook for Let's Encrypt
	@echo "Installing renewal hook..."
	@sudo mkdir -p /etc/letsencrypt/renewal-hooks/deploy
	@sudo cp scripts/certificates/renew-hook.sh /etc/letsencrypt/renewal-hooks/deploy/traefik-renew.sh
	@sudo chmod +x /etc/letsencrypt/renewal-hooks/deploy/traefik-renew.sh
	@echo "✓ Renewal hook installed at /etc/letsencrypt/renewal-hooks/deploy/traefik-renew.sh"
	@echo "  Edit the script to update TRAEFIK_DIR if needed"

test-renewal: ## Test Let's Encrypt renewal process (dry run)
	sudo certbot renew --dry-run

setup-auto-renewal: ## Setup automatic certificate renewal (twice daily via LaunchDaemon)
	sudo ./scripts/certificates/setup-auto-renewal.sh

remove-auto-renewal: ## Remove automatic certificate renewal
	sudo ./scripts/certificates/remove-auto-renewal.sh

check-renewal-status: ## Check if automatic renewal is configured
	@sudo launchctl list | grep certbot && echo "✓ Auto-renewal is configured" || echo "✗ Auto-renewal is NOT configured (run: make setup-auto-renewal)"


