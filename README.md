# Alisupen

**Integrated Update Manager** for [Noctalia Shell](https://github.com/noctalia-dev) v4.6+

Alisupen consolidates package updates from **Pacman**, **AUR**, and **Flatpak** into a single interface with fine-grained control — right from your Noctalia top bar.

## Features

- **Per-category counters** — Pacman, AUR, Flatpak at a glance
- **One-click actions** — Refresh, Update All, Remove Pacman Lock
- **Update queue** — Browse, filter, and update individual packages
- **Auto-refresh** — Configurable interval (5–120 min) for background checks
- **Visibility toggles** — Show/hide Pacman, AUR, or Flatpak sources
- **AUR helper selection** — Auto-detect, paru, or yay
- **Advanced AUR options** — Skip PKGBUILD review, remove build deps
- **Excluded packages** — Prevent specific packages from appearing
- **Desktop notifications** — Alert on newly available updates
- **Progress tracking** — Visual progress bar during system updates
- **IPC support** — CLI interaction via `alisupen` command prefix
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

### Post-Install Steps

After installing, you need to **add the widget to your bar**:

1. Open **Noctalia Settings → Plugins** → enable **Alisupen**
2. Open **Noctalia Settings → Bar** → add the Alisupen widget to Left/Center/Right section
3. The widget will appear on your top bar

### Manual (local testing)

```bash
# Clone into the Noctalia plugins directory
git clone https://github.com/mrwan218/ALISUPEN.git \
  ~/.config/noctalia/plugins/alisupen
```

Register in `~/.config/noctalia/plugins.json`:

```json
{
  "alisupen": {
    "enabled": true,
    "sourceUrl": "https://github.com/mrwan218/ALISUPEN"
  }
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

### Debugging

Run Noctalia with debug output to see QML errors:
```bash
NOCTALIA_DEBUG=1 qs -c noctalia-shell
```

### Official Submission

Fork [noctalia-dev/noctalia-plugins](https://github.com/noctalia-dev/noctalia-plugins) and submit a PR with the validated `manifest.json`.

## Plugin Structure

```
alisupen/
├── manifest.json      # Plugin identity, entry points, default settings
├── BarWidget.qml      # Top-bar badge (Item + visualCapsule pattern)
├── Main.qml           # Background service (Process, IpcHandler, timers)
├── Panel.qml          # Dropdown panel (opened via pluginApi.openPanel)
├── Settings.qml       # Configuration panel (pluginApi.pluginSettings)
├── install.sh         # Automated installer/uninstaller
├── .gitignore
└── README.md
```

## Architecture

The plugin follows Noctalia's official plugin architecture built on **Quickshell**:

| Component | Root Type | Role |
|-----------|-----------|------|
| `BarWidget.qml` | `Item` | Top-bar capsule badge; calls `pluginApi.togglePanel()` |
| `Main.qml` | `Item` | Background service with `Process` (Quickshell.Io), `IpcHandler`, timers |
| `Panel.qml` | `Item` | Dropdown panel positioned by Noctalia's Panel system |
| `Settings.qml` | `Item` | Settings UI using `pluginApi.pluginSettings` + `saveSettings()` |

**Key imports used:**
- `Quickshell` — ShellScreen, execDetached()
- `Quickshell.Io` — Process, StdioCollector, IpcHandler
- `qs.Commons` — Style, Color, Settings
- `qs.Widgets` — NButton, NIcon, NText, NTextInput, NIconButton
- `qs.Services.UI` — ToastService, BarService, TooltipService

**Communication flow:**
- `BarWidget` → `pluginApi.mainInstance` → reads properties from `Main.qml`
- `BarWidget` → `pluginApi.togglePanel()` → opens `Panel.qml`
- `Main.qml` → `IpcHandler` → exposes CLI commands
- `Settings.qml` → `pluginApi.pluginSettings` + `saveSettings()` → persistence

## Requirements

- Noctalia Shell ≥ 4.6.6
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
