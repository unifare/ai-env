#!/usr/bin/env bash
# ==============================================================================
# ai-env - Shell Initialization
# Source this file from your .bashrc / .zshrc
# This file is auto-managed by ai-env install/uninstall.
# ==============================================================================

# Guard: don't load twice
if [ -n "${_AI_ENV_LOADED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi

_AI_ENV_DIR="${HOME}/.config/ai-env"
_AI_ENV_KEYS="${_AI_ENV_DIR}/keys"

# ---- Source existing keys into the current shell ----
if [ -f "$_AI_ENV_KEYS" ]; then
    source "$_AI_ENV_KEYS"
fi

# ---- Mark that the function wrapper is active ----
export _AI_ENV_FUNC=1

# ---- Wrapper function ----
# When ai-env is called through this function, environment changes
# (set/remove/reload) take effect immediately in the current shell.
# The ai-env script outputs lines prefixed with __EVAL__: for eval-able
# commands, and regular lines for display output.
ai-env() {
    local _ae_output _ae_ret _ae_eval _ae_display _ae_line

    # Call the real ai-env binary
    _ae_output=$(command ai-env "$@")
    _ae_ret=$?

    # Separate eval-able lines (prefixed with __EVAL__:) from display lines
    _ae_eval=""
    _ae_display=""

    while IFS= read -r _ae_line; do
        if [[ "$_ae_line" == __EVAL__:* ]]; then
            _ae_eval="${_ae_eval}${_ae_line#__EVAL__:}"$'\n'
        else
            _ae_display="${_ae_display}${_ae_line}"$'\n'
        fi
    done <<< "$_ae_output"

    # Print display output (trim trailing newline)
    if [ -n "$_ae_display" ]; then
        printf '%s' "$_ae_display"
    fi

    # Evaluate shell commands in the current shell
    if [ -n "$_ae_eval" ]; then
        eval "$_ae_eval"
    fi

    return $_ae_ret
}

# Export the function for Bash subshells (not available in Zsh)
if [ -n "${BASH_VERSION:-}" ]; then
    export -f ai-env 2>/dev/null || true
fi

# Mark as loaded
export _AI_ENV_LOADED=1
