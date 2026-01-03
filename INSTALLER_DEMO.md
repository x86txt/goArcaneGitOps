# Install.sh Visual Demo

This document shows the visual improvements to the installer script.

## 🎨 Visual Comparison

### Header (Unicode Mode)
```
╔══════════════════════════════════════════════════════════════╗
║  ★ Arcane GitOps Installer                                   ║
╚══════════════════════════════════════════════════════════════╝
```

### Header (ASCII Mode with --no-unicode)
```
+==============================================================+
|  * Arcane GitOps Installer                                   |
+==============================================================+
```

---

## 📝 Configuration Prompts

### With Gum (Enhanced Experience)
```
→ Configuring System Service
────────────────────────────────────────────────────────────

Configuration Setup
────────────────────────────────────────────────────────────
✓ Config directory created: /etc/arcane-gitops
• Using enhanced prompts (gum detected)

┃ • Git repository path: █
┃ /opt/docker

┃ • Arcane API key: ⣿⣿⣿⣿⣿⣿⣿⣿
┃ (password masked)

┃ • Configure SSH key for private repositories? (Y/n)
┃ ❯ Yes
┃   No
```

### Without Gum (Standard Prompts)
```
-> Configuring System Service
------------------------------------------------------------

Configuration Setup
------------------------------------------------------------
[OK] Config directory created: /etc/arcane-gitops

* Git repository path [/opt/docker]: _

* Arcane API key: (hidden input)

* SSH key path (optional, press Enter to skip): _
```

---

## 🎯 Progress Indicators

### Download Progress (Unicode)
```
  [████████████████████░░░░░░░░░░] 75%
```

### Download Progress (ASCII)
```
  [###########################-----------------] 75%
```

### Spinner (Unicode)
```
  ⠋ Downloading binary...
```

### Spinner (ASCII)
```
  | Processing...
```

---

## ✅ Status Messages

### Success Messages

**Unicode Mode:**
```
✓ Binary downloaded successfully
✓ Installation verified (version: v1.0.0)
✓ Config directory created: /etc/arcane-gitops
```

**ASCII Mode:**
```
[OK] Binary downloaded successfully
[OK] Installation verified (version: v1.0.0)
[OK] Config directory created: /etc/arcane-gitops
```

### Warning Messages

**Unicode Mode:**
```
• SSH key not found at: /root/.ssh/id_rsa
• You can update this later in /etc/arcane-gitops/config.env
```

**ASCII Mode:**
```
* SSH key not found at: /root/.ssh/id_rsa
* You can update this later in /etc/arcane-gitops/config.env
```

### Error Messages

**Unicode Mode:**
```
✗ Failed to download binary from URL
✗ Please check if the release exists for your platform
```

**ASCII Mode:**
```
[X] Failed to download binary from URL
[X] Please check if the release exists for your platform
```

---

## 🚀 Command Examples

### Standard Installation
```bash
$ sudo ./install.sh

╔══════════════════════════════════════════════════════════════╗
║  ★ Arcane GitOps Installer                                   ║
╚══════════════════════════════════════════════════════════════╝

→ Detecting System Architecture
────────────────────────────────────────────────────────────
• Operating System: Linux
• Architecture: x86_64
✓ Platform detected: linux_amd64

→ Fetching Latest Release Information
────────────────────────────────────────────────────────────
  → Querying GitHub API...
✓ Latest version: v1.0.0
```

### ASCII-Only Mode
```bash
$ sudo ./install.sh --no-unicode

+==============================================================+
|  * Arcane GitOps Installer                                   |
+==============================================================+

-> Detecting System Architecture
------------------------------------------------------------
* Operating System: Linux
* Architecture: x86_64
[OK] Platform detected: linux_amd64

-> Fetching Latest Release Information
------------------------------------------------------------
  -> Querying GitHub API...
[OK] Latest version: v1.0.0
```

### No Color Mode
```bash
$ sudo ./install.sh --no-color

╔══════════════════════════════════════════════════════════════╗
║  ★ Arcane GitOps Installer                                   ║
╚══════════════════════════════════════════════════════════════╝

→ Detecting System Architecture
────────────────────────────────────────────────────────────
• Operating System: Linux
• Architecture: x86_64
✓ Platform detected: linux_amd64
(All output in plain text, no colors)
```

### Both Flags Combined
```bash
$ sudo ./install.sh --no-unicode --no-color

+==============================================================+
|  * Arcane GitOps Installer                                   |
+==============================================================+

-> Detecting System Architecture
------------------------------------------------------------
* Operating System: Linux
* Architecture: x86_64
[OK] Platform detected: linux_amd64
(ASCII only, no colors - maximum compatibility)
```

---

## 🎓 Interactive Configuration Flow

### Full Flow with Gum

```
→ Configuring System Service
────────────────────────────────────────────────────────────

Configuration Setup
────────────────────────────────────────────────────────────
✓ Config directory created: /etc/arcane-gitops

• Install 'gum' for enhanced prompts? (y/N): y
  → Installing gum...
✓ Gum installed successfully
• Using enhanced prompts (gum detected)

┃ • Git repository path:
┃ > /opt/docker
┃ /var/docker
┃ /home/user/docker

┃ • Projects root path:
┃ /opt/docker

┃ • Arcane base URL:
┃ http://localhost:3552

┃ • Arcane API key:
┃ ••••••••••••••••

┃ • Arcane environment ID:
┃ 0

┃ • Configure SSH key for private repositories?
┃ ❯ Yes
┃   No

┃ Choose SSH key file:
┃ ❯ /root/.ssh/id_rsa
┃   /root/.ssh/id_ed25519
┃   /home/user/.ssh/id_rsa

✓ Configuration saved to /etc/arcane-gitops/config.env
```

### Flow Without Gum

```
-> Configuring System Service
------------------------------------------------------------

Configuration Setup
------------------------------------------------------------
[OK] Config directory created: /etc/arcane-gitops

* Install 'gum' for enhanced prompts? (y/N): n

* Git repository path [/opt/docker]: /opt/docker
* Projects root path [/opt/docker]: /opt/docker
* Arcane base URL [http://localhost:3552]: http://localhost:3552
* Arcane API key: (input hidden)
* Arcane environment ID [0]: 0
* SSH key path (optional, press Enter to skip): /root/.ssh/id_rsa

[OK] Configuration saved to /etc/arcane-gitops/config.env
```

---

## 🎯 Summary Section

### Unicode + Color (Default)
```
╔══════════════════════════════════════════════════════════════╗
║  ✓ Installation Complete!                                    ║
╚══════════════════════════════════════════════════════════════╝

Quick Start:
• Manual sync:      sudo systemctl start arcane-gitops.service
• View logs:        sudo journalctl -u arcane-gitops.service -f
• Check timer:      sudo systemctl status arcane-gitops.timer
• Configuration:    /etc/arcane-gitops/config.env

Next Steps:
• Ensure your Git repository is accessible
• Verify API key has proper permissions
• Check that compose.yaml files are in place

For more information, visit:
https://github.com/x86txt/goArcaneGitOps
```

### ASCII + No Color
```
+==============================================================+
|  [OK] Installation Complete!                                 |
+==============================================================+

Quick Start:
* Manual sync:      sudo systemctl start arcane-gitops.service
* View logs:        sudo journalctl -u arcane-gitops.service -f
* Check timer:      sudo systemctl status arcane-gitops.timer
* Configuration:    /etc/arcane-gitops/config.env

Next Steps:
* Ensure your Git repository is accessible
* Verify API key has proper permissions
* Check that compose.yaml files are in place

For more information, visit:
https://github.com/x86txt/goArcaneGitOps
```

---

## 🔧 Help Output

```bash
$ ./install.sh --help

Arcane GitOps Installer

Usage: ./install.sh [OPTIONS]

Options:
  --no-unicode    Use ASCII characters instead of Unicode
  --no-color      Disable colored output
  --help          Show this help message
```

---

## 📱 Accessibility Features

### Screen Reader Friendly
When using `--no-unicode --no-color`:
- All status messages use clear text: [OK], [X], etc.
- No special characters that might be misread
- Plain arrows (->) instead of Unicode arrows
- Standard asterisks (*) instead of bullets

### Legacy Terminal Support
The `--no-unicode` flag ensures compatibility with:
- Linux console (no framebuffer)
- Serial terminals
- Telnet/SSH sessions with limited character sets
- Older terminal emulators
- Embedded systems with basic displays

### High Contrast Mode
The `--no-color` flag helps users who:
- Have color blindness
- Use monochrome displays
- Need high contrast for visibility
- Rely on screen readers
- Work in terminals with poor color support

---

## 🎬 Real-World Scenarios

### Scenario 1: Modern Linux Desktop
```bash
# Full featured installation
sudo ./install.sh
# ✓ Unicode symbols
# ✓ Full colors
# ✓ Gum prompts (if available)
```

### Scenario 2: Headless Server via SSH
```bash
# Standard installation, might have limited character set
sudo ./install.sh
# ✓ Unicode symbols (usually works)
# ✓ Full colors
# ✓ Standard prompts
```

### Scenario 3: Minimal/Embedded System
```bash
# ASCII-only for maximum compatibility
sudo ./install.sh --no-unicode
# ✓ ASCII symbols
# ✓ Full colors
# ✓ Works on any terminal
```

### Scenario 4: Screen Reader User
```bash
# Accessible mode
sudo ./install.sh --no-unicode --no-color
# ✓ ASCII symbols only
# ✓ No colors
# ✓ Perfect for screen readers
```

### Scenario 5: Automated/CI Environment
```bash
# Non-interactive installation (future enhancement)
sudo ARCANE_API_KEY=xxx REPO_PATH=/opt/docker ./install.sh --no-color
# ✓ No colors in logs
# ✓ Clean output for parsing
```

---

## 💡 Tips for Users

1. **First time users**: Run standard `sudo ./install.sh` for the best experience
2. **Legacy systems**: Add `--no-unicode` if you see garbled characters
3. **Screen readers**: Use `--no-unicode --no-color` for best results
4. **Better UX**: Install gum first with `go install github.com/charmbracelet/gum@latest`
5. **Automation**: Use environment variables to pre-configure settings (future feature)

---

## 🎨 Color Palette Reference

The installer uses these colors for semantic meaning:

| Color | Usage | Meaning |
|-------|-------|---------|
| 🔴 Red | Errors | Critical failures |
| 🟢 Green | Success | Operations completed |
| 🟡 Yellow | Warnings | Non-critical issues |
| 🔵 Blue | Info | General information |
| 🟣 Magenta | Headers | Section titles |
| 🔷 Cyan | Prompts | User input required |
| ⚪ Dim | Details | Secondary information |

All colors can be disabled with `--no-color` for accessibility.
