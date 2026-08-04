# ==============================================================================
# manage.ps1 - ai-env Management Script for Windows
# Supports interactive numbered menu & direct CLI parameters
# Usage:
#   Interactive:  .\manage.ps1
#   CLI Command:  .\manage.ps1 install
#                 .\manage.ps1 set OPENAI_API_KEY sk-xxxx
#                 .\manage.ps1 list
#                 .\manage.ps1 doctor
# ==============================================================================

$ErrorActionPreference = "Stop"

$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { (Get-Location).Path }

function Run-Install {
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $ScriptDir "install.ps1")
}

function Run-Uninstall {
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $ScriptDir "uninstall.ps1")
}

function Run-AiEnv($cmdArgs) {
    $psScript = Join-Path $ScriptDir "ai-env.ps1"
    if (Test-Path $psScript) {
        & powershell -NoProfile -ExecutionPolicy Bypass -File $psScript @cmdArgs
    } else {
        $installedScript = Join-Path $HOME ".config\ai-env\ai-env.ps1"
        if (Test-Path $installedScript) {
            & powershell -NoProfile -ExecutionPolicy Bypass -File $installedScript @cmdArgs
        } else {
            Write-Host "ai-env is not installed. Please run option 1 (Install) first." -ForegroundColor Red
        }
    }
}

function Show-Menu {
    while ($true) {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "     ai-env Management Tool (Windows)   " -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host " 1. Install ai-env"
        Write-Host " 2. Set API Key (set)"
        Write-Host " 3. Get API Key (get)"
        Write-Host " 4. List API Keys (list)"
        Write-Host " 5. Remove API Key (remove)"
        Write-Host " 6. Reload Keys (reload)"
        Write-Host " 7. Export Keys (export)"
        Write-Host " 8. Run Diagnostics (doctor)"
        Write-Host " 9. Show Version (version)"
        Write-Host "10. Uninstall ai-env"
        Write-Host " 0. Exit"
        Write-Host "========================================" -ForegroundColor Cyan
        $choice = Read-Host "Please enter your choice [0-10]"

        switch ($choice.Trim()) {
            '1' {
                Run-Install
            }
            '2' {
                $key = Read-Host "Enter variable name (e.g. OPENAI_API_KEY)"
                $val = Read-Host "Enter variable value"
                if ($key -and $val) {
                    Run-AiEnv @("set", $key, $val)
                } else {
                    Write-Host "Key and Value are required." -ForegroundColor Red
                }
            }
            '3' {
                $key = Read-Host "Enter variable name"
                if ($key) {
                    Run-AiEnv @("get", $key)
                }
            }
            '4' {
                Run-AiEnv @("list")
            }
            '5' {
                $key = Read-Host "Enter variable name to remove"
                if ($key) {
                    Run-AiEnv @("remove", $key)
                }
            }
            '6' {
                Run-AiEnv @("reload")
            }
            '7' {
                Run-AiEnv @("export")
            }
            '8' {
                Run-AiEnv @("doctor")
            }
            '9' {
                Run-AiEnv @("version")
            }
            '10' {
                Run-Uninstall
            }
            '0' {
                Write-Host "Exiting..."
                return
            }
            default {
                Write-Host "Invalid option, please try again." -ForegroundColor Red
            }
        }
    }
}

function Main {
    if ($args.Count -eq 0) {
        Show-Menu
    } else {
        $firstArg = $args[0].ToLower()
        switch ($firstArg) {
            'install'   { Run-Install }
            'uninstall' { Run-Uninstall }
            default     { Run-AiEnv $args }
        }
    }
}

Main @args
