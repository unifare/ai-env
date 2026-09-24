#!/usr/bin/env bash
# ==============================================================================
# ai-env - Installer
# Usage: ./install.sh   OR   curl -fsSL <url>/install.sh | bash
# ==============================================================================

set -euo pipefail

AI_ENV_VERSION="1.0.0"
AI_ENV_DIR="${HOME}/.config/ai-env"
AI_ENV_LOCAL_BIN="${HOME}/.local/bin"
AI_ENV_SYSTEM_BIN="/usr/local/bin"

# Where to fetch source files from when running the one-click (curl|bash) path.
# Fall back to the raw GitHub URL so a bare pipe install always works.
AI_ENV_RAW_BASE="${AI_ENV_RAW_BASE:-https://raw.githubusercontent.com/unifare/ai-env/main}"

# ---- Color output ----
_RED='\033[0;31m'
_GREEN='\033[0;32m'
_YELLOW='\033[0;33m'
_CYAN='\033[0;36m'
_BOLD='\033[1m'
_RESET='\033[0m'

_step()  { printf "\n${_BOLD}▸${_RESET} %s\n" "$1"; }
_ok()    { printf "  ${_GREEN}✓${_RESET} %s\n" "$1"; }
_err()   { printf "  ${_RED}✗${_RESET} %s\n" "$1" >&2; }
_warn()  { printf "  ${_YELLOW}⚠${_RESET} %s\n" "$1"; }
_info()  { printf "  ${_CYAN}ℹ${_RESET} %s\n" "$1"; }

# ---- Determine script directory ----
# If running from curl, the script source files are in the same directory as
# this installer. If running as ./install.sh, resolve the directory.
_RESOLVE_SCRIPT_DIR() {
    local src="${BASH_SOURCE[0]}"
    # If sourced via pipe (curl | bash), BASH_SOURCE may be empty or /dev/stdin
    if [ -z "$src" ] || [ "$src" = "/dev/stdin" ] || [ "$src" = "/dev/fd/63" ]; then
        # Running from pipe — look for files in current directory
        echo "$(pwd)"
    else
        # Running as a file
        local dir
        dir=$(cd "$(dirname "$src")" && pwd)
        echo "$dir"
    fi
}

SCRIPT_DIR=$(_RESOLVE_SCRIPT_DIR)

# ---- Determine installation target ----
_DETERMINE_BIN_DIR() {
    # Prefer ~/.local/bin if it exists or can be created
    # Fall back to /usr/local/bin if user has write access
    if [ -w "$AI_ENV_SYSTEM_BIN" ] 2>/dev/null; then
        echo "$AI_ENV_SYSTEM_BIN"
    else
        echo "$AI_ENV_LOCAL_BIN"
    fi
}

BIN_DIR=$(_DETERMINE_BIN_DIR)

# ---- Check prerequisites ----
_CHECK_PREREQS() {
    _step "Checking prerequisites"

    # Check bash
    if [ -z "${BASH_VERSION:-}" ]; then
        _warn "Not running in Bash. Some features may not work."
    else
        _ok "Bash ${BASH_VERSION%%-*}"
    fi

    # Check core tools
    for tool in sed grep mktemp chmod cat curl; do
        if command -v "$tool" &>/dev/null; then
            _ok "$tool available"
        else
            _err "$tool not found (required)"
            exit 1
        fi
    done
}

# ---- Fetch missing source files ----
# The one-click path (curl | bash) streams install.sh over stdin, so no sibling
# files (ai-env, init.sh, config) exist on disk. Whenever a required source file
# is missing, download it from the repo so the install can proceed. This also
# covers running install.sh locally from a directory that lacks the sources.
_FETCH_SOURCE_FILE() {
    local name="$1"
    local target="${SCRIPT_DIR}/${name}"

    [ -f "$target" ] && return 0  # already present locally

    _info "Downloading ${name} from ${AI_ENV_RAW_BASE}/${name}"
    if ! curl -fsSL "${AI_ENV_RAW_BASE}/${name}" -o "$target"; then
        _err "Failed to download ${name}"
        _info "Check AI_ENV_RAW_BASE or run install.sh from a directory containing ${name}"
        exit 1
    fi
}

# ---- Create directories ----
_CREATE_DIRS() {
    _step "Creating directories"

    mkdir -p "$AI_ENV_DIR"
    _ok "Config directory: ${AI_ENV_DIR}"

    if [ "$BIN_DIR" = "$AI_ENV_LOCAL_BIN" ]; then
        mkdir -p "$AI_ENV_LOCAL_BIN"
        _ok "Local bin: ${AI_ENV_LOCAL_BIN}"
    else
        _ok "System bin: ${BIN_DIR}"
    fi
}

# ---- Install the ai-env binary ----
_INSTALL_BINARY() {
    _step "Installing ai-env binary"

    local target="${BIN_DIR}/ai-env"
    local source_file="${SCRIPT_DIR}/ai-env"

    # Fetch the binary if it's not next to the installer (one-click path)
    _FETCH_SOURCE_FILE "ai-env"

    cp "$source_file" "$target"
    chmod 755 "$target"
    _ok "Installed: ${target}"
}

# ---- Install init.sh ----
_INSTALL_INIT() {
    _step "Installing init.sh"

    local target="${AI_ENV_DIR}/init.sh"
    local source_file="${SCRIPT_DIR}/init.sh"

    # Fetch init.sh if it's not next to the installer (one-click path)
    _FETCH_SOURCE_FILE "init.sh"

    cp "$source_file" "$target"
    chmod 644 "$target"
    _ok "Installed: ${target}"
}

# ---- Install config ----
_INSTALL_CONFIG() {
    _step "Installing config"

    local target="${AI_ENV_DIR}/config"
    local source_file="${SCRIPT_DIR}/config"

    # Fetch config if it's not next to the installer (one-click path)
    _FETCH_SOURCE_FILE "config"

    if [ -f "$source_file" ]; then
        cp "$source_file" "$target"
        _ok "Installed: ${target}"
    else
        # Create default config if source doesn't exist
        cat > "$target" <<CONF
# ai-env configuration
AI_ENV_VERSION=${AI_ENV_VERSION}
CONF
        _ok "Created default config: ${target}"
    fi
}

# ---- Create keys file (if not exists) ----
_ENSURE_KEYS_FILE() {
    _step "Setting up keys file"

    if [ ! -f "${AI_ENV_DIR}/keys" ]; then
        touch "${AI_ENV_DIR}/keys"
        chmod 600 "${AI_ENV_DIR}/keys"
        _ok "Created keys file: ${AI_ENV_DIR}/keys"
    else
        _ok "Keys file exists: ${AI_ENV_DIR}/keys"
    fi
}

# ---- Add to PATH ----
_ADD_TO_PATH() {
    if [ "$BIN_DIR" != "$AI_ENV_LOCAL_BIN" ]; then
        return 0  # System bin, already in PATH
    fi

    _step "Adding ~/.local/bin to PATH"

    # Check if already in PATH
    case ":${PATH}:" in
        *":${AI_ENV_LOCAL_BIN}:"*|"${AI_ENV_LOCAL_BIN}:"*|*":${AI_ENV_LOCAL_BIN}")
            _ok "~/.local/bin already in PATH"
            return 0
            ;;
    esac

    # Add to PATH in shell rc files
    local path_line='export PATH="${HOME}/.local/bin:${PATH}"'

    for rc_file in "${HOME}/.bashrc" "${HOME}/.zshrc"; do
        if [ -f "$rc_file" ]; then
            if grep -qF '.local/bin' "$rc_file" 2>/dev/null; then
                _ok "$(basename "$rc_file") already has ~/.local/bin"
            else
                echo "" >> "$rc_file"
                echo "# Added by ai-env installer" >> "$rc_file"
                echo "$path_line" >> "$rc_file"
                _ok "Added ~/.local/bin to $(basename "$rc_file")"
            fi
        fi
    done

    # Also add for current session
    export PATH="${AI_ENV_LOCAL_BIN}:${PATH}"
    _ok "Added to current session PATH"
}

# ---- Add source line to shell rc files ----
_ADD_SHELL_INTEGRATION() {
    _step "Setting up shell integration"

    local source_line='[ -f "${HOME}/.config/ai-env/init.sh" ] && source "${HOME}/.config/ai-env/init.sh"'

    local rc_found=0

    for rc_file in "${HOME}/.bashrc" "${HOME}/.zshrc" "${HOME}/.bash_profile" "${HOME}/.profile"; do
        # Only add to rc files that exist (or .bashrc which is standard)
        if [ "$rc_file" = "${HOME}/.bashrc" ] || [ "$rc_file" = "${HOME}/.zshrc" ]; then
            # Create .bashrc / .zshrc if they don't exist
            if [ ! -f "$rc_file" ]; then
                # Only create if the corresponding shell is detected
                if [ "$rc_file" = "${HOME}/.bashrc" ] && [ -n "${BASH_VERSION:-}" ]; then
                    touch "$rc_file"
                elif [ "$rc_file" = "${HOME}/.zshrc" ] && [ -n "${ZSH_VERSION:-}" ]; then
                    touch "$rc_file"
                else
                    continue
                fi
            fi
        fi

        if [ -f "$rc_file" ]; then
            if grep -qF 'ai-env/init.sh' "$rc_file" 2>/dev/null; then
                _ok "$(basename "$rc_file") already configured"
                rc_found=1
            else
                echo "" >> "$rc_file"
                echo "# ai-env: manage AI API keys" >> "$rc_file"
                echo "$source_line" >> "$rc_file"
                _ok "Added source line to $(basename "$rc_file")"
                rc_found=1
            fi
        fi
    done

    if [ $rc_found -eq 0 ]; then
        _warn "No shell rc file found. Add this line manually:"
        _info "$source_line"
    fi
}

# ---- Source init.sh for current session ----
_SOURCE_FOR_CURRENT_SESSION() {
    _step "Loading for current session"

    if [ -f "${AI_ENV_DIR}/init.sh" ]; then
        # shellcheck source=/dev/null
        source "${AI_ENV_DIR}/init.sh"
        _ok "Loaded ai-env in current shell"
    else
        _warn "init.sh not found, run: source ${AI_ENV_DIR}/init.sh"
    fi
}

# ---- Print success message ----
_PRINT_SUCCESS() {
    printf "\n"
    printf "${_GREEN}${_BOLD}  ╔══════════════════════════════════════╗${_RESET}\n"
    printf "${_GREEN}${_BOLD}  ║   ai-env installed successfully! 🎉   ║${_RESET}\n"
    printf "${_GREEN}${_BOLD}  ╚══════════════════════════════════════╝${_RESET}\n"
    printf "\n"
    printf "  ${_BOLD}Quick start:${_RESET}\n"
    printf "\n"
    printf "    ai-env set OPENAI_API_KEY sk-your-key\n"
    printf "    ai-env list\n"
    printf "    ai-env doctor\n"
    printf "\n"
    printf "  ${_BOLD}New terminal:${_RESET} automatically loaded\n"
    printf "  ${_BOLD}Current terminal:${_RESET} already loaded ✅\n"
    printf "\n"
}

# ---- Main ----

main() {
    printf "${_BOLD}ai-env v${AI_ENV_VERSION} installer${_RESET}\n"
    printf "══════════════════════════════════════\n"

    _CHECK_PREREQS
    _CREATE_DIRS
    _INSTALL_BINARY
    _INSTALL_INIT
    _INSTALL_CONFIG
    _ENSURE_KEYS_FILE
    _ADD_TO_PATH
    _ADD_SHELL_INTEGRATION
    _SOURCE_FOR_CURRENT_SESSION
    _PRINT_SUCCESS
}

main "$@"