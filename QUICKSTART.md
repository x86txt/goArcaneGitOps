# Quick Start Guide

Get up and running in 5 minutes!

## Prerequisites

- Go 1.21+
- Git
- Docker Compose
- Root/sudo access

## Installation

### Option 1: Interactive Install (Recommended)

```bash
# Make install script executable
chmod +x install.sh

# Run the installer (it will guide you through everything)
sudo ./install.sh
```

The installer will:
- Check prerequisites
- Install Arcane CLI if needed
- Configure Arcane CLI
- Build and install the binary
- Create configuration
- Set up systemd service and timer
- Run a test

### Option 2: Manual Install

```bash
# 1. Install Arcane CLI
go install go.getarcane.app/cli/cmd/arcane@latest

# 2. Configure Arcane CLI
arcane config set --server-url http://localhost:3552 --api-key YOUR_API_KEY

# 3. Build and install
make install

# 4. Configure
sudo cp /etc/sync-tool/config.env.example /etc/sync-tool/config.env
sudo nano /etc/sync-tool/config.env

# 5. Enable service
sudo systemctl enable sync-tool.timer
sudo systemctl start sync-tool.timer
```

## Configuration

Edit `/etc/sync-tool/config.env`:

```bash
# Path to your git repository
COMPOSE_REPO_PATH=/path/to/your/docker-compose-repo

# Root path where projects are deployed (e.g., /opt/docker)
PROJECTS_ROOT_PATH=/opt/docker

# Arcane environment ID
ARCANE_ENV_ID=0

# Optional: SSH key for private repositories
GIT_SSH_KEY_PATH=/root/.ssh/id_rsa
```

**Important:** Projects are auto-created from git (GitOps workflow)!
- Just create a folder with `compose.yaml` and push to git
- Sync-tool automatically creates the Arcane project
- Example: Push `myapp/compose.yaml` → Arcane project `myapp` is auto-created

**No Manual Setup Needed:**
- ✅ Create folder in git repo
- ✅ Add compose.yaml file
- ✅ Push to git
- ✅ Sync-tool handles the rest!

```bash
# Create a new project
cd /path/to/dockerGitOps
mkdir mynewapp
cat > mynewapp/compose.yaml <<EOF
services:
  web:
    image: nginx:alpine
    ports:
      - "8080:80"
EOF

# Push to git
git add mynewapp/
git commit -m "feat: add mynewapp"
git push

# That's it! Sync-tool will:
# 1. Detect the new mynewapp/compose.yaml
# 2. Create Arcane project "mynewapp"
# 3. Deploy it automatically
```

**Setup SSH Key for Private Repos:**
```bash
# Generate SSH key if needed
ssh-keygen -t ed25519 -C "sync-tool" -f /root/.ssh/sync-tool_key

# Add public key to GitHub/GitLab
cat /root/.ssh/sync-tool_key.pub

# Update config with key path
sudo nano /etc/sync-tool/config.env
# Add: GIT_SSH_KEY_PATH=/root/.ssh/sync-tool_key
```

## Testing

```bash
# Run once manually
sudo systemctl start sync-tool.service

# Watch logs
sudo journalctl -u sync-tool.service -f
```

## Common Commands

```bash
# Check status
make status

# View logs
make logs

# Rebuild and reinstall
make install

# Uninstall
make uninstall
```

## Troubleshooting

### Can't find Arcane CLI?

```bash
# Check if it's installed
which arcane

# If not in PATH, add Go bin to PATH
echo 'export PATH="$PATH:$HOME/go/bin"' >> ~/.bashrc
source ~/.bashrc
```

### Git authentication issues?

```bash
# For SSH
ssh-add -l  # Check if key is loaded
ssh -T git@github.com  # Test connection

# For HTTPS
git config --global credential.helper store
```

### Finding Project ID?

```bash
# List projects
arcane project list

# Or check Arcane UI URL when viewing your project
```

For detailed documentation, see [README.md](README.md)
