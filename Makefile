# Presencia - Makefile
# Usage: make <target>

SHELL := /bin/bash

.PHONY: help lint deploy-server deploy-nuc

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ─── Lint ────────────────────────────────────────────────────────

lint: lint-shell lint-yaml lint-compose ## Run all linters

lint-shell: ## Lint all shell scripts with shellcheck
	@echo "── ShellCheck ──"
	@find server nuc -name "*.sh" -exec shellcheck -x {} + && echo "All scripts OK" || true

lint-yaml: ## Lint YAML files
	@echo "── YAML Lint ──"
	@if command -v yamllint &>/dev/null; then \
		find . -name "*.yml" -o -name "*.yaml" | xargs yamllint -d relaxed; \
	else \
		echo "yamllint not installed (pip install yamllint)"; \
	fi

lint-compose: ## Validate docker-compose.yml
	@echo "── Docker Compose Validate ──"
	@cd server && docker compose config --quiet && echo "docker-compose.yml OK" || echo "Validation failed"

# ─── Deploy Server ──────────────────────────────────────────────

deploy-server: ## Deploy Jitsi to VPS (requires SSH_HOST)
	@if [ -z "$(SSH_HOST)" ]; then \
		echo "Usage: make deploy-server SSH_HOST=user@your-vps"; \
		exit 1; \
	fi
	@echo "Deploying Jitsi server to $(SSH_HOST)..."
	rsync -avz --exclude '.env' server/ $(SSH_HOST):~/presencia-server/
	@echo ""
	@echo "Files synced. SSH to $(SSH_HOST) and run:"
	@echo "  cd ~/presencia-server"
	@echo "  cp .env.example .env"
	@echo "  ./gen-passwords.sh"
	@echo "  # Edit .env with your domain"
	@echo "  docker compose up -d"

# ─── Deploy NUC ─────────────────────────────────────────────────

deploy-nuc: ## Deploy NUC config (requires SSH_HOST)
	@if [ -z "$(SSH_HOST)" ]; then \
		echo "Usage: make deploy-nuc SSH_HOST=presencia@nuc-tailscale-ip"; \
		exit 1; \
	fi
	@echo "Deploying NUC configuration to $(SSH_HOST)..."
	rsync -avz --exclude 'presencia.conf' nuc/ $(SSH_HOST):~/presencia-nuc/
	@echo ""
	@echo "Files synced. SSH to $(SSH_HOST) and run:"
	@echo "  cd ~/presencia-nuc"
	@echo "  cp config/presencia.conf.example config/presencia.conf"
	@echo "  # Edit config/presencia.conf"
	@echo "  sudo ./install.sh"
