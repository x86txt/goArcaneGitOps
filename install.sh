#!/bin/bash

#############################################################################
# Arcane GitOps Installer
# Detects system architecture, downloads the correct binary, and configures
#
# Features:
#   - Automatic platform detection (Linux/macOS/Windows, multiple architectures)
#   - Downloads latest release from GitHub
#   - Interactive configuration with optional gum support for enhanced UX
#   - Systemd service installation and configuration
#   - Accessibility: --no-unicode and --no-color flags for compatibility
#   - Performance optimized: minimal dependencies, non-blocking operations
#
# Usage:
#   sudo ./install.sh                    # Standard installation
#   sudo ./install.sh --no-unicode       # ASCII-only mode (for older terminals)
#   sudo ./install.sh --no-color         # Disable colors (for screen readers)
#   sudo ./install.sh --help             # Show help
#
# Requirements:
#   - curl or wget (for downloading)
#   - systemd (for service installation)
#   - Optional: gum (for enhanced interactive prompts)
#
#############################################################################

set -e

#############################################################################
# Parse Command Line Arguments
#############################################################################

USE_UNICODE=true
USE_COLOR=true

while [[ $# -gt 0 ]]; do
    case $1 in
        --no-unicode)
            USE_UNICODE=false
            shift
            ;;
        --no-color)
            USE_COLOR=false
            shift
            ;;
        --help)
            echo "Arcane GitOps Installer"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --no-unicode    Use ASCII characters instead of Unicode"
            echo "  --no-color      Disable colored output"
            echo "  --help          Show this help message"
            echo ""
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Run '$0 --help' for usage information"
            exit 1
            ;;
    esac
done

# Color codes for pretty output (conditionally enabled)
if [ "$USE_COLOR" = true ]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly MAGENTA='\033[0;35m'
    readonly CYAN='\033[0;36m'
    readonly BOLD='\033[1m'
    readonly DIM='\033[2m'
    readonly NC='\033[0m' # No Color
else
    readonly RED=''
    readonly GREEN=''
    readonly YELLOW=''
    readonly BLUE=''
    readonly MAGENTA=''
    readonly CYAN=''
    readonly BOLD=''
    readonly DIM=''
    readonly NC=''
fi

# Unicode or ASCII characters for visual enhancement
if [ "$USE_UNICODE" = true ]; then
    readonly CHECK="✓"
    readonly CROSS="✗"
    readonly ARROW="→"
    readonly BULLET="•"
    readonly STAR="★"
    readonly BOX_H="═"
    readonly BOX_V="║"
    readonly BOX_TL="╔"
    readonly BOX_TR="╗"
    readonly BOX_BL="╚"
    readonly BOX_BR="╝"
    readonly SPINNER_CHARS='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    readonly PROGRESS_FULL="█"
    readonly PROGRESS_EMPTY="░"
else
    readonly CHECK="[OK]"
    readonly CROSS="[X]"
    readonly ARROW="->"
    readonly BULLET="*"
    readonly STAR="*"
    readonly BOX_H="="
    readonly BOX_V="|"
    readonly BOX_TL="+"
    readonly BOX_TR="+"
    readonly BOX_BL="+"
    readonly BOX_BR="+"
    readonly SPINNER_CHARS='|/-\\'
    readonly PROGRESS_FULL="#"
    readonly PROGRESS_EMPTY="-"
fi

# GitHub repository information
readonly GITHUB_REPO="x86txt/goArcaneGitOps"
readonly BINARY_NAME="arcane-gitops"
readonly CONFIG_DIR="/etc/arcane-gitops"
readonly CONFIG_FILE="${CONFIG_DIR}/config.env"
readonly INSTALL_DIR="/usr/local/bin"

#############################################################################
# Helper Functions
#############################################################################

# Print functions with visual flair
print_header() {
    local box_width=62
    local title=" ${STAR} Arcane GitOps Installer "
    local padding=$(( (box_width - ${#title}) / 2 ))

    echo -e "\n${BOLD}${MAGENTA}${BOX_TL}$(printf '%*s' $box_width '' | tr ' ' "${BOX_H}")${BOX_TR}${NC}"
    echo -e "${BOLD}${MAGENTA}${BOX_V}${NC}$(printf '%*s' $padding '')${CYAN}${title}${NC}$(printf '%*s' $padding '')${BOLD}${MAGENTA}${BOX_V}${NC}"
    echo -e "${BOLD}${MAGENTA}${BOX_BL}$(printf '%*s' $box_width '' | tr ' ' "${BOX_H}")${BOX_BR}${NC}\n"
}

print_section() {
    echo -e "\n${BOLD}${BLUE}${ARROW} $1${NC}"
    if [ "$USE_UNICODE" = true ]; then
        echo -e "${DIM}────────────────────────────────────────────────────────────${NC}"
    else
        echo -e "${DIM}------------------------------------------------------------${NC}"
    fi
}

print_success() {
    echo -e "${GREEN}${CHECK}${NC} $1"
}

print_error() {
    echo -e "${RED}${CROSS}${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}${BULLET}${NC} $1"
}

print_info() {
    echo -e "${CYAN}${BULLET}${NC} $1"
}

print_step() {
    echo -e "  ${DIM}${ARROW}${NC} $1"
}

# Spinner for long-running operations (non-blocking)
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr="${SPINNER_CHARS}"
    local spin_msg="${2:-Processing}"

    while kill -0 $pid 2>/dev/null; do
        local temp=${spinstr#?}
        printf "\r  ${CYAN}%c${NC} ${spin_msg}..." "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
    done
    printf "\r%60s\r" ""  # Clear the line
}

# Progress bar
progress_bar() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((width * current / total))
    local remaining=$((width - completed))

    printf "\r  ${CYAN}["
    printf "%${completed}s" | tr ' ' "${PROGRESS_FULL}"
    printf "%${remaining}s" | tr ' ' "${PROGRESS_EMPTY}"
    printf "]${NC} ${BOLD}%3d%%${NC}" $percentage
}

#############################################################################
# System Detection
#############################################################################

detect_system() {
    print_section "Detecting System Architecture"
    
    # Detect OS
    case "$(uname -s)" in
        Linux*)
            OS="linux"
            print_info "Operating System: ${BOLD}Linux${NC}"
            ;;
        Darwin*)
            OS="darwin"
            print_info "Operating System: ${BOLD}macOS${NC}"
            ;;
        MINGW*|MSYS*|CYGWIN*)
            OS="windows"
            print_info "Operating System: ${BOLD}Windows${NC}"
            ;;
        *)
            print_error "Unsupported operating system: $(uname -s)"
            exit 1
            ;;
    esac
    
    # Detect Architecture
    case "$(uname -m)" in
        x86_64|amd64)
            ARCH="amd64"
            print_info "Architecture: ${BOLD}x86_64${NC}"
            ;;
        aarch64|arm64)
            ARCH="arm64"
            print_info "Architecture: ${BOLD}ARM64${NC}"
            ;;
        armv7l)
            ARCH="armv7"
            print_info "Architecture: ${BOLD}ARMv7${NC}"
            ;;
        *)
            print_error "Unsupported architecture: $(uname -m)"
            exit 1
            ;;
    esac
    
    PLATFORM="${OS}_${ARCH}"
    print_success "Platform detected: ${BOLD}${PLATFORM}${NC}"
}

#############################################################################
# Download Binary
#############################################################################

get_latest_release() {
    print_section "Fetching Latest Release Information"
    
    # Try to get latest release from GitHub API
    print_step "Querying GitHub API..."
    
    if command -v curl >/dev/null 2>&1; then
        LATEST_VERSION=$(curl -s "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    elif command -v wget >/dev/null 2>&1; then
        LATEST_VERSION=$(wget -qO- "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    else
        print_error "Neither curl nor wget found. Please install one of them."
        exit 1
    fi
    
    if [ -z "$LATEST_VERSION" ]; then
        print_error "Failed to fetch latest release version"
        exit 1
    fi
    
    print_success "Latest version: ${BOLD}${LATEST_VERSION}${NC}"
}

download_binary() {
    print_section "Downloading Binary"

    # Strip 'v' from version for archive name (e.g., v0.0.9 -> 0.0.9)
    VERSION_NUMBER="${LATEST_VERSION#v}"

    # Determine archive extension based on OS
    if [ "$OS" = "windows" ]; then
        ARCHIVE_EXT="zip"
    else
        ARCHIVE_EXT="tar.gz"
    fi

    # Construct archive filename: arcane-gitops-VERSION-OS-ARCH.EXTENSION
    ARCHIVE_NAME="${BINARY_NAME}-${VERSION_NUMBER}-${OS}-${ARCH}.${ARCHIVE_EXT}"
    CHECKSUM_NAME="${ARCHIVE_NAME}.sha256"

    # Construct download URLs
    ARCHIVE_URL="https://github.com/${GITHUB_REPO}/releases/download/${LATEST_VERSION}/${ARCHIVE_NAME}"
    CHECKSUM_URL="https://github.com/${GITHUB_REPO}/releases/download/${LATEST_VERSION}/${CHECKSUM_NAME}"

    print_info "Archive: ${DIM}${ARCHIVE_NAME}${NC}"
    print_info "Checksum: ${DIM}${CHECKSUM_NAME}${NC}"

    # Create temporary directory
    TMP_DIR=$(mktemp -d)
    TMP_ARCHIVE="${TMP_DIR}/${ARCHIVE_NAME}"
    TMP_CHECKSUM="${TMP_DIR}/${CHECKSUM_NAME}"
    TMP_BINARY="${TMP_DIR}/${BINARY_NAME}"

    # Download archive
    print_step "Downloading archive..."
    if command -v curl >/dev/null 2>&1; then
        if ! curl -L --fail -o "${TMP_ARCHIVE}" "${ARCHIVE_URL}" 2>&1; then
            print_error "Failed to download archive from ${ARCHIVE_URL}"
            print_warning "Please check if the release exists for your platform"
            rm -rf "${TMP_DIR}"
            exit 1
        fi
    elif command -v wget >/dev/null 2>&1; then
        if ! wget -q -O "${TMP_ARCHIVE}" "${ARCHIVE_URL}" 2>&1; then
            print_error "Failed to download archive from ${ARCHIVE_URL}"
            rm -rf "${TMP_DIR}"
            exit 1
        fi
    fi
    print_success "Archive downloaded"

    # Download checksum
    print_step "Downloading checksum..."
    if command -v curl >/dev/null 2>&1; then
        if ! curl -L --fail -o "${TMP_CHECKSUM}" "${CHECKSUM_URL}" 2>&1; then
            print_error "Failed to download checksum from ${CHECKSUM_URL}"
            rm -rf "${TMP_DIR}"
            exit 1
        fi
    elif command -v wget >/dev/null 2>&1; then
        if ! wget -q -O "${TMP_CHECKSUM}" "${CHECKSUM_URL}" 2>&1; then
            print_error "Failed to download checksum from ${CHECKSUM_URL}"
            rm -rf "${TMP_DIR}"
            exit 1
        fi
    fi
    print_success "Checksum downloaded"

    # Verify checksum
    print_step "Verifying checksum..."
    cd "${TMP_DIR}"
    if command -v sha256sum >/dev/null 2>&1; then
        if ! sha256sum -c "${CHECKSUM_NAME}" 2>&1 | grep -q "OK"; then
            print_error "Checksum verification failed"
            print_warning "The downloaded file may be corrupted or tampered with"
            rm -rf "${TMP_DIR}"
            exit 1
        fi
    elif command -v shasum >/dev/null 2>&1; then
        # macOS
        if ! shasum -a 256 -c "${CHECKSUM_NAME}" 2>&1 | grep -q "OK"; then
            print_error "Checksum verification failed"
            print_warning "The downloaded file may be corrupted or tampered with"
            rm -rf "${TMP_DIR}"
            exit 1
        fi
    else
        print_warning "sha256sum/shasum not found, skipping checksum verification"
    fi
    cd - >/dev/null
    print_success "Checksum verified"

    # Extract archive
    print_step "Extracting archive..."
    cd "${TMP_DIR}"
    if [ "$ARCHIVE_EXT" = "tar.gz" ]; then
        if ! tar -xzf "${ARCHIVE_NAME}" 2>&1; then
            print_error "Failed to extract archive"
            rm -rf "${TMP_DIR}"
            exit 1
        fi
    elif [ "$ARCHIVE_EXT" = "zip" ]; then
        if ! unzip -q "${ARCHIVE_NAME}" 2>&1; then
            print_error "Failed to extract archive"
            rm -rf "${TMP_DIR}"
            exit 1
        fi
    fi
    cd - >/dev/null
    print_success "Archive extracted"

    # Verify binary exists
    if [ ! -f "${TMP_BINARY}" ]; then
        print_error "Binary not found in archive"
        rm -rf "${TMP_DIR}"
        exit 1
    fi

    # Make executable
    chmod +x "${TMP_BINARY}"
    print_success "Binary ready for installation"
}

#############################################################################
# Installation
#############################################################################

check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This installer must be run as root"
        echo -e "\n${YELLOW}Please run: ${BOLD}sudo $0${NC}\n"
        exit 1
    fi
}

install_binary() {
    print_section "Installing Binary"
    
    print_step "Installing to ${INSTALL_DIR}/${BINARY_NAME}..."
    
    # Backup existing binary if it exists
    if [ -f "${INSTALL_DIR}/${BINARY_NAME}" ]; then
        BACKUP="${INSTALL_DIR}/${BINARY_NAME}.backup.$(date +%Y%m%d_%H%M%S)"
        mv "${INSTALL_DIR}/${BINARY_NAME}" "${BACKUP}"
        print_info "Backed up existing binary to ${BACKUP}"
    fi
    
    # Install new binary
    install -m 755 "${TMP_BINARY}" "${INSTALL_DIR}/${BINARY_NAME}"
    print_success "Binary installed to ${BOLD}${INSTALL_DIR}/${BINARY_NAME}${NC}"
    
    # Verify installation
    if [ -x "${INSTALL_DIR}/${BINARY_NAME}" ]; then
        VERSION=$(${INSTALL_DIR}/${BINARY_NAME} --version 2>/dev/null || echo "unknown")
        print_success "Installation verified (version: ${VERSION})"
    fi
}

configure_service() {
    print_section "Configuring System Service"

    # Create config directory
    print_step "Creating configuration directory..."
    mkdir -p "${CONFIG_DIR}"
    print_success "Config directory created: ${CONFIG_DIR}"

    # Interactive configuration with gum support
    echo -e "\n${BOLD}${CYAN}Configuration Setup${NC}"
    if [ "$USE_UNICODE" = true ]; then
        echo -e "${DIM}────────────────────────────────────────────────────────────${NC}"
    else
        echo -e "${DIM}------------------------------------------------------------${NC}"
    fi

    # Check if gum is available for enhanced prompts
    local HAS_GUM=false
    if command -v gum >/dev/null 2>&1; then
        HAS_GUM=true
        print_info "Using enhanced prompts (gum detected)"
    else
        # Offer to install gum for better experience
        echo ""
        read -p "$(echo -e ${CYAN}${BULLET}${NC}) Install 'gum' for enhanced prompts? (y/N): " INSTALL_GUM
        if [[ "$INSTALL_GUM" =~ ^[Yy]$ ]]; then
            print_step "Installing gum..."
            if command -v go >/dev/null 2>&1; then
                if go install github.com/charmbracelet/gum@latest 2>/dev/null; then
                    # Add Go bin to PATH if needed
                    export PATH="$PATH:$(go env GOPATH)/bin"
                    if command -v gum >/dev/null 2>&1; then
                        HAS_GUM=true
                        print_success "Gum installed successfully"
                    else
                        print_warning "Gum installed but not found in PATH. Using standard prompts."
                    fi
                else
                    print_warning "Failed to install gum. Using standard prompts."
                fi
            else
                print_warning "Go not found. Cannot install gum. Using standard prompts."
                print_info "Visit https://github.com/charmbracelet/gum for installation instructions"
            fi
        fi
    fi

    # Repository path
    if [ "$HAS_GUM" = true ]; then
        REPO_PATH=$(gum input \
            --placeholder "/opt/docker" \
            --prompt "${BULLET} Git repository path: " \
            --value "/opt/docker" \
            --width 60)
    else
        read -p "$(echo -e ${CYAN}${BULLET}${NC}) Git repository path [/opt/docker]: " REPO_PATH
        REPO_PATH=${REPO_PATH:-/opt/docker}
    fi

    # Projects root path
    if [ "$HAS_GUM" = true ]; then
        PROJECTS_PATH=$(gum input \
            --placeholder "${REPO_PATH}" \
            --prompt "${BULLET} Projects root path: " \
            --value "${REPO_PATH}" \
            --width 60)
    else
        read -p "$(echo -e ${CYAN}${BULLET}${NC}) Projects root path [${REPO_PATH}]: " PROJECTS_PATH
        PROJECTS_PATH=${PROJECTS_PATH:-${REPO_PATH}}
    fi

    # Arcane base URL
    if [ "$HAS_GUM" = true ]; then
        ARCANE_URL=$(gum input \
            --placeholder "http://localhost:3552" \
            --prompt "${BULLET} Arcane base URL: " \
            --value "http://localhost:3552" \
            --width 60)
    else
        read -p "$(echo -e ${CYAN}${BULLET}${NC}) Arcane base URL [http://localhost:3552]: " ARCANE_URL
        ARCANE_URL=${ARCANE_URL:-http://localhost:3552}
    fi

    # Arcane API key (password mode with gum)
    if [ "$HAS_GUM" = true ]; then
        API_KEY=$(gum input \
            --password \
            --placeholder "Enter your Arcane API key" \
            --prompt "${BULLET} Arcane API key: " \
            --width 60)
        while [ -z "$API_KEY" ]; do
            print_warning "API key cannot be empty"
            API_KEY=$(gum input \
                --password \
                --placeholder "Enter your Arcane API key" \
                --prompt "${BULLET} Arcane API key: " \
                --width 60)
        done
    else
        read -sp "$(echo -e ${CYAN}${BULLET}${NC}) Arcane API key: " API_KEY
        echo ""  # New line after password input
        while [ -z "$API_KEY" ]; do
            print_warning "API key cannot be empty"
            read -sp "$(echo -e ${CYAN}${BULLET}${NC}) Arcane API key: " API_KEY
            echo ""
        done
    fi

    # Environment ID
    if [ "$HAS_GUM" = true ]; then
        ENV_ID=$(gum input \
            --placeholder "0" \
            --prompt "${BULLET} Arcane environment ID: " \
            --value "0" \
            --width 60)
    else
        read -p "$(echo -e ${CYAN}${BULLET}${NC}) Arcane environment ID [0]: " ENV_ID
        ENV_ID=${ENV_ID:-0}
    fi

    # SSH key path (optional)
    if [ "$HAS_GUM" = true ]; then
        if gum confirm "${BULLET} Configure SSH key for private repositories?"; then
            SSH_KEY=$(gum file --height 15 --file 2>/dev/null || true)
            if [ -z "$SSH_KEY" ]; then
                SSH_KEY=$(gum input \
                    --placeholder "/root/.ssh/id_rsa" \
                    --prompt "${BULLET} SSH key path: " \
                    --width 60)
            fi
        else
            SSH_KEY=""
        fi
    else
        read -p "$(echo -e ${CYAN}${BULLET}${NC}) SSH key path (optional, press Enter to skip): " SSH_KEY
    fi

    # Validate SSH key if provided
    if [ -n "$SSH_KEY" ] && [ ! -f "$SSH_KEY" ]; then
        print_warning "SSH key not found at: ${SSH_KEY}"
        print_info "You can update this later in ${CONFIG_FILE}"
    fi
    
    # Write configuration
    cat > "${CONFIG_FILE}" <<EOF
# Arcane GitOps Configuration
# Generated: $(date)

# Git repository path
COMPOSE_REPO_PATH=${REPO_PATH}

# Projects root path
PROJECTS_ROOT_PATH=${PROJECTS_PATH}

# Arcane API configuration
ARCANE_BASE_URL=${ARCANE_URL}
ARCANE_API_KEY=${API_KEY}
ARCANE_ENV_ID=${ENV_ID}

EOF
    
    if [ -n "$SSH_KEY" ]; then
        echo "# SSH key for private repos" >> "${CONFIG_FILE}"
        echo "GIT_SSH_KEY_PATH=${SSH_KEY}" >> "${CONFIG_FILE}"
    fi
    
    chmod 600 "${CONFIG_FILE}"
    print_success "Configuration saved to ${CONFIG_FILE}"
    
    # Install systemd files if they exist
    if [ -f "arcane-gitops.service" ] && [ -f "arcane-gitops.timer" ]; then
        print_step "Installing systemd service files..."
        cp arcane-gitops.service arcane-gitops.timer /etc/systemd/system/
        systemctl daemon-reload
        print_success "Systemd files installed"
        
        # Enable and start timer
        print_step "Enabling systemd timer..."
        systemctl enable arcane-gitops.timer
        systemctl start arcane-gitops.timer
        print_success "Timer enabled and started"
    else
        print_warning "Systemd service files not found in current directory"
        print_info "You may need to configure systemd manually"
    fi
}

test_installation() {
    print_section "Testing Installation"
    
    print_step "Running test sync..."
    echo ""
    
    if systemctl start arcane-gitops.service; then
        sleep 2
        print_success "Test sync completed successfully"
        
        echo -e "\n${CYAN}${BULLET}${NC} View logs with:"
        echo -e "  ${DIM}sudo journalctl -u arcane-gitops.service -f${NC}"
    else
        print_warning "Test sync failed - check configuration"
        echo -e "\n${CYAN}${BULLET}${NC} Debug with:"
        echo -e "  ${DIM}sudo journalctl -u arcane-gitops.service -n 50${NC}"
    fi
}

print_summary() {
    local box_width=62
    local title=" ${CHECK} Installation Complete! "
    local padding=$(( (box_width - ${#title}) / 2 ))

    echo -e "\n${BOLD}${GREEN}${BOX_TL}$(printf '%*s' $box_width '' | tr ' ' "${BOX_H}")${BOX_TR}${NC}"
    echo -e "${BOLD}${GREEN}${BOX_V}${NC}$(printf '%*s' $padding '')${title}$(printf '%*s' $padding '')${BOLD}${GREEN}${BOX_V}${NC}"
    echo -e "${BOLD}${GREEN}${BOX_BL}$(printf '%*s' $box_width '' | tr ' ' "${BOX_H}")${BOX_BR}${NC}\n"
    
    echo -e "${BOLD}${CYAN}Quick Start:${NC}"
    echo -e "${BULLET} ${DIM}Manual sync:${NC}      sudo systemctl start arcane-gitops.service"
    echo -e "${BULLET} ${DIM}View logs:${NC}        sudo journalctl -u arcane-gitops.service -f"
    echo -e "${BULLET} ${DIM}Check timer:${NC}      sudo systemctl status arcane-gitops.timer"
    echo -e "${BULLET} ${DIM}Configuration:${NC}    ${CONFIG_FILE}"
    
    echo -e "\n${BOLD}${CYAN}Next Steps:${NC}"
    echo -e "${BULLET} Ensure your Git repository is accessible"
    echo -e "${BULLET} Verify API key has proper permissions"
    echo -e "${BULLET} Check that compose.yaml files are in place"
    
    echo -e "\n${DIM}For more information, visit:${NC}"
    echo -e "${CYAN}https://github.com/${GITHUB_REPO}${NC}\n"
}

cleanup() {
    if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
        rm -rf "$TMP_DIR"
    fi
}

#############################################################################
# Main Installation Flow
#############################################################################

main() {
    trap cleanup EXIT
    
    print_header
    check_root
    detect_system
    get_latest_release
    download_binary
    install_binary
    configure_service
    test_installation
    print_summary
}

# Run main installation
main "$@"
