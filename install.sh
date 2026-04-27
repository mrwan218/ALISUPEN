#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
#  Alisupen — Automated Installer for Noctalia Shell
#  https://github.com/mrwan218/ALISUPEN
#
#  Usage:
#    bash install.sh            # install
#    bash install.sh --uninstall  # remove
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

# ── Config ────────────────────────────────────────────────────
PLUGIN_ID="alisupen"
REPO_URL="https://github.com/mrwan218/ALISUPEN.git"
NOCTALIA_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/noctalia"
PLUGIN_DIR="${NOCTALIA_DIR}/plugins/${PLUGIN_ID}"
PLUGINS_JSON="${NOCTALIA_DIR}/plugins.json"

# ── Colors ────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

info()    { echo -e "${PURPLE}[alisupen]${RESET} ${CYAN}$1${RESET}"; }
success() { echo -e "${PURPLE}[alisupen]${RESET} ${GREEN}$1${RESET}"; }
warn()    { echo -e "${PURPLE}[alisupen]${RESET} ${YELLOW}$1${RESET}"; }
error()   { echo -e "${PURPLE}[alisupen]${RESET} ${RED}$1${RESET}"; }

# ═══════════════════════════════════════════════════════════════
#  Uninstall
# ═══════════════════════════════════════════════════════════════
uninstall() {
    info "Uninstalling Alisupen…"

    # Remove plugin directory
    if [ -d "$PLUGIN_DIR" ]; then
        rm -rf "$PLUGIN_DIR"
        success "Removed ${PLUGIN_DIR}"
    else
        warn "Plugin directory not found — already removed?"
    fi

    # Remove entry from plugins.json
    if [ -f "$PLUGINS_JSON" ]; then
        if command -v python3 &>/dev/null; then
            python3 -c "
import json, sys
path = '${PLUGINS_JSON}'
with open(path) as f:
    data = json.load(f)
before = len(data.get('plugins', []))
data['plugins'] = [p for p in data.get('plugins', []) if p.get('id') != '${PLUGIN_ID}']
after = len(data['plugins'])
with open(path, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
if before != after:
    print('Removed plugin entry from plugins.json')
else:
    print('No entry found in plugins.json')
"
        elif command -v jq &>/dev/null; then
            tmp=$(mktemp)
            jq "del(.plugins[] | select(.id == \"${PLUGIN_ID}\"))" "$PLUGINS_JSON" > "$tmp" && mv "$tmp" "$PLUGINS_JSON"
            success "Removed plugin entry from plugins.json"
        else
            warn "Cannot update plugins.json — install python3 or jq to clean up automatically"
        fi
    else
        warn "plugins.json not found — nothing to clean up"
    fi

    success "Alisupen uninstalled. Restart Noctalia Shell to apply."
    exit 0
}

# ── Parse args ────────────────────────────────────────────────
case "${1:-}" in
    --uninstall|-u) uninstall ;;
    --help|-h)
        echo "Usage: bash install.sh [--uninstall|--help]"
        exit 0
        ;;
esac

# ═══════════════════════════════════════════════════════════════
#  Install
# ═══════════════════════════════════════════════════════════════
echo ""
echo -e "${BOLD}${PURPLE}  ╔══════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${PURPLE}  ║        Alisupen Installer            ║${RESET}"
echo -e "${BOLD}${PURPLE}  ║   Noctalia Shell Update Manager      ║${RESET}"
echo -e "${BOLD}${PURPLE}  ╚══════════════════════════════════════╝${RESET}"
echo ""

# ── 1. Check dependencies ─────────────────────────────────────
info "Checking dependencies…"

_missing=0

if ! command -v git &>/dev/null; then
    error "git is not installed"
    _missing=1
fi

# Check for python3 OR jq (needed for JSON manipulation)
if ! command -v python3 &>/dev/null && ! command -v jq &>/dev/null; then
    error "python3 or jq is required for JSON manipulation"
    _missing=1
fi

# Optional: check for Noctalia Shell
if [ ! -d "$NOCTALIA_DIR" ]; then
    warn "Noctalia config directory not found at ${NOCTALIA_DIR}"
    warn "This may mean Noctalia Shell is not installed or uses a different config path"
    read -rp "$(echo -e "${YELLOW}Continue anyway? [y/N] ${RESET}")" _confirm
    if [[ ! "$_confirm" =~ ^[Yy]$ ]]; then
        error "Aborted."
        exit 1
    fi
fi

if [ "$_missing" -eq 1 ]; then
    error "Missing required dependencies. Please install them and retry."
    exit 1
fi

success "All dependencies satisfied"

# ── 2. Create directory structure ──────────────────────────────
info "Creating plugin directory…"

mkdir -p "${NOCTALIA_DIR}/plugins"
success "Directory ready: ${NOCTALIA_DIR}/plugins"

# ── 3. Clone or update the plugin ─────────────────────────────
if [ -d "$PLUGIN_DIR/.git" ]; then
    info "Plugin already cloned — pulling latest changes…"
    cd "$PLUGIN_DIR"
    git pull --ff-only origin main 2>/dev/null || {
        warn "Could not fast-forward pull. Trying reset…"
        git fetch origin main
        git reset --hard origin/main
    }
    success "Plugin updated to latest version"
elif [ -d "$PLUGIN_DIR" ]; then
    warn "Plugin directory exists but is not a git repo"
    warn "Backing up and re-cloning…"
    mv "$PLUGIN_DIR" "${PLUGIN_DIR}.bak.$(date +%s)"
    git clone "$REPO_URL" "$PLUGIN_DIR"
    success "Plugin cloned (backup saved)"
else
    info "Cloning Alisupen from ${REPO_URL}…"
    git clone "$REPO_URL" "$PLUGIN_DIR"
    success "Plugin cloned"
fi

# ── 4. Verify manifest ────────────────────────────────────────
info "Verifying plugin manifest…"

MANIFEST="${PLUGIN_DIR}/manifest.json"
if [ ! -f "$MANIFEST" ]; then
    error "manifest.json not found in ${PLUGIN_DIR}"
    error "The clone may have failed. Check the repository URL."
    exit 1
fi

# Validate manifest has required fields
_valid=1
for _field in id name version entries; do
    if ! python3 -c "import json; d=json.load(open('${MANIFEST}')); assert '${_field}' in d" 2>/dev/null; then
        if ! jq -e ".${_field}" "$MANIFEST" &>/dev/null; then
            error "manifest.json missing required field: ${_field}"
            _valid=0
        fi
    fi
done

if [ "$_valid" -eq 0 ]; then
    error "Manifest validation failed"
    exit 1
fi

success "Manifest validated"

# ── 5. Register in plugins.json ───────────────────────────────
info "Registering plugin in Noctalia…"

mkdir -p "$(dirname "$PLUGINS_JSON")"

if [ ! -f "$PLUGINS_JSON" ]; then
    # Create new plugins.json
    echo '{"plugins":[{"id":"alisupen","enabled":true}]}' > "$PLUGINS_JSON"
    success "Created plugins.json with Alisupen registered"
else
    # Check if already registered
    _already=0
    if command -v python3 &>/dev/null; then
        _already=$(python3 -c "
import json
with open('${PLUGINS_JSON}') as f:
    data = json.load(f)
for p in data.get('plugins', []):
    if p.get('id') == '${PLUGIN_ID}':
        print('1')
        break
else:
    print('0')
")
    elif command -v jq &>/dev/null; then
        _already=$(jq ".plugins[] | select(.id==\"${PLUGIN_ID}\") | .id" "$PLUGINS_JSON" 2>/dev/null | grep -c "alisupen" || true)
    fi

    if [ "$_already" -eq 1 ] || [ "$_already" = "1" ]; then
        info "Plugin already registered — ensuring it is enabled"
        if command -v python3 &>/dev/null; then
            python3 -c "
import json
path = '${PLUGINS_JSON}'
with open(path) as f:
    data = json.load(f)
for p in data.get('plugins', []):
    if p.get('id') == '${PLUGIN_ID}':
        p['enabled'] = True
with open(path, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
print('Plugin enabled in plugins.json')
"
        elif command -v jq &>/dev/null; then
            tmp=$(mktemp)
            jq "(.plugins[] | select(.id==\"${PLUGIN_ID}\")).enabled = true" "$PLUGINS_JSON" > "$tmp" && mv "$tmp" "$PLUGINS_JSON"
        fi
        success "Plugin enabled in plugins.json"
    else
        # Append entry
        if command -v python3 &>/dev/null; then
            python3 -c "
import json
path = '${PLUGINS_JSON}'
with open(path) as f:
    data = json.load(f)
data.setdefault('plugins', []).append({'id': '${PLUGIN_ID}', 'enabled': True})
with open(path, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
print('Plugin registered in plugins.json')
"
        elif command -v jq &>/dev/null; then
            tmp=$(mktemp)
            jq ".plugins += [{\"id\": \"${PLUGIN_ID}\", \"enabled\": true}]" "$PLUGINS_JSON" > "$tmp" && mv "$tmp" "$PLUGINS_JSON"
        fi
        success "Plugin registered in plugins.json"
    fi
fi

# ── 6. Check for optional tools ───────────────────────────────
info "Checking optional tools…"

_tools=0

if command -v pacman &>/dev/null; then
    success "pacman found"
else
    warn "pacman not found (required for Pacman updates)"
    _tools=1
fi

if command -v paru &>/dev/null; then
    success "paru found (AUR helper)"
elif command -v yay &>/dev/null; then
    success "yay found (AUR helper)"
else
    warn "No AUR helper found — install paru or yay for AUR support"
    _tools=1
fi

if command -v flatpak &>/dev/null; then
    success "flatpak found"
else
    warn "flatpak not found — install for Flatpak support"
    _tools=1
fi

if command -v pkexec &>/dev/null; then
    success "pkexec found (privilege escalation)"
else
    warn "pkexec not found — required for system-level updates"
    _tools=1
fi

if command -v notify-send &>/dev/null; then
    success "notify-send found (desktop notifications)"
else
    warn "notify-send not found — install libnotify for desktop notifications"
    _tools=1
fi

# ═══════════════════════════════════════════════════════════════
#  Done
# ═══════════════════════════════════════════════════════════════
echo ""
echo -e "${BOLD}${GREEN}  ✔ Alisupen installed successfully!${RESET}"
echo ""
echo -e "  ${DIM}Plugin directory:${RESET}  ${PLUGIN_DIR}"
echo -e "  ${DIM}Registered in:${RESET}     ${PLUGINS_JSON}"
echo ""
echo -e "  ${CYAN}To activate:${RESET}"
echo -e "    1. Restart Noctalia Shell, OR"
echo -e "    2. Enable Debug Mode (8 clicks on Noctalia logo in About tab)"
echo -e "       for hot-reload without restart"
echo ""
echo -e "  ${CYAN}To uninstall:${RESET}"
echo -e "    bash ${PLUGIN_DIR}/install.sh --uninstall"
echo ""
