# ==============================================================================
# ai-env.ps1 - AI API Key Manager for PowerShell
# Version: 1.0.0
# ==============================================================================

$ErrorActionPreference = "Stop"

$AI_ENV_VERSION = "1.0.0"

# Determine config directory
if ($env:AI_ENV_DIR) {
    $AI_ENV_DIR = $env:AI_ENV_DIR
} else {
    $AI_ENV_DIR = Join-Path $HOME ".config\ai-env"
}

$AI_ENV_KEYS = Join-Path $AI_ENV_DIR "keys"
$AI_ENV_CONFIG = Join-Path $AI_ENV_DIR "config"
$AI_ENV_INIT = Join-Path $AI_ENV_DIR "init.ps1"
$AI_ENV_EVAL_PREFIX = "__EVAL__:"

# Utility output helpers
function Print-Ok($msg) {
    Write-Output "OK: $msg"
}

function Print-Err($msg) {
    Write-Output "ERR: $msg"
}

function Print-Warn($msg) {
    Write-Output "WARN: $msg"
}

function Print-Info($msg) {
    Write-Output "INFO: $msg"
}

# Validation: [A-Za-z_][A-Za-z0-9_]*
function Test-VarName($name) {
    if ($name -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') {
        Print-Err "Invalid variable name: '$name'. Must match [A-Za-z_][A-Za-z0-9_]*"
        return $false
    }
    return $true
}

# Escape single quotes for bash export format compatibility: ' -> '\''
function Escape-SingleQuotes($val) {
    if ($null -eq $val) { return "" }
    return $val -replace "'", "'\''"
}

# Unescape single quotes from bash export format
function Unescape-SingleQuotes($val) {
    if ($null -eq $val) { return "" }
    return $val -replace "'\\''", "'"
}

# Ensure directory and keys file exist
function Ensure-KeysFile {
    if (-not (Test-Path $AI_ENV_DIR)) {
        New-Item -ItemType Directory -Path $AI_ENV_DIR -Force | Out-Null
    }
    if (-not (Test-Path $AI_ENV_KEYS)) {
        New-Item -ItemType File -Path $AI_ENV_KEYS -Force | Out-Null
    }
}

# Read keys dictionary from keys file
function Read-KeysFromFile {
    $keysDict = [ordered]@{}
    if (Test-Path $AI_ENV_KEYS) {
        $lines = Get-Content $AI_ENV_KEYS -ErrorAction SilentlyContinue
        foreach ($line in $lines) {
            $trimmed = $line.Trim()
            if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith('#')) {
                continue
            }
            if ($trimmed -match '^export\s+([A-Za-z_][A-Za-z0-9_]*)=(.*)$') {
                $k = $Matches[1]
                $rawVal = $Matches[2]
                # Strip leading and trailing single quotes if present
                if ($rawVal.StartsWith("'") -and $rawVal.EndsWith("'") -and $rawVal.Length -ge 2) {
                    $rawVal = $rawVal.Substring(1, $rawVal.Length - 2)
                }
                $val = Unescape-SingleQuotes $rawVal
                $keysDict[$k] = $val
            }
        }
    }
    return $keysDict
}

# Save keys dictionary back to keys file
function Save-KeysToFile($keysDict) {
    Ensure-KeysFile
    $lines = @()
    foreach ($k in $keysDict.Keys) {
        $v = $keysDict[$k]
        $escaped = Escape-SingleQuotes $v
        $lines += "export ${k}='${escaped}'"
    }
    Set-Content -Path $AI_ENV_KEYS -Value $lines -Encoding UTF8
}

# Command: set
function Cmd-Set($key, $val) {
    if ([string]::IsNullOrEmpty($key) -or $null -eq $val) {
        Print-Err "Usage: ai-env set <KEY> <VALUE>"
        $global:_aienv_rc = 1
        return
    }

    if (-not (Test-VarName $key)) {
        $global:_aienv_rc = 1
        return
    }

    $dict = Read-KeysFromFile
    $dict[$key] = $val
    Save-KeysToFile $dict

    # Set user level environment variable in Windows registry
    try {
        [System.Environment]::SetEnvironmentVariable($key, $val, [System.EnvironmentVariableTarget]::User)
    } catch {
        # Non-critical if permission issue
    }

    # Escaped value for PowerShell eval
    $psEscaped = $val -replace "'", "''"
    Write-Output "${AI_ENV_EVAL_PREFIX} `$env:${key} = '$psEscaped'"
    Print-Ok "${key} set"
    $global:_aienv_rc = 0
    return
}

# Command: get
function Cmd-Get($key) {
    if ([string]::IsNullOrEmpty($key)) {
        Print-Err "Usage: ai-env get <KEY>"
        $global:_aienv_rc = 1
        return
    }

    if (-not (Test-VarName $key)) {
        $global:_aienv_rc = 1
        return
    }

    # Try session env var first
    $envVal = Get-Item "Env:$key" -ErrorAction SilentlyContinue
    if ($null -ne $envVal -and [string]::Empty -ne $envVal.Value) {
        Write-Output $envVal.Value
        $global:_aienv_rc = 0
        return
    }

    # Fall back to keys file
    $dict = Read-KeysFromFile
    if ($dict.Contains($key)) {
        Write-Output $dict[$key]
        $global:_aienv_rc = 0
        return
    }

    # Fall back to User env var
    $userVal = [System.Environment]::GetEnvironmentVariable($key, [System.EnvironmentVariableTarget]::User)
    if (-not [string]::IsNullOrEmpty($userVal)) {
        Write-Output $userVal
        $global:_aienv_rc = 0
        return
    }

    Print-Err "${key} not found"
    $global:_aienv_rc = 1
    return
}

# Command: list
function Cmd-List {
    $dict = Read-KeysFromFile

    if ($dict.Count -eq 0) {
        Print-Info "No keys configured"
        $global:_aienv_rc = 0
        return
    }

    Write-Host ("{0,-35} {1}" -f "KEY", "VALUE") -ForegroundColor White
    Write-Host ("{0,-35} {1}" -f "-----------------------------------", "-------------------")

    foreach ($k in $dict.Keys) {
        $val = $dict[$k]
        if (-not $val) {
            $val = Get-Item "Env:$k" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Value
        }

        $masked = ""
        if ([string]::IsNullOrEmpty($val)) {
            $masked = "(empty)"
        } elseif ($val.Length -le 8) {
            $masked = "********"
        } else {
            $head = $val.Substring(0, 4)
            $tail = $val.Substring($val.Length - 4, 4)
            $masked = "${head}****${tail}"
        }

        Write-Host ("{0,-35} {1}" -f $k, $masked)
    }
    $global:_aienv_rc = 0
    return
}

# Command: remove
function Cmd-Remove($key) {
    if ([string]::IsNullOrEmpty($key)) {
        Print-Err "Usage: ai-env remove <KEY>"
        $global:_aienv_rc = 1
        return
    }

    if (-not (Test-VarName $key)) {
        $global:_aienv_rc = 1
        return
    }

    $dict = Read-KeysFromFile
    if (-not $dict.Contains($key)) {
        Print-Err "${key} not found"
        $global:_aienv_rc = 1
        return
    }

    $dict.Remove($key)
    Save-KeysToFile $dict

    # Remove user level environment variable
    try {
        [System.Environment]::SetEnvironmentVariable($key, $null, [System.EnvironmentVariableTarget]::User)
    } catch {}

    Write-Output "${AI_ENV_EVAL_PREFIX} Remove-Item -Path Env:\${key} -ErrorAction SilentlyContinue"
    Print-Ok "${key} removed"
    $global:_aienv_rc = 0
    return
}

# Command: reload
function Cmd-Reload {
    $dict = Read-KeysFromFile
    if ($dict.Count -eq 0) {
        Print-Err "No keys file found or empty at ${AI_ENV_KEYS}"
        $global:_aienv_rc = 1
        return
    }

    $count = 0
    foreach ($k in $dict.Keys) {
        $val = $dict[$k]
        $psEscaped = $val -replace "'", "''"
        Write-Output "${AI_ENV_EVAL_PREFIX} `$env:${k} = '$psEscaped'"
        $count++
    }

    Print-Ok "Reloaded ${count} key(s)"
    $global:_aienv_rc = 0
    return
}

# Command: export
function Cmd-Export {
    if (Test-Path $AI_ENV_KEYS) {
        Get-Content $AI_ENV_KEYS
    }
    $global:_aienv_rc = 0
    return
}

# Command: doctor
function Cmd-Doctor {
    $issues = 0
    Write-Output "ai-env doctor"
    Write-Output "────────────────────────────────────────"

    # 1. Config dir
    if (Test-Path $AI_ENV_DIR) {
        Print-Ok "Config directory: ${AI_ENV_DIR}"
    } else {
        Print-Err "Config directory not found: ${AI_ENV_DIR}"
        $issues++
    }

    # 2. Command in PATH
    $cmdInPath = Get-Command "ai-env" -ErrorAction SilentlyContinue
    if ($cmdInPath) {
        Print-Ok "ai-env in PATH: $($cmdInPath.Source)"
    } else {
        Print-Warn "ai-env not found in PATH"
        $issues++
    }

    # 3. Init script
    if (Test-Path $AI_ENV_INIT) {
        Print-Ok "Init script: ${AI_ENV_INIT}"
    } else {
        Print-Err "Init script not found: ${AI_ENV_INIT}"
        $issues++
    }

    # 4. Profile integration
    $profilePath = $PROFILE
    if (Test-Path $profilePath) {
        $profileContent = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
        if ($profileContent -and $profileContent -match 'init\.ps1') {
            Print-Ok "Shell integration in profile: ${profilePath}"
        } else {
            Print-Warn "Shell integration not found in profile: ${profilePath}"
            $issues++
        }
    } else {
        Print-Warn "PowerShell profile does not exist: ${profilePath}"
        $issues++
    }

    # 5. Shell function
    if (Get-Command "ai-env" -CommandType Function -ErrorAction SilentlyContinue) {
        Print-Ok "PowerShell wrapper function loaded"
    } else {
        Print-Warn "PowerShell wrapper function not loaded (source ${AI_ENV_INIT})"
        $issues++
    }

    # 6. Keys file
    if (Test-Path $AI_ENV_KEYS) {
        $dict = Read-KeysFromFile
        Print-Ok "Keys file exists ($($dict.Count) key(s))"
    } else {
        Print-Warn "Keys file not found (will be created on first set)"
    }

    Write-Host "────────────────────────────────────────" -ForegroundColor Cyan
    if ($issues -eq 0) {
        Print-Ok "All checks passed"
        $global:_aienv_rc = 0
    } else {
        Print-Err "${issues} issue(s) found"
        $global:_aienv_rc = 1
    }
    return
}

# Command: version
function Cmd-Version {
    Write-Output "ai-env v${AI_ENV_VERSION}"
    $global:_aienv_rc = 0
    return
}

# Command: help
function Cmd-Help {
    $helpText = @"
ai-env - AI API Key Manager v${AI_ENV_VERSION} (PowerShell)

Usage:
  ai-env set <KEY> <VALUE>    Set an environment variable
  ai-env get <KEY>            Get the value of a variable
  ai-env list                 List all variables (values masked)
  ai-env remove <KEY>         Remove a variable
  ai-env reload               Reload all variables into current shell
  ai-env export               Export all variables (for piping)
  ai-env doctor               Run diagnostic checks
  ai-env version              Show version
  ai-env help                 Show this help

Examples:
  ai-env set OPENAI_API_KEY sk-xxxx
  ai-env get OPENAI_API_KEY
  ai-env list
  ai-env remove OPENAI_API_KEY
  ai-env reload
  ai-env export > ~\.env.backup

Configuration:
  Directory:  $AI_ENV_DIR
  Keys file:  $AI_ENV_KEYS
  Init file:  $AI_ENV_INIT

Supported Shells:
  PowerShell 5.1+, PowerShell 7+, Bash, Zsh
"@
    Write-Output $helpText
    $global:_aienv_rc = 0
    return
}

# Initialize global return code
$global:_aienv_rc = 0

# Main dispatcher
function Main {
    param(
        [Parameter(ValueFromRemainingArguments=$true)]
        [string[]]$argsList
    )

    if ($null -eq $argsList -or $argsList.Count -eq 0) {
        Cmd-Help
        return
    }

    $cmd = $argsList[0]
    $remaining = @()
    if ($argsList.Count -gt 1) {
        for ($i = 1; $i -lt $argsList.Count; $i++) {
            $remaining += $argsList[$i]
        }
    }

    switch -Regex ($cmd) {
        '^(set)$' {
            $k = if ($remaining.Count -gt 0) { $remaining[0] } else { $null }
            $v = if ($remaining.Count -gt 1) { $remaining[1] } else { $null }
            Cmd-Set $k $v
            $script:exitCode = $global:_aienv_rc
            break
        }
        '^(get)$' {
            $k = if ($remaining.Count -gt 0) { $remaining[0] } else { $null }
            Cmd-Get $k
            $script:exitCode = $global:_aienv_rc
            break
        }
        '^(list|ls)$' {
            Cmd-List
            $script:exitCode = $global:_aienv_rc
            break
        }
        '^(remove|rm|delete|unset)$' {
            $k = if ($remaining.Count -gt 0) { $remaining[0] } else { $null }
            Cmd-Remove $k
            $script:exitCode = $global:_aienv_rc
            break
        }
        '^(reload)$' {
            Cmd-Reload
            $script:exitCode = $global:_aienv_rc
            break
        }
        '^(export)$' {
            Cmd-Export
            $script:exitCode = $global:_aienv_rc
            break
        }
        '^(doctor)$' {
            Cmd-Doctor
            $script:exitCode = $global:_aienv_rc
            break
        }
        '^(version|-v|--version)$' {
            Cmd-Version
            $script:exitCode = $global:_aienv_rc
            break
        }
        '^(help|-h|--help)$' {
            Cmd-Help
            $script:exitCode = $global:_aienv_rc
            break
        }
        default {
            Print-Err "Unknown command: ${cmd}"
            Print-Info "Run 'ai-env help' for usage"
            $global:_aienv_rc = 1
            break
        }
    }
    # Preserve exit code for help/case with no matching command
    if (-not $global:_aienv_rc) {
        $global:_aienv_rc = 0
    }
}

Main @args
exit $global:_aienv_rc
