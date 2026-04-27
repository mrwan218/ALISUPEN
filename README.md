# Alisupen

**Integrated Update Manager** for [Noctalia Shell](https://github.com/noctalia-dev) v4.7+

Alisupen consolidates package updates from **Pacman**, **AUR**, and **Flatpak** into a single interface with fine-grained control — right from your Noctalia top bar.

## Features

- **Per-category counters** — Pacman (blue), AUR (purple), Flatpak (teal) at a glance
- **One-click actions** — Refresh, Update All, Remove Pacman Lock
- **Update queue** — Browse, filter, and update individual packages
- **Auto-refresh** — Configurable interval (5–120 min) for background checks
- **Visibility toggles** — Show/hide Pacman, AUR, or Flatpak sources
- **AUR helper selection** — Auto-detect, paru, or yay
- **Advanced AUR options** — Skip PKGBUILD review, remove build deps
- **Excluded packages** — Prevent specific packages from appearing
- **Desktop notifications** — Alert on newly available updates
- **Progress tracking** — Visual progress bar during system updates
- **Persistent settings** — All preferences saved via pluginApi

## Installation

### Automated (recommended)

```bash
# One-line install — clone and run the installer
bash <(curl -fsSL https://raw.githubusercontent.com/mrwan218/ALISUPEN/main/install.sh)
```

The installer will:
1. Check dependencies (git, python3/jq)
2. Clone the plugin into `~/.config/noctalia/plugins/alisupen/`
3. Validate `manifest.json`
4. Register the plugin in `~/.config/noctalia/plugins.json`
5. Check for optional tools (pacman, paru/yay, flatpak, pkexec, notify-send)

### Manual (local testing)

```bash
# Clone into the Noctalia plugins directory
git clone https://github.com/mrwan218/ALISUPEN.git \
  ~/.config/noctalia/plugins/alisupen
```

Register in `~/.config/noctalia/plugins.json`:

```json
{
  "plugins": [
    { "id": "alisupen", "enabled": true }
  ]
}
```

### Uninstall

```bash
bash ~/.config/noctalia/plugins/alisupen/install.sh --uninstall
```

### Hot Reload (Debug Mode)

1. Open Noctalia Settings → **About** tab
2. Click the Noctalia logo **8 times** to activate Debug Mode
3. The plugin will hot-reload from disk automatically

### Official Submission

Fork [noctalia-dev/noctalia-plugins](https://github.com/noctalia-dev/noctalia-plugins) and submit a PR with the validated `manifest.json`.

## Plugin Structure

```
alisupen/
├── manifest.json      # Plugin identity, version, entry points, permissions
├── BarWidget.qml      # Top-bar badge + dropdown panel UI
├── Main.qml           # Background service (periodic checks, Process API)
├── Settings.qml       # Configuration panel (AUR helper, toggles, exclusions)
├── install.sh         # Automated installer/uninstaller
├── .gitignore
└── README.md
```

## Requirements

- Noctalia Shell ≥ 4.7.0
- Arch Linux (or Arch-based distribution)
- `pacman` (required)
- `paru` or `yay` (optional, for AUR updates)
- `flatpak` (optional, for Flatpak updates)
- `pkexec` (for privileged pacman operations)
- `notify-send` (for desktop notifications)

## Configuration

All settings are accessible via **Noctalia Settings → Plugins → Alisupen** and are persisted across sessions.

| Setting | Default | Description |
|---------|---------|-------------|
| Auto-Refresh Interval | 30 min | How often to check for updates |
| Show Pacman | true | Include Pacman in update checks |
| Show AUR | true | Include AUR in update checks |
| Show Flatpak | true | Include Flatpak in update checks |
| AUR Helper | Auto-detect | Which AUR helper to use |
| Skip PKGBUILD | false | Skip PKGBUILD review during AUR updates |
| Remove Build Deps | true | Remove build dependencies after AUR installs |
| Excluded Packages | (none) | Packages to exclude from the update queue |

## License

MIT
