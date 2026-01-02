#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BINARY_NAME="arcane-gitops"
INSTALL_PATH="/usr/local/bin"
CONFIG_PATH="/etc/arcane-gitops"
SERVICE_PATH="/etc/systemd/system"

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root or with sudo"
        exit 1
    fi
}

check_go() {
    if ! command -v go &> /dev/null; then
        print_error "Go is not installed. Please install Go 1.21+ first."
        echo "Visit: https://golang.org/doc/install"
        exit 1
    fi
    
    GO_VERSION=$(go version | awk '{print $3}' | sed 's/go//')
    print_success "Go ${GO_VERSION} found"
}

check_git() {
    if ! command -v git &> /dev/null; then
        print_error "Git is not installed. Please install git first."
        exit 1
    fi
    print_success "Git found"
}

build_binary() {
    print_info "Building ${BINARY_NAME}..."
    go build -ldflags="-s -w" -o ${BINARY_NAME} main.go
    print_success "Build complete"
}

install_binary() {
    print_info "Installing binary to ${INSTALL_PATH}..."
    install -m 755 ${BINARY_NAME} ${INSTALL_PATH}/${BINARY_NAME}
    print_success "Binary installed"
}

create_config() {
    print_info "Creating configuration directory..."
    mkdir -p ${CONFIG_PATH}

    # If an existing config is present, use it to pre-fill defaults (press Enter to keep them)
    EXISTING_REPO_PATH=""
    EXISTING_ARCANE_URL=""
    EXISTING_ARCANE_KEY=""
    EXISTING_ENV_ID=""
    EXISTING_GIT_AUTH_METHOD=""
    EXISTING_GIT_SSH_KEY_PATH=""
    EXISTING_GIT_HTTPS_TOKEN=""
    if [[ -f "${CONFIG_PATH}/config.env" ]]; then
        # shellcheck disable=SC1090
        source "${CONFIG_PATH}/config.env"
        EXISTING_REPO_PATH="${COMPOSE_REPO_PATH:-}"
        EXISTING_ARCANE_URL="${ARCANE_BASE_URL:-}"
        EXISTING_ARCANE_KEY="${ARCANE_API_KEY:-}"
        EXISTING_ENV_ID="${ARCANE_ENV_ID:-}"
        EXISTING_GIT_AUTH_METHOD="${GIT_AUTH_METHOD:-}"
        EXISTING_GIT_SSH_KEY_PATH="${GIT_SSH_KEY_PATH:-}"
        EXISTING_GIT_HTTPS_TOKEN="${GIT_HTTPS_TOKEN:-}"

        # Legacy default from older versions (CLI used "default"); Arcane API typically uses "0"
        if [[ "$EXISTING_ENV_ID" == "default" ]]; then
            EXISTING_ENV_ID=""
        fi
    fi
    
    if [[ -f "${CONFIG_PATH}/config.env" ]]; then
        print_warning "Configuration file already exists at ${CONFIG_PATH}/config.env"
        read -p "Would you like to reconfigure? (y/n) [n]: " -n 1 -r
        echo
        REPLY=${REPLY:-n}
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return
        fi
    fi
    
    print_info "Configuring arcane-gitops..."
    echo
    
    # Get repository path (with default)
    DEFAULT_REPO_PATH="${EXISTING_REPO_PATH:-/opt/docker}"
    read -p "Enter the path to your docker compose git repository [$DEFAULT_REPO_PATH]: " REPO_PATH_INPUT
    REPO_PATH=${REPO_PATH_INPUT:-$DEFAULT_REPO_PATH}
    
    if [[ ! -d "$REPO_PATH" ]]; then
        print_warning "Directory $REPO_PATH does not exist"
        read -p "Continue anyway? (y/n) [n]: " -n 1 -r
        echo
        REPLY=${REPLY:-n}
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_error "Installation cancelled. Please create the directory or use a different path."
            exit 1
        fi
    fi

    echo
    print_info "Arcane API Configuration"
    print_info "You need to create an API key in Arcane: Settings → API Keys → Add API Key"
    echo
    
    # Arcane API URL (with default)
    DEFAULT_ARCANE_URL="${EXISTING_ARCANE_URL:-http://localhost:3552}"
    read -p "Enter your Arcane API URL [$DEFAULT_ARCANE_URL]: " ARCANE_URL_INPUT
    ARCANE_URL=${ARCANE_URL_INPUT:-$DEFAULT_ARCANE_URL}

    # Normalize URL:
    # - strip trailing slash
    # - if user accidentally includes /api, strip it (our tool appends /api)
    ARCANE_URL="${ARCANE_URL%/}"
    if [[ "$ARCANE_URL" == */api ]]; then
        ARCANE_URL="${ARCANE_URL%/api}"
    fi
    
    # Arcane API Key (required, hidden input). If reconfiguring and a key exists, allow Enter to keep it.
    if [[ -n "$EXISTING_ARCANE_KEY" ]]; then
        read -s -p "Enter your Arcane API key [press Enter to keep existing]: " ARCANE_KEY_INPUT
        echo
        ARCANE_KEY=${ARCANE_KEY_INPUT:-$EXISTING_ARCANE_KEY}
    fi

    while [[ -z "${ARCANE_KEY:-}" ]]; do
        read -s -p "Enter your Arcane API key: " ARCANE_KEY
        echo
        if [[ -z "$ARCANE_KEY" ]]; then
            print_error "Arcane API key is required!"
        fi
    done
    
    # Arcane Environment ID
    # NOTE: Arcane commonly uses numeric environment IDs like "0".
    DEFAULT_ENV_ID="${EXISTING_ENV_ID:-0}"
    read -p "Enter your Arcane environment ID [$DEFAULT_ENV_ID]: " ENV_ID_INPUT
    ENV_ID=${ENV_ID_INPUT:-$DEFAULT_ENV_ID}
    
    # Test API connection
    echo
    print_info "Testing Arcane API connection..."
    ENVIRONMENTS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "X-Api-Key: $ARCANE_KEY" \
        -H "Authorization: Bearer $ARCANE_KEY" \
        "$ARCANE_URL/api/environments" 2>/dev/null || echo "000")
    PROJECTS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "X-Api-Key: $ARCANE_KEY" \
        -H "Authorization: Bearer $ARCANE_KEY" \
        "$ARCANE_URL/api/environments/$ENV_ID/projects" 2>/dev/null || echo "000")

    if [[ "$PROJECTS_STATUS" == "200" ]]; then
        print_success "Successfully connected to Arcane API!"
    else
        print_warning "Could not connect to Arcane API (environments: HTTP $ENVIRONMENTS_STATUS, projects: HTTP $PROJECTS_STATUS)"
        if [[ "$PROJECTS_STATUS" == "404" ]]; then
            print_warning "HTTP 404 usually means your environment ID '$ENV_ID' does not exist."
            print_info "Tip: Arcane commonly uses environment ID '0'. You can list environments with:"
            print_info "  curl -H \"X-Api-Key: <your-key>\" -H \"Authorization: Bearer <your-key>\" \"$ARCANE_URL/api/environments\""
        elif [[ "$ENVIRONMENTS_STATUS" == "404" ]]; then
            print_warning "HTTP 404 on /api/environments usually means your base URL is wrong (or you included '/api' in the URL)."
            print_info "Use the root server URL, like: http://<host>:3552 (not .../api)"
        elif [[ "$ENVIRONMENTS_STATUS" == "401" || "$ENVIRONMENTS_STATUS" == "403" ]]; then
            print_warning "Authentication failed. Please verify your API key is valid and has access."
        elif [[ "$ENVIRONMENTS_STATUS" == "000" || "$PROJECTS_STATUS" == "000" ]]; then
            print_warning "Connection failed. Please verify the server URL is reachable from this machine."
        fi

        read -p "Continue anyway? (y/n) [n]: " -n 1 -r
        echo
        REPLY=${REPLY:-n}
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    echo
    print_info "Projects will be auto-detected from folder names in ${REPO_PATH}"
    print_info "Ensure your folder names match your Arcane project names"
    print_info "Example: ${REPO_PATH}/zerobyte/compose.yaml → Arcane project 'zerobyte'"
    echo

    # Git Authentication Configuration
    print_info "Git Authentication Configuration"
    print_info "Choose how to authenticate with your Git repository:"
    print_info "1. SSH (using private key) - recommended for automated systems"
    print_info "2. HTTPS (using GitHub personal access token)"
    echo

    DEFAULT_AUTH_METHOD="${EXISTING_GIT_AUTH_METHOD:-ssh}"
    read -p "Select authentication method (ssh/https) [$DEFAULT_AUTH_METHOD]: " AUTH_METHOD_INPUT
    AUTH_METHOD=${AUTH_METHOD_INPUT:-$DEFAULT_AUTH_METHOD}

    # Normalize input
    AUTH_METHOD=$(echo "$AUTH_METHOD" | tr '[:upper:]' '[:lower:]')

    SSH_KEY_PATH=""
    HTTPS_TOKEN=""

    if [[ "$AUTH_METHOD" == "ssh" ]]; then
        DEFAULT_SSH_KEY_PATH="${EXISTING_GIT_SSH_KEY_PATH:-/root/.ssh/id_rsa}"
        read -p "Enter the path to your SSH private key [$DEFAULT_SSH_KEY_PATH]: " SSH_KEY_INPUT
        SSH_KEY_PATH=${SSH_KEY_INPUT:-$DEFAULT_SSH_KEY_PATH}

        if [[ ! -f "$SSH_KEY_PATH" ]]; then
            print_warning "SSH key file not found at ${SSH_KEY_PATH}"
            print_warning "Make sure to create it before running the service"
        else
            print_success "SSH key configured: ${SSH_KEY_PATH}"
        fi
    elif [[ "$AUTH_METHOD" == "https" ]]; then
        print_info "GitHub Personal Access Token:"
        print_info "Create a token at: https://github.com/settings/tokens"
        print_info "Required scopes: repo (full control of private repositories)"
        echo

        if [[ -n "$EXISTING_GIT_HTTPS_TOKEN" ]]; then
            read -s -p "Enter your GitHub personal access token [press Enter to keep existing]: " HTTPS_TOKEN_INPUT
            echo
            HTTPS_TOKEN=${HTTPS_TOKEN_INPUT:-$EXISTING_GIT_HTTPS_TOKEN}
        fi

        while [[ -z "${HTTPS_TOKEN:-}" ]]; do
            read -s -p "Enter your GitHub personal access token: " HTTPS_TOKEN
            echo
            if [[ -z "$HTTPS_TOKEN" ]]; then
                print_error "GitHub personal access token is required!"
            fi
        done

        print_success "GitHub HTTPS authentication configured"
    else
        print_error "Invalid authentication method. Using default (ssh)"
        AUTH_METHOD="ssh"
        DEFAULT_SSH_KEY_PATH="${EXISTING_GIT_SSH_KEY_PATH:-/root/.ssh/id_rsa}"
        read -p "Enter the path to your SSH private key [$DEFAULT_SSH_KEY_PATH]: " SSH_KEY_INPUT
        SSH_KEY_PATH=${SSH_KEY_INPUT:-$DEFAULT_SSH_KEY_PATH}
    fi
    
    # Create config file
    cat > ${CONFIG_PATH}/config.env <<EOF
# Docker Compose Git Sync Configuration
# Generated by install.sh on $(date)

# Git repository path (projects are discovered within this directory)
COMPOSE_REPO_PATH=${REPO_PATH}

# Git Authentication Method (ssh or https)
GIT_AUTH_METHOD=${AUTH_METHOD}

# Arcane API Configuration
ARCANE_BASE_URL=${ARCANE_URL}
ARCANE_API_KEY=${ARCANE_KEY}
ARCANE_ENV_ID=${ENV_ID}

# Log file location
LOG_FILE=/var/log/arcane-gitops.log
EOF

    # Add SSH key path if configured
    if [[ "$AUTH_METHOD" == "ssh" && -n "$SSH_KEY_PATH" ]]; then
        echo "" >> ${CONFIG_PATH}/config.env
        echo "# Git SSH private key for repository access" >> ${CONFIG_PATH}/config.env
        echo "GIT_SSH_KEY_PATH=${SSH_KEY_PATH}" >> ${CONFIG_PATH}/config.env
    fi

    # Add HTTPS token if configured
    if [[ "$AUTH_METHOD" == "https" && -n "$HTTPS_TOKEN" ]]; then
        echo "" >> ${CONFIG_PATH}/config.env
        echo "# GitHub personal access token for HTTPS authentication" >> ${CONFIG_PATH}/config.env
        echo "GIT_HTTPS_TOKEN=${HTTPS_TOKEN}" >> ${CONFIG_PATH}/config.env
    fi
    
    echo "" >> ${CONFIG_PATH}/config.env
    echo "# NOTE: Projects are auto-detected based on folder names" >> ${CONFIG_PATH}/config.env
    echo "# Folder name must match Arcane project name (e.g., zerobyte folder → 'zerobyte' project)" >> ${CONFIG_PATH}/config.env
    
    chmod 600 ${CONFIG_PATH}/config.env
    print_success "Configuration created at ${CONFIG_PATH}/config.env"
    
    # Verify the configuration
    echo
    print_info "Verifying configuration..."
    if [[ -f "${CONFIG_PATH}/config.env" ]]; then
        if grep -q "ARCANE_BASE_URL=" "${CONFIG_PATH}/config.env" && grep -q "ARCANE_API_KEY=" "${CONFIG_PATH}/config.env"; then
            print_success "Config file created successfully"
            echo
            print_info "Configuration summary:"
            echo "  Repository: ${REPO_PATH}"
            echo "  Git auth method: ${AUTH_METHOD}"
            if [[ "$AUTH_METHOD" == "ssh" ]]; then
                echo "  SSH key: ${SSH_KEY_PATH}"
            else
                echo "  HTTPS token: ***MASKED***"
            fi
            echo "  Arcane URL: ${ARCANE_URL}"
            echo "  Arcane environment: ${ENV_ID}"
        else
            print_error "Config file is missing required values!"
            cat "${CONFIG_PATH}/config.env"
            exit 1
        fi
    else
        print_error "Failed to create config file!"
        exit 1
    fi
}

install_systemd_files() {
    print_info "Installing systemd service and timer..."
    
    install -m 644 arcane-gitops.service ${SERVICE_PATH}/arcane-gitops.service
    install -m 644 arcane-gitops.timer ${SERVICE_PATH}/arcane-gitops.timer
    
    systemctl daemon-reload
    print_success "Systemd files installed"
}

enable_service() {
    print_info "Enabling and starting timer..."
    
    systemctl enable arcane-gitops.timer
    systemctl start arcane-gitops.timer
    
    print_success "Timer enabled and started"
    echo
    print_info "Timer status:"
    systemctl status arcane-gitops.timer --no-pager
}

test_run() {
    echo
    print_info "Would you like to test the sync now?"
    read -p "Run a test sync? (y/n) [n]: " -n 1 -r
    echo
    REPLY=${REPLY:-n}
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo
        print_info "Verifying config file one more time..."
        if [[ -f "${CONFIG_PATH}/config.env" ]]; then
            print_info "Config file exists at ${CONFIG_PATH}/config.env"
            print_info "Config contents (API key masked):"
            cat "${CONFIG_PATH}/config.env" | sed 's/ARCANE_API_KEY=.*/ARCANE_API_KEY=***MASKED***/'
            echo
        else
            print_error "Config file not found at ${CONFIG_PATH}/config.env!"
            return 1
        fi
        
        print_info "Running test sync..."
        if systemctl start arcane-gitops.service; then
            sleep 3
            print_info "Service logs:"
            journalctl -u arcane-gitops.service -n 50 --no-pager
        else
            print_error "Failed to start service"
            journalctl -u arcane-gitops.service -n 50 --no-pager
        fi
    fi
}

print_next_steps() {
    echo
    echo "=========================================="
    print_success "Installation complete!"
    echo "=========================================="
    echo
    echo "Next steps:"
    echo
    echo "1. Check timer status:"
    echo "   systemctl status arcane-gitops.timer"
    echo
    echo "2. View logs:"
    echo "   journalctl -u arcane-gitops.service -f"
    echo
    echo "3. Manual run:"
    echo "   systemctl start arcane-gitops.service"
    echo
    echo "4. Edit configuration:"
    echo "   nano ${CONFIG_PATH}/config.env"
    echo
    echo "5. Adjust sync frequency:"
    echo "   nano ${SERVICE_PATH}/arcane-gitops.timer"
    echo "   systemctl daemon-reload"
    echo "   systemctl restart arcane-gitops.timer"
    echo
}

uninstall() {
    echo "=========================================="
    echo "  Docker Compose Git Sync Uninstaller"
    echo "=========================================="
    echo

    check_root

    print_warning "This will remove arcane-gitops from your system"
    echo
    read -p "Are you sure you want to uninstall? (y/n) [n]: " -n 1 -r
    echo
    REPLY=${REPLY:-n}
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Uninstall cancelled"
        exit 0
    fi

    # Stop and disable the timer
    print_info "Stopping timer and service..."
    systemctl stop arcane-gitops.timer 2>/dev/null || true
    systemctl stop arcane-gitops.service 2>/dev/null || true
    systemctl disable arcane-gitops.timer 2>/dev/null || true
    systemctl disable arcane-gitops.service 2>/dev/null || true
    print_success "Service stopped and disabled"

    # Remove systemd files
    print_info "Removing systemd files..."
    rm -f ${SERVICE_PATH}/arcane-gitops.service
    rm -f ${SERVICE_PATH}/arcane-gitops.timer
    systemctl daemon-reload
    print_success "Systemd files removed"

    # Remove binary
    print_info "Removing binary..."
    rm -f ${INSTALL_PATH}/${BINARY_NAME}
    print_success "Binary removed"

    # Ask about config directory
    print_warning "Configuration directory: ${CONFIG_PATH}"
    read -p "Remove configuration directory and config files? (y/n) [n]: " -n 1 -r
    echo
    REPLY=${REPLY:-n}
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Removing configuration directory..."
        rm -rf ${CONFIG_PATH}
        print_success "Configuration directory removed"
    else
        print_info "Keeping configuration directory at ${CONFIG_PATH}"
    fi

    echo
    echo "=========================================="
    print_success "Uninstall complete!"
    echo "=========================================="
    echo
    print_info "arcane-gitops has been removed from your system"
    if [[ -d ${CONFIG_PATH} ]]; then
        print_info "Configuration remains at ${CONFIG_PATH}"
    fi
    echo
}

main() {
    # Handle command-line arguments
    if [[ "${1:-}" == "--uninstall" ]]; then
        uninstall
        return
    fi

    echo "=========================================="
    echo "  Docker Compose Git Sync Installer"
    echo "  (Arcane API Edition)"
    echo "=========================================="
    echo

    check_root
    check_go
    check_git

    echo
    print_info "Starting installation..."

    build_binary
    install_binary
    create_config
    install_systemd_files
    enable_service

    test_run
    print_next_steps
}

# Run main function with arguments
main "$@"
