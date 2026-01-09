> [!IMPORTANT]
> Please note, this repo has been retired because GitOps has been rolled into the official Arcane client.

# Sync Tool - Docker Compose GitOps for Arcane

[![CI Lint & Test](https://github.com/x86txt/goArcaneGitOps/actions/workflows/ci.yml/badge.svg)](https://github.com/x86txt/goArcaneGitOps/actions/workflows/ci.yml)
[![Go Report Card](https://goreportcard.com/badge/github.com/x86txt/goArcaneGitOps)](https://goreportcard.com/report/github.com/x86txt/goArcaneGitOps)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A GitOps-style sync tool that automatically synchronizes Docker Compose projects from a Git repository to [Arcane](https://getarcane.app).

## Features

- **GitOps Workflow**: Git is the single source of truth - all changes are pulled from remote
- **Automatic Project Creation**: New folders with `compose.yaml` are automatically created in Arcane
- **Selective Deployment**: Only changed projects are redeployed
- **Disk-to-Arcane Reconciliation**: Compares projects on disk with Arcane and syncs any differences
- **API-First**: Uses Arcane REST API for all operations (no CLI dependency)
- **Private Repo Support**: Configure SSH keys for accessing private Git repositories

## How It Works

1. **Git Sync**: Fetches and force-resets to remote `origin/main` (local changes are discarded)
2. **Project Discovery**: Scans for folders containing `compose.yaml` files
3. **Arcane Comparison**: Lists projects in Arcane via API and compares with disk
4. **Create Missing**: Creates any projects that exist on disk but not in Arcane
5. **Update Changed**: Updates and redeploys projects that changed in git

## Requirements

- Go 1.21+
- Git
- Arcane instance with API access
- Arcane API key (generate in Settings → API Keys)

## Installation

> [!TIP]
> **One-line install**: `curl -fsSL https://raw.githubusercontent.com/x86txt/goArcaneGitOps/main/install.sh | sudo bash`

### Quick Install (Recommended)

**Remote install without cloning:**
```bash
# Using curl
curl -fsSL https://raw.githubusercontent.com/x86txt/goArcaneGitOps/main/install.sh | sudo bash

# Or using wget
wget -qO- https://raw.githubusercontent.com/x86txt/goArcaneGitOps/main/install.sh | sudo bash
```

**Or clone and run locally:**
```bash
git clone https://github.com/x86txt/goArcaneGitOps.git
cd goArcaneGitOps
sudo ./install.sh
```

**Installation options:**
```bash
# Standard installation (with colors and Unicode)
sudo ./install.sh

# ASCII-only mode (for older terminals)
sudo ./install.sh --no-unicode

# No colors (for screen readers)
sudo ./install.sh --no-color

# Maximum compatibility
sudo ./install.sh --no-unicode --no-color
```

The installer will:
1. Detect your system architecture
2. Download the latest pre-built binary from GitHub releases
3. Prompt for configuration (repo path, Arcane URL, API key)
4. Install systemd service and timer
5. Run an initial test sync

> [!NOTE]
> The installer supports optional [gum](https://github.com/charmbracelet/gum) integration for enhanced interactive prompts. If Go is available, the installer can install it for you.

### Manual Installation

```bash
# Build
go build -o arcane-gitops main.go

# Install binary
sudo install -m 755 arcane-gitops /usr/local/bin/arcane-gitops

# Create config
sudo mkdir -p /etc/arcane-gitops
sudo cp config.env.example /etc/arcane-gitops/config.env
sudo nano /etc/arcane-gitops/config.env  # Edit with your values

# Install systemd files
sudo cp arcane-gitops.service arcane-gitops.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now arcane-gitops.timer
```

## Configuration

Create `/etc/arcane-gitops/config.env` with:

```bash
# Git repository path (where compose files live)
COMPOSE_REPO_PATH=/opt/docker

# Projects root path (usually same as repo path)
PROJECTS_ROOT_PATH=/opt/docker

# Arcane API configuration
ARCANE_BASE_URL=http://localhost:3552
ARCANE_API_KEY=your_api_key_here
ARCANE_ENV_ID=0

# Optional: SSH key for private repos
GIT_SSH_KEY_PATH=/root/.ssh/id_rsa
```

### Getting an Arcane API Key

1. Log in to Arcane
2. Go to **Settings** → **API Keys**
3. Click **Add API Key**
4. Give it a name (e.g., "arcane-gitops")
5. Copy the key immediately (it won't be shown again!)

## Usage

### Manual Run

```bash
# Run sync now
sudo systemctl start arcane-gitops.service

# View logs
sudo journalctl -u arcane-gitops.service -f
```

### Timer Status

```bash
# Check when next sync will run
sudo systemctl status arcane-gitops.timer

# List all timers
sudo systemctl list-timers
```

### Adjust Sync Frequency

Edit `/etc/systemd/system/arcane-gitops.timer`:

```ini
[Timer]
OnBootSec=1min
OnUnitActiveSec=5min  # Change this value
```

Then reload:

```bash
sudo systemctl daemon-reload
sudo systemctl restart arcane-gitops.timer
```

## Project Structure

Your source git repository should be organized like:

```
.
├── arcane
│   └── compose.yaml
├── bittorrent
│   └── compose.yaml
├── cinephage
│   └── compose.yaml
├── tautulli
│   └── compose.yaml
├── usenet
│   └── compose.yaml
└── zerobyte
    └── compose.yaml
```

Each folder name becomes the Arcane project name.

## API Endpoints Used

The tool uses these Arcane API endpoints:

| Operation | Method | Endpoint |
|-----------|--------|----------|
| List projects | GET | `/api/environments/{id}/projects` |
| Create project | POST | `/api/environments/{id}/projects` |
| Update project | PUT | `/api/environments/{id}/projects/{projectId}` |
| Start project | POST | `/api/environments/{id}/projects/{projectId}/up` |
| Redeploy project | POST | `/api/environments/{id}/projects/{projectId}/redeploy` |

## Troubleshooting

### Check Config

```bash
cat /etc/arcane-gitops/config.env
```

### Test API Connection

```bash
curl -H "X-Api-Key: YOUR_KEY" http://localhost:3552/api/environments/default/projects
```

### View Detailed Logs

```bash
sudo journalctl -u arcane-gitops.service -n 100 --no-pager
```

### Force Sync

If projects are out of sync, the tool will automatically reconcile on next run. To force it:

```bash
sudo systemctl start arcane-gitops.service
```

## License

MIT
