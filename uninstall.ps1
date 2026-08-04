# ==============================================================================
# uninstall.ps1 - Windows Uninstaller for ai-env
# Usage: powershell -ExecutionPolicy Bypass -File uninstall.ps1
# ==============================================================================

$ErrorActionPreference = "Stop"

$AI_ENV_DIR = Join-Path $HOME ".config\ai-env"
$AI_ENV_KEYS = Join-Path $AI_ENV_DIR "keys"

function Step($msg) { Write-Host "`n▸ $msg" -ForegroundColor Cyan }
function Ok($msg)   { Write-Host "  ✓ $msg" -ForegroundColor Green }
function Warn($msg) { Write-Host "  ⚠ $msg" -ForegroundColor Yellow }

function Uninstall-AiEnv {
    Write-Host "ai-env Uninstaller (Windows)" -ForegroundColor Cyan
    Write-Host "══════════════════════════════════════"

    # 1. Clean profile
    Step "Removing PowerShell profile integration"
    if (Test-Path $PROFILE) {
        $lines = Get-Content $PROFILE -ErrorAction SilentlyContinue
        $filtered = $lines | Where-Object { $_ -notmatch 'ai-env' -and $_ -notmatch 'init\.ps1' }
        Set-Content -Path $PROFILE -Value $filtered -Encoding UTF8
        Ok "Cleaned profile: $PROFILE"
    }

    # 2. Unset variables
    Step "Unsetting environment variables"
    if (Test-Path $AI_ENV_KEYS) {
        $lines = Get-Content $AI_ENV_KEYS -ErrorAction SilentlyContinue
        foreach ($line in $lines) {
            if ($line -match '^export\s+([A-Za-z_][A-Za-z0-9_]*)=') {
                $k = $Matches[1]
                Remove-Item -Path "Env:\$k" -ErrorAction SilentlyContinue
                try {
                    [System.Environment]::SetEnvironmentVariable($k, $null, [System.EnvironmentVariableTarget]::User)
                } catch {}
            }
        }
        Ok "Unset ai-env environment variables"
    }

    # 3. Backup keys and remove dir
    Step "Removing config directory"
    if (Test-Path $AI_ENV_KEYS) {
        $backupPath = Join-Path $HOME ".ai-env-keys.backup"
        Copy-Item -Path $AI_ENV_KEYS -Destination $backupPath -Force
        Ok "Keys backed up to: $backupPath"
    }

    if (Test-Path $AI_ENV_DIR) {
        Remove-Item -Path $AI_ENV_DIR -Recurse -Force
        Ok "Removed: $AI_ENV_DIR"
    }

    # 4. Remove function
    Remove-Item -Path "Function:\ai-env" -ErrorAction SilentlyContinue
    $env:_AI_ENV_LOADED = $null
    $env:_AI_ENV_FUNC = $null

    Write-Host "`n  ai-env has been uninstalled successfully.`n" -ForegroundColor Green
}

Uninstall-AiEnv
