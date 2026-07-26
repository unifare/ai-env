#!/usr/bin/env bash
# ==============================================================================
# ai-env - Installer
# Usage:
#   ./install.sh
#   curl -fsSL https://raw.githubusercontent.com/unifare/ai-env/main/install.sh | bash
# ==============================================================================

set -euo pipefail

AI_ENV_VERSION="1.0.0"
AI_ENV_DIR="${HOME}/.config/ai-env"
AI_ENV_LOCAL_BIN="${HOME}/.local/bin"
AI_ENV_SYSTEM_BIN="/usr/local/bin"
AI_ENV_REPO_RAW="https://raw.githubusercontent.com/unifare/ai-env/main"

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

# ---- Detect installation mode ----
_IS_PIPE_INSTALL=0
_SCRIPT_DIR=""

_DETECT_MODE() {
    local src="${BASH_SOURCE[0]:-}"
    # If running from pipe (curl | bash), BASH_SOURCE is empty or /dev/stdin
    if [ -z "$src" ] || [ "$src" = "/dev/stdin" ] || [ "$src" = "/dev/fd/63" ] || [ ! -f "$src" ]; then
        _IS_PIPE_INSTALL=1
        _info "Detected pipe install mode (curl | bash)"
    else
        _SCRIPT_DIR="$(cd "$(dirname "$src")" && pwd)"
        # Verify source files exist in script directory
        if [ -f "${_SCRIPT_DIR}/ai-env" ] && [ -f "${_SCRIPT_DIR}/init.sh" ]; then
            _ok "Local source files found"
        else
            _warn "Source files not found locally, falling back to download"
            _IS_PIPE_INSTALL=1
        fi
    fi
}

# ---- Download a file from GitHub ----
_DOWNLOAD_FILE() {
    local filename="$1"
    local target="$2"
    local url="${AI_ENV_REPO_RAW}/${filename}"

    _info "Downloading ${filename}..."

    # Try curl first, then wget
    if command -v curl &>/dev/null; then
        curl -fsSL "$url" -o "$target" 2>/dev/null && return 0
    elif command -v wget &>/dev/null; then
        wget -q "$url" -O "$target" 2>/dev/null && return 0
    fi

    _err "Failed to download ${filename}"
    return 1
}

# ---- Determine installation target ----
_DETERMINE_BIN_DIR() {
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

    if [ -z "${BASH_VERSION:-}" ]; then
        _warn "Not running in Bash. Some features may not work."
    else
        _ok "Bash ${BASH_VERSION%%-*}"
    fi

    for tool in sed grep mktemp chmod cat; do
        if command -v "$tool" &>/dev/null; then
            _ok "$tool available"
        else
            _err "$tool not found (required)"
            exit 1
        fi
    done

    # For pipe install, we need curl or wget
    if [ "$_IS_PIPE_INSTALL" -eq 1 ]; then
        if command -v curl &>/dev/null; then
            _ok "curl available (for downloading)"
        elif command -v wget &>/dev/null; then
            _ok "wget available (for downloading)"
        else
            _err "curl or wget required for remote install"
            exit 1
        fi
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

    if [ "$_IS_PIPE_INSTALL" -eq 0 ] && [ -f "${_SCRIPT_DIR}/ai-env" ]; then
        cp "${_SCRIPT_DIR}/ai-env" "$target"
    else
        _DOWNLOAD_FILE "ai-env" "$target"
    fi

    chmod 755 "$target"
    _ok "Installed: ${target}"
}

# ---- Install init.sh ----
_INSTALL_INIT() {
    _step "Installing init.sh"

    local target="${AI_ENV_DIR}/init.sh"

    if [ "$_IS_PIPE_INSTALL" -eq 0 ] && [ -f "${_SCRIPT_DIR}/init.sh" ]; then
        cp "${_SCRIPT_DIR}/init.sh" "$target"
    else
        _DOWNLOAD_FILE "init.sh" "$target"
    fi

    chmod 644 "$target"
    _ok "Installed: ${target}"
}

# ---- Install config ----
_INSTALL_CONFIG() {
    _step "Installing config"

    local target="${AI_ENV_DIR}/config"

    if [ "$_IS_PIPE_INSTALL" -eq 0 ] && [ -f "${_SCRIPT_DIR}/config" ]; then
        cp "${_SCRIPT_DIR}/config" "$target"
    else
        # Create default config (small enough to inline)
        cat > "$target" <<CONF
# ai-env configuration
AI_ENV_VERSION=${AI_ENV_VERSION}

# Mask mode for list command: full | partial | none
AI_ENV_MASK_MODE=partial
CONF
    fi

    _ok "Installed: ${target}"
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
        return 0
    fi

    _step "Adding ~/.local/bin to PATH"

    case ":${PATH}:" in
        *":${AI_ENV_LOCAL_BIN}:"*|"${AI_ENV_LOCAL_BIN}:"*|*":${AI_ENV_LOCAL_BIN}")
            _ok "~/.local/bin already in PATH"
            return 0
            ;;
    esac

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

    export PATH="${AI_ENV_LOCAL_BIN}:${PATH}"
    _ok "Added to current session PATH"
}

# ---- Add source line to shell rc files ----
_ADD_SHELL_INTEGRATION() {
    _step "Setting up shell integration"

    local source_line='[ -f "${HOME}/.config/ai-env/init.sh" ] && source "${HOME}/.config/ai-env/init.sh"'

    local rc_found=0

    for rc_file in "${HOME}/.bashrc" "${HOME}/.zshrc" "${HOME}/.bash_profile" "${HOME}/.profile"; do
        if [ "$rc_file" = "${HOME}/.bashrc" ] || [ "$rc_file" = "${HOME}/.zshrc" ]; then
            if [ ! -f "$rc_file" ]; then
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

    _DETECT_MODE
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
