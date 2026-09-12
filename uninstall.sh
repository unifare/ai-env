#!/usr/bin/env bash
# ==============================================================================
# ai-env - Uninstaller
# Usage: ./uninstall.sh
# ==============================================================================

set -euo pipefail

AI_ENV_VERSION="1.0.0"
AI_ENV_DIR="${HOME}/.config/ai-env"
AI_ENV_KEYS="${AI_ENV_DIR}/keys"
AI_ENV_BACKUP="${HOME}/.ai-env-keys.backup"
AI_ENV_LOCAL_BIN="${HOME}/.local/bin"
AI_ENV_SYSTEM_BIN="/usr/local/bin"

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

uninstall_ai_env() {
    printf "${_BOLD}ai-env v${AI_ENV_VERSION} Uninstaller${_RESET}\n"
    printf "══════════════════════════════════════\n"

    # Step 1: Backup keys
    _step "Backing up keys"
    if [ -f "$AI_ENV_KEYS" ]; then
        cp "$AI_ENV_KEYS" "$AI_ENV_BACKUP"
        _ok "Keys backed up to: ${AI_ENV_BACKUP}"
    else
        _warn "No keys file found to backup"
    fi

    # Step 2: Remove ai-env binary
    _step "Removing ai-env binary"
    for bin_dir in "$AI_ENV_LOCAL_BIN" "$AI_ENV_SYSTEM_BIN"; do
        if [ -f "${bin_dir}/ai-env" ]; then
            rm -f "${bin_dir}/ai-env"
            _ok "Removed: ${bin_dir}/ai-env"
        fi
    done

    # Step 3: Remove config directory
    _step "Removing config directory"
    if [ -d "$AI_ENV_DIR" ]; then
        rm -rf "$AI_ENV_DIR"
        _ok "Removed: ${AI_ENV_DIR}"
    else
        _warn "Config directory not found (already uninstalled?)"
    fi

    # Step 4: Remove from PATH and shell integration in rc files
    _step "Cleaning up shell profile"

    local rc_found=0
    for rc_file in "${HOME}/.bashrc" "${HOME}/.zshrc" "${HOME}/.bash_profile" "${HOME}/.profile"; do
        if [ -f "$rc_file" ]; then
            # Remove ai-env source lines and PATH additions
            local tmp_file
            tmp_file=$(mktemp)
            if grep -v -e 'ai-env/init\.sh' -e 'AI_ENV_DIR' -e '# Added by ai-env' "$rc_file" > "$tmp_file" 2>/dev/null; then
                if ! cmp -s "$rc_file" "$tmp_file"; then
                    mv "$tmp_file" "$rc_file"
                    _ok "Cleaned up: ${rc_file}"
                    rc_found=1
                else
                    rm -f "$tmp_file"
                fi
            else
                rm -f "$tmp_file"
            fi
        fi
    done

    if [ $rc_found -eq 0 ]; then
        _info "No shell profile entries found to remove"
    fi

    # Step 5: Unset env vars in current session
    unset AI_ENV_DIR AI_ENV_KEYS AI_ENV_INIT AI_ENV_CONFIG _AI_ENV_LOADED _AI_ENV_FUNC _AI_ENV_DIR _AI_ENV_KEYS _AI_ENV_SCRIPT 2>/dev/null || true

    printf "\n${_GREEN}${_BOLD}  ╔══════════════════════════════════════╗${_RESET}\n"
    printf "${_GREEN}${_BOLD}  ║   ai-env uninstalled successfully!   ║${_RESET}\n"
    printf "${_GREEN}${_BOLD}  ╚══════════════════════════════════════╝${_RESET}\n\n"
    printf "  Keys backup: ${AI_ENV_BACKUP}\n"
    printf "  To reinstall: run install.sh again\n\n"
}

uninstall_ai_env
