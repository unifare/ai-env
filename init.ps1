# ==============================================================================
# ai-env - Shell Initialization for PowerShell
# Source this file from your $PROFILE
# ==============================================================================

if ($env:_AI_ENV_LOADED) {
    return
}

if ($env:AI_ENV_DIR) {
    $_AI_ENV_DIR = $env:AI_ENV_DIR
} else {
    $_AI_ENV_DIR = Join-Path $HOME ".config\ai-env"
}

$_AI_ENV_KEYS = Join-Path $_AI_ENV_DIR "keys"
$_AI_ENV_SCRIPT = Join-Path $_AI_ENV_DIR "ai-env.ps1"

# Load existing keys into current process environment
if (Test-Path $_AI_ENV_KEYS) {
    $lines = Get-Content $_AI_ENV_KEYS -ErrorAction SilentlyContinue
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith('#')) { continue }
        if ($trimmed -match '^export\s+([A-Za-z_][A-Za-z0-9_]*)=(.*)$') {
            $k = $Matches[1]
            $rawVal = $Matches[2]
            if ($rawVal.StartsWith("'") -and $rawVal.EndsWith("'") -and $rawVal.Length -ge 2) {
                $rawVal = $rawVal.Substring(1, $rawVal.Length - 2)
            }
            $val = $rawVal -replace "'\\''", "'"
            Set-Item -Path "Env:\$k" -Value $val
        }
    }
}

$env:_AI_ENV_FUNC = "1"

# Wrapper function for immediate shell env updates
function ai-env {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromRemainingArguments=$true)]
        [string[]]$ScriptArgs
    )

    $targetScript = $_AI_ENV_SCRIPT
    if (-not (Test-Path $targetScript)) {
        # Fallback to PATH or script directory
        $cmd = Get-Command "ai-env.ps1" -ErrorAction SilentlyContinue
        if ($cmd) {
            $targetScript = $cmd.Source
        }
    }

    if (-not (Test-Path $targetScript)) {
        Write-Error "ai-env.ps1 not found at $targetScript"
        return
    }

    $rawOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File $targetScript @ScriptArgs
    $retCode = $LASTEXITCODE

    $evalLines = @()
    $displayLines = @()

    foreach ($line in $rawOutput) {
        if ($line -like "__EVAL__:*") {
            $evalLines += $line.Substring(9)
        } else {
            $displayLines += $line
        }
    }

    if ($displayLines.Count -gt 0) {
        $displayLines | ForEach-Object { Write-Output $_ }
    }

    if ($evalLines.Count -gt 0) {
        foreach ($eCode in $evalLines) {
            Invoke-Expression $eCode
        }
    }

    return $retCode
}

$env:_AI_ENV_LOADED = "1"
