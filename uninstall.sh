#!/usr/bin/env bash
# ==============================================================================
# ai-env - Uninstaller
# Usage: ./uninstall.sh
# ==============================================================================

set -euo pipefail

AI_ENV_DIR="${HOME}/.config/ai-env"
AI_ENV_LOCAL_BIN="${HOME}/.local/bin/ai-env"
AI_ENV_SYSTEM_BIN="/usr/local/bin/ai-env"

# ---- Color output ----
_RED='\033[0;31m'
_GREEN='\033[0;32m'
_YELLOW='\033[0;33m'
_BOLD='\033[1m'
_RESET='\033[0m'

_step()  { printf "\n${_BOLD}▸${_RESET} %s\n" "$1"; }
_ok()    { printf "  ${_GREEN}✓${_RESET} %s\n" "$1"; }
_err()   { printf "  ${_RED}✗${_RESET} %s\n" "$1" >&2; }
_warn()  { printf "  ${_YELLOW}⚠${_RESET} %s\n" "$1"; }

# ---- Remove ai-env binary ----
_REMOVE_BINARY() {
    _step "Removing ai-env binary"

    if [ -f "$AI_ENV_LOCAL_BIN" ]; then
        rm -f "$AI_ENV_LOCAL_BIN"
        _ok "Removed: ${AI_ENV_LOCAL_BIN}"
    fi

    if [ -f "$AI_ENV_SYSTEM_BIN" ]; then
        rm -f "$AI_ENV_SYSTEM_BIN" 2>/dev/null && _ok "Removed: ${AI_ENV_SYSTEM_BIN}" || \
            _warn "Cannot remove ${AI_ENV_SYSTEM_BIN} (need sudo?)"
    fi
}

# ---- Remove shell integration from rc files ----
_REMOVE_SHELL_INTEGRATION() {
    _step "Removing shell integration"

    for rc_file in "${HOME}/.bashrc" "${HOME}/.zshrc" "${HOME}/.bash_profile" "${HOME}/.profile"; do
        if [ ! -f "$rc_file" ]; then
            continue
        fi

        # Check if ai-env integration exists
        if ! grep -q 'ai-env' "$rc_file" 2>/dev/null; then
            continue
        fi

        # Remove ai-env related lines
        local tmp_file
        tmp_file=$(mktemp)

        # Remove lines containing ai-env/init.sh source
        grep -v 'ai-env/init\.sh' "$rc_file" | \
        grep -v '# ai-env: manage AI API keys' | \
        grep -v '# Added by ai-env installer' > "$tmp_file"

        # Also remove the ~/.local/bin PATH line added by ai-env installer
        # Only remove if it matches exactly what we added
        grep -v '^export PATH="${HOME}/.local/bin:${PATH}"$' "$tmp_file" > "${tmp_file}.2" 2>/dev/null || true
        mv "${tmp_file}.2" "$tmp_file" 2>/dev/null || true

        mv "$tmp_file" "$rc_file"
        _ok "Cleaned: $(basename "$rc_file")"
    done
}

# ---- Remove config directory ----
_REMOVE_CONFIG() {
    _step "Removing configuration"

    if [ ! -d "$AI_ENV_DIR" ]; then
        _ok "Config directory already removed"
        return 0
    fi

    # Ask about preserving keys
    local preserve_keys="n"
    if [ -f "${AI_ENV_DIR}/keys" ] && [ -s "${AI_ENV_DIR}/keys" ]; then
        local key_count
        key_count=$(grep -c '^export' "${AI_ENV_DIR}/keys" 2>/dev/null || echo 0)
        if [ "$key_count" -gt 0 ]; then
            printf "  ${_YELLOW}?${_RESET} Found %d key(s) in keys file. Preserve keys file? [y/N] " "$key_count"
            read -r preserve_keys
        fi
    fi

    if [ "$preserve_keys" = "y" ] || [ "$preserve_keys" = "Y" ]; then
        # Backup keys file
        cp "${AI_ENV_DIR}/keys" "${HOME}/.ai-env-keys.backup"
        _ok "Keys backed up to ~/.ai-env-keys.backup"
    fi

    rm -rf "$AI_ENV_DIR"
    _ok "Removed: ${AI_ENV_DIR}"
}

# ---- Unset environment variables ----
_UNSET_ENV() {
    _step "Unsetting environment variables"

    if [ -f "${AI_ENV_DIR}/keys" ]; then
        while IFS= read -r line; do
            [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
            local key
            key=$(printf '%s' "$line" | sed 's/^export //' | sed 's/=.*//')
            if [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
                unset "$key" 2>/dev/null || true
            fi
        done < "${AI_ENV_DIR}/keys"
        _ok "Unset all ai-env variables"
    fi

    unset _AI_ENV_FUNC 2>/dev/null || true
    unset _AI_ENV_LOADED 2>/dev/null || true

    # Unset the wrapper function
    unset -f ai-env 2>/dev/null || true
    _ok "Unloaded shell function"
}

# ---- Print result ----
_PRINT_RESULT() {
    printf "\n"
    printf "${_GREEN}${_BOLD}  ai-env has been uninstalled.${_RESET}\n"
    printf "\n"
    printf "  Restart your terminal for changes to take full effect.\n"
    if [ -f "${HOME}/.ai-env-keys.backup" ]; then
        printf "\n  ${_YELLOW}Keys backup:${_RESET} ~/.ai-env-keys.backup\n"
    fi
    printf "\n"
}

# ---- Main ----

main() {
    printf "${_BOLD}ai-env uninstaller${_RESET}\n"
    printf "══════════════════════════════════════\n"

    _REMOVE_BINARY
    _REMOVE_SHELL_INTEGRATION
    _UNSET_ENV
    _REMOVE_CONFIG
    _PRINT_RESULT
}

main "$@"
