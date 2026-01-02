# Sync Tool - Docker Compose GitOps for Arcane

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
> **Quick start**: `git clone https://github.com/x86txt/goArcaneGitOps.git && cd goArcaneGitOps && sudo ./install.sh`

### Quick Install (Interactive)

```bash
sudo ./install.sh
```

The installer will:
1. Build the binary
2. Prompt for configuration (repo path, Arcane URL, API key)
3. Install systemd service and timer
4. Run an initial test sync

### Manual Installation

```bash
# Build
go build -o sync-tool main.go

# Install binary
sudo install -m 755 sync-tool /usr/local/bin/sync-tool

# Create config
sudo mkdir -p /etc/sync-tool
sudo cp config.env.example /etc/sync-tool/config.env
sudo nano /etc/sync-tool/config.env  # Edit with your values

# Install systemd files
sudo cp sync-tool.service sync-tool.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now sync-tool.timer
```

## Configuration

Create `/etc/sync-tool/config.env` with:

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
4. Give it a name (e.g., "sync-tool")
5. Copy the key immediately (it won't be shown again!)

## Usage

### Manual Run

```bash
# Run sync now
sudo systemctl start sync-tool.service

# View logs
sudo journalctl -u sync-tool.service -f
```

### Timer Status

```bash
# Check when next sync will run
sudo systemctl status sync-tool.timer

# List all timers
sudo systemctl list-timers
```

### Adjust Sync Frequency

Edit `/etc/systemd/system/sync-tool.timer`:

```ini
[Timer]
OnBootSec=1min
OnUnitActiveSec=5min  # Change this value
```

Then reload:

```bash
sudo systemctl daemon-reload
sudo systemctl restart sync-tool.timer
```

## Project Structure

Your git repository should be organized like:

```
/opt/docker/
├── zerobyte/
│   └── compose.yaml
├── bittorrent/
│   └── compose.yaml
├── nginx-test/
│   └── compose.yaml
└── syncTool/           # (excluded from scanning)
    └── ...
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
cat /etc/sync-tool/config.env
```

### Test API Connection

```bash
curl -H "X-Api-Key: YOUR_KEY" http://localhost:3552/api/environments/default/projects
```

### View Detailed Logs

```bash
sudo journalctl -u sync-tool.service -n 100 --no-pager
```

### Force Sync

If projects are out of sync, the tool will automatically reconcile on next run. To force it:

```bash
sudo systemctl start sync-tool.service
```

## License

MIT
