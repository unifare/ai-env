# ==============================================================================
# install.ps1 - Windows Installer for ai-env
# Usage: powershell -ExecutionPolicy Bypass -File install.ps1
# ==============================================================================

$ErrorActionPreference = "Stop"

$AI_ENV_VERSION = "1.0.0"
$AI_ENV_DIR = Join-Path $HOME ".config\ai-env"
$AI_ENV_KEYS = Join-Path $AI_ENV_DIR "keys"
$AI_ENV_INIT = Join-Path $AI_ENV_DIR "init.ps1"
$AI_ENV_CONFIG = Join-Path $AI_ENV_DIR "config"

function Step($msg) { Write-Host "`n▸ $msg" -ForegroundColor Cyan }
function Ok($msg)   { Write-Host "  ✓ $msg" -ForegroundColor Green }
function Err($msg)  { Write-Host "  ✗ $msg" -ForegroundColor Red }
function Warn($msg) { Write-Host "  ⚠ $msg" -ForegroundColor Yellow }
function Info($msg) { Write-Host "  ℹ $msg" -ForegroundColor Cyan }

function Install-AiEnv {
    Write-Host "ai-env v${AI_ENV_VERSION} Installer (Windows)" -ForegroundColor Cyan
    Write-Host "══════════════════════════════════════"

    $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { (Get-Location).Path }

    # Step 1: Create directory
    Step "Creating config directory"
    if (-not (Test-Path $AI_ENV_DIR)) {
        New-Item -ItemType Directory -Path $AI_ENV_DIR -Force | Out-Null
    }
    Ok "Config directory: ${AI_ENV_DIR}"

    # Step 2: Copy scripts
    Step "Installing scripts"
    $filesToCopy = @("ai-env.ps1", "init.ps1", "ai-env.cmd", "ai-env")
    foreach ($f in $filesToCopy) {
        $src = Join-Path $scriptDir $f
        if (Test-Path $src) {
            Copy-Item -Path $src -Destination $AI_ENV_DIR -Force
            Ok "Installed: $f -> ${AI_ENV_DIR}"
        } else {
            Warn "Source file missing: $f"
        }
    }

    # Step 3: Default config
    Step "Installing config"
    $configContent = @"
# ai-env configuration
AI_ENV_VERSION=${AI_ENV_VERSION}
AI_ENV_MASK_MODE=partial
"@
    Set-Content -Path $AI_ENV_CONFIG -Value $configContent -Encoding UTF8
    Ok "Installed: ${AI_ENV_CONFIG}"

    # Step 4: Setup keys file
    Step "Setting up keys file"
    if (-not (Test-Path $AI_ENV_KEYS)) {
        New-Item -ItemType File -Path $AI_ENV_KEYS -Force | Out-Null
        Ok "Created keys file: ${AI_ENV_KEYS}"
    } else {
        Ok "Keys file exists: ${AI_ENV_KEYS}"
    }

    # Step 5: Update User PATH
    Step "Checking User PATH"
    $userPath = [Environment]::GetEnvironmentVariable("PATH", [EnvironmentVariableTarget]::User)
    if ($null -eq $userPath) { $userPath = "" }
    $pathEntries = $userPath -split ";"

    if ($pathEntries -notcontains $AI_ENV_DIR) {
        $newPath = ($pathEntries + $AI_ENV_DIR) -join ";"
        [Environment]::SetEnvironmentVariable("PATH", $newPath, [EnvironmentVariableTarget]::User)
        $env:PATH = "$env:PATH;$AI_ENV_DIR"
        Ok "Added $AI_ENV_DIR to User PATH"
    } else {
        Ok "$AI_ENV_DIR is already in User PATH"
    }

    # Step 6: Configure PowerShell Profile
    Step "Setting up PowerShell profile integration"
    $profilePath = $PROFILE
    $profileDir = Split-Path -Parent $profilePath

    if (-not (Test-Path $profileDir)) {
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    }

    if (-not (Test-Path $profilePath)) {
        New-Item -ItemType File -Path $profilePath -Force | Out-Null
    }

    $sourceLine = "if (Test-Path `"$AI_ENV_INIT`") { . `"$AI_ENV_INIT`" }"
    $existingProfile = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue

    if ($existingProfile -and $existingProfile.Contains("init.ps1")) {
        Ok "Profile already configured: $profilePath"
    } else {
        Add-Content -Path $profilePath -Value "`n# ai-env: manage AI API keys`n$sourceLine`n"
        Ok "Added init line to profile: $profilePath"
    }

    # Step 7: Load for current session
    Step "Loading for current session"
    if (Test-Path $AI_ENV_INIT) {
        . $AI_ENV_INIT
        Ok "Loaded ai-env in current session"
    }

    # Print success
    Write-Host "`n  ╔══════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "  ║   ai-env installed successfully! 🎉   ║" -ForegroundColor Green
    Write-Host "  ╚══════════════════════════════════════╝`n" -ForegroundColor Green

    Write-Host "  Quick start:" -ForegroundColor White
    Write-Host "    ai-env set OPENAI_API_KEY sk-your-key"
    Write-Host "    ai-env list"
    Write-Host "    ai-env doctor`n"

    Write-Host "  New terminal: automatically loaded" -ForegroundColor White
    Write-Host "  Current terminal: already loaded ✅`n" -ForegroundColor White
}

Install-AiEnv
