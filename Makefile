.PHONY: build install uninstall clean test run help

BINARY_NAME=arcane-gitops
INSTALL_PATH=/usr/local/bin
SERVICE_PATH=/etc/systemd/system
CONFIG_PATH=/etc/arcane-gitops

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

build: ## Build the binary
	@echo "Building $(BINARY_NAME)..."
	go build -ldflags="-s -w" -o $(BINARY_NAME) main.go
	@echo "Build complete!"

test: ## Run tests (if any)
	go test -v ./...

clean: ## Clean build artifacts
	@echo "Cleaning..."
	rm -f $(BINARY_NAME)
	@echo "Clean complete!"

install: build ## Install binary and systemd files (requires sudo)
	@echo "Installing $(BINARY_NAME)..."
	sudo install -m 755 $(BINARY_NAME) $(INSTALL_PATH)/$(BINARY_NAME)
	sudo install -d $(CONFIG_PATH)
	sudo install -m 600 config.env.example $(CONFIG_PATH)/config.env.example
	sudo install -m 644 arcane-gitops.service $(SERVICE_PATH)/arcane-gitops.service
	sudo install -m 644 arcane-gitops.timer $(SERVICE_PATH)/arcane-gitops.timer
	sudo systemctl daemon-reload
	@echo "Installation complete!"
	@echo ""
	@echo "Next steps:"
	@echo "1. Copy and edit configuration:"
	@echo "   sudo cp $(CONFIG_PATH)/config.env.example $(CONFIG_PATH)/config.env"
	@echo "   sudo nano $(CONFIG_PATH)/config.env"
	@echo ""
	@echo "2. Enable and start the timer:"
	@echo "   sudo systemctl enable arcane-gitops.timer"
	@echo "   sudo systemctl start arcane-gitops.timer"

uninstall: ## Uninstall binary and systemd files (requires sudo)
	@echo "Uninstalling $(BINARY_NAME)..."
	sudo systemctl stop arcane-gitops.timer 2>/dev/null || true
	sudo systemctl disable arcane-gitops.timer 2>/dev/null || true
	sudo rm -f $(SERVICE_PATH)/arcane-gitops.service
	sudo rm -f $(SERVICE_PATH)/arcane-gitops.timer
	sudo rm -f $(INSTALL_PATH)/$(BINARY_NAME)
	sudo systemctl daemon-reload
	@echo "Uninstall complete!"
	@echo "Note: Configuration in $(CONFIG_PATH) was preserved"
	@echo "To remove config: sudo rm -rf $(CONFIG_PATH)"

run: build ## Build and run locally (for testing)
	@echo "Running $(BINARY_NAME) (ensure environment variables are set)..."
	./$(BINARY_NAME)

install-dev: build ## Install binary only (for development)
	@echo "Installing $(BINARY_NAME) (dev mode)..."
	sudo install -m 755 $(BINARY_NAME) $(INSTALL_PATH)/$(BINARY_NAME)
	@echo "Dev installation complete!"

status: ## Check service and timer status
	@echo "Timer status:"
	@sudo systemctl status arcane-gitops.timer --no-pager || true
	@echo ""
	@echo "Service status:"
	@sudo systemctl status arcane-gitops.service --no-pager || true
	@echo ""
	@echo "Recent logs:"
	@sudo journalctl -u arcane-gitops.service -n 20 --no-pager || true

logs: ## Show service logs
	sudo journalctl -u arcane-gitops.service -f

check-config: ## Verify configuration file
	@echo "Checking configuration..."
	@if [ -f /etc/arcane-gitops/config.env ]; then \
		echo "✓ Config file exists"; \
		echo ""; \
		echo "Config contents (API key masked):"; \
		sudo cat /etc/arcane-gitops/config.env | sed 's/ARCANE_API_KEY=.*/ARCANE_API_KEY=***MASKED***/'; \
		echo ""; \
		echo "Required variables check:"; \
		if grep -q "COMPOSE_REPO_PATH=" /etc/arcane-gitops/config.env; then \
			echo "✓ COMPOSE_REPO_PATH is set"; \
		else \
			echo "✗ COMPOSE_REPO_PATH is missing!"; \
		fi; \
		if grep -q "ARCANE_BASE_URL=" /etc/arcane-gitops/config.env; then \
			echo "✓ ARCANE_BASE_URL is set"; \
		else \
			echo "✗ ARCANE_BASE_URL is missing!"; \
		fi; \
		if grep -q "ARCANE_API_KEY=" /etc/arcane-gitops/config.env; then \
			echo "✓ ARCANE_API_KEY is set"; \
		else \
			echo "✗ ARCANE_API_KEY is missing!"; \
		fi; \
	else \
		echo "✗ Config file not found at /etc/arcane-gitops/config.env"; \
		exit 1; \
	fi

test-api: ## Test Arcane API connection
	@echo "Testing Arcane API connection..."
	@if [ -f /etc/arcane-gitops/config.env ]; then \
		. /etc/arcane-gitops/config.env && \
		curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" \
			-H "X-Api-Key: $$ARCANE_API_KEY" \
			-H "Authorization: Bearer $$ARCANE_API_KEY" \
			"$$ARCANE_BASE_URL/api/environments/$$ARCANE_ENV_ID/projects"; \
	else \
		echo "Config file not found"; \
		exit 1; \
	fi
