.DEFAULT_GOAL := help

help:  ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Application commands
create: create-loopback create-network start ## Create application from scratch (one-time only command)
create-linux: create-loopback-linux create-network start
destroy: ## Stop application and remove all volumes and networks
	docker compose down -v
start: ## Start application (application must be created before)
	docker compose up -d
stop: ## Stop application (will preserve state of the application)
	docker compose stop

create-network: ## create custom gr-dev network if now exist (it is required to gr-dev.me domain to work properly)
	docker network ls|grep phpcon-dev > /dev/null || docker network create phpcon-dev
create-loopback: ## Setup network loopback for mac environments
	if [ ! -f /etc/systemd/system/loopback-alias.service ]; then sudo ./add-alias-linux.sh; fi

