#!/usr/bin/env bash
# ==============================================================================
# manage.sh - ai-env Management Tool (Interactive Menu + CLI)
# Usage: ./manage.sh [command] [args...]
# ==============================================================================

set -euo pipefail

AI_ENV_VERSION="1.0.0"
AI_ENV_DIR="${HOME}/.config/ai-env"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---- Color output ----
_RED='\033[0;31m'
_GREEN='\033[0;32m'
_YELLOW='\033[0;33m'
_CYAN='\033[0;36m'
_BOLD='\033[1m'
_RESET='\033[0m'

# ---- Interactive menu ----

print_menu() {
    clear
    printf "${_CYAN}========================================${_RESET}\n"
    printf "${_BOLD}     ai-env Management Tool${_RESET}\n"
    printf "${_CYAN}========================================${_RESET}\n"
    printf " 1. Install ai-env\n"
    printf " 2. Set API Key (set)\n"
    printf " 3. Get API Key (get)\n"
    printf " 4. List API Keys (list)\n"
    printf " 5. Remove API Key (remove)\n"
    printf " 6. Reload Keys (reload)\n"
    printf " 7. Export Keys (export)\n"
    printf " 8. Run Diagnostics (doctor)\n"
    printf " 9. Show Version (version)\n"
    printf "10. Uninstall ai-env\n"
    printf " 0. Exit\n"
    printf "${_CYAN}========================================${_RESET}\n"
    printf "Please enter your choice [0-10]: "
}

# If arguments are provided, run in CLI mode
if [ $# -gt 0 ]; then
    case "$1" in
        install)
            bash "$SCRIPT_DIR/install.sh"
            ;;
        uninstall)
            bash "$SCRIPT_DIR/uninstall.sh"
            ;;
        set)
            shift
            ai-env set "$@"
            ;;
        get)
            shift
            ai-env get "$@"
            ;;
        list|ls)
            ai-env list
            ;;
        remove|rm|delete|unset)
            shift
            ai-env remove "$@"
            ;;
        reload)
            ai-env reload
            ;;
        export)
            ai-env export
            ;;
        doctor)
            ai-env doctor
            ;;
        version|-v|--version)
            ai-env version
            ;;
        help|-h|--help)
            ai-env help
            ;;
        *)
            printf "${_RED}Unknown command: $1${_RESET}\n"
            printf "Usage: $0 [install|uninstall|set|get|list|remove|reload|export|doctor|version|help]\n"
            exit 1
            ;;
    esac
    exit $?
fi

# Interactive mode
while true; do
    print_menu
    read -r choice

    case "$choice" in
        1)
            bash "$SCRIPT_DIR/install.sh"
            read -rp "Press Enter to continue..."
            ;;
        2)
            read -rp "Enter KEY name: " key
            read -rp "Enter VALUE: " val
            ai-env set "$key" "$val"
            read -rp "Press Enter to continue..."
            ;;
        3)
            read -rp "Enter KEY name: " key
            ai-env get "$key"
            read -rp "Press Enter to continue..."
            ;;
        4)
            ai-env list
            read -rp "Press Enter to continue..."
            ;;
        5)
            read -rp "Enter KEY name: " key
            ai-env remove "$key"
            read -rp "Press Enter to continue..."
            ;;
        6)
            ai-env reload
            read -rp "Press Enter to continue..."
            ;;
        7)
            ai-env export
            read -rp "Press Enter to continue..."
            ;;
        8)
            ai-env doctor
            read -rp "Press Enter to continue..."
            ;;
        9)
            ai-env version
            read -rp "Press Enter to continue..."
            ;;
        10)
            bash "$SCRIPT_DIR/uninstall.sh"
            read -rp "Press Enter to continue..."
            ;;
        0)
            printf "Goodbye!\n"
            exit 0
            ;;
        *)
            printf "${_RED}Invalid choice. Please try again.${_RESET}\n"
            sleep 1
            ;;
    esac
done
