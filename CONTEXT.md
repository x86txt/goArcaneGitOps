# Project Context & Development Log

This file maintains a running log of development activities, architectural decisions, and important context for this project.

---

## 2026-01-02 - Installer Enhancements & SHA256 Verification

### Summary
Enhanced the install.sh script with improved UX, accessibility, and security features.

### Changes Made

#### 1. Enhanced Interactive Prompts (v0.0.9)
- Added optional [gum](https://github.com/charmbracelet/gum) integration for beautiful prompts
- Password masking for API key input
- File picker for SSH key selection
- Automatic fallback to standard bash prompts if gum not available
- Optional gum installation during setup (requires Go)

#### 2. Accessibility Features (v0.0.9)
- `--no-unicode` flag: ASCII-only mode for legacy terminals
- `--no-color` flag: Disable colors for screen readers
- `--help` flag: Show usage information
- Works on any terminal with full feature parity

#### 3. One-Line Remote Install (v0.0.9)
- Added to README.md: `curl -fsSL ... | sudo bash`
- No need to clone repository first
- Downloads latest release automatically

#### 4. SHA256 Checksum Verification (v0.0.10)
- Fixed installer to download correct archive format (tar.gz/zip)
- Automatically downloads and verifies SHA256 checksums
- Prevents installation of corrupted or tampered binaries
- Supports both Linux (sha256sum) and macOS (shasum)
- Fails installation with clear error if verification fails

### Installation Flow

```
1. Detect system (OS + architecture)
2. Fetch latest release from GitHub API
3. Download archive: arcane-gitops-VERSION-OS-ARCH.{tar.gz,zip}
4. Download checksum: arcane-gitops-VERSION-OS-ARCH.{tar.gz,zip}.sha256
5. Verify SHA256 checksum
6. Extract binary from archive
7. Install to /usr/local/bin
8. Configure systemd service
```

### Commits
- `ef9b036` - feat: enhance installer with gum support, accessibility, and remote install
- `6bb5cb2` - fix: correct installer to download archives with SHA256 verification

### Tags
- `v0.0.9` - Initial enhanced installer (had broken download URLs)
- `v0.0.10` - Fixed installer with working downloads and SHA256 verification

### Files Modified
- `install.sh` - Complete rewrite of download/verification logic
- `README.md` - Added one-line install command and new flags

### Technical Decisions

**Why gum is optional:**
- Not available by default on most systems
- Adds value but shouldn't be required
- Progressive enhancement approach

**Why SHA256 verification is critical:**
- Prevents MITM attacks
- Detects corrupted downloads
- Industry standard for package managers
- Matches GitHub release workflow output

**Archive format choice:**
- tar.gz for Linux/macOS (native support)
- zip for Windows (native support)
- Matches release workflow (.github/workflows/release.yml)

---

## Project Architecture Notes

### Binary Name
- Changed from `sync-tool` to `arcane-gitops` in commit `4c3cec8`
- All references updated (systemd files, config, docs)

### Release Process
1. Tag with `vX.Y.Z` format
2. GitHub Actions builds multi-platform binaries
3. Creates release with archives + SHA256 checksums
4. Installer downloads and verifies from releases

### Key Files
- `main.go` - Single-file application (~916 lines)
- `install.sh` - Interactive installer with verification
- `config.env.example` - Configuration template
- `arcane-gitops.service` - Systemd service unit
- `arcane-gitops.timer` - Systemd timer (periodic sync)
- `.github/workflows/ci.yml` - Lint, test, security scans
- `.github/workflows/release.yml` - Multi-platform builds

---

## Future Considerations

- Consider adding `--quiet` mode for scripted installations
- Support for non-interactive config via environment variables
- Pre-flight dependency checks
- Rollback mechanism for failed upgrades

---

*Last Updated: 2026-01-02*
