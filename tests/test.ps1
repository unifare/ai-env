# ==============================================================================
# test.ps1 - ai-env PowerShell Test Suite
# Usage: powershell -ExecutionPolicy Bypass -File .\tests\test.ps1
# ==============================================================================

$ErrorActionPreference = "Continue"

$TestDir = Join-Path $env:TEMP "ai-env-test-$PID"
$TestKeys = Join-Path $TestDir "keys"

$TestsPassed = 0
$TestsFailed = 0

function Section($msg) { Write-Host "`n▸ $msg" -ForegroundColor Cyan }
function Pass($msg)    { $global:TestsPassed++; Write-Host "  ✓ $msg" -ForegroundColor Green }
function Fail($msg)    { $global:TestsFailed++; Write-Host "  ✗ $msg" -ForegroundColor Red }

$ScriptDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Definition)
$AiEnvPs1 = Join-Path $ScriptDir "ai-env.ps1"

function Setup {
    if (Test-Path $TestDir) { Remove-Item -Path $TestDir -Recurse -Force }
    New-Item -ItemType Directory -Path $TestDir -Force | Out-Null
    $env:AI_ENV_DIR = $TestDir
    $env:AI_ENV_KEYS = $TestKeys
}

function Teardown {
    if (Test-Path $TestDir) { Remove-Item -Path $TestDir -Recurse -Force }
    $env:AI_ENV_DIR = $null
    $env:AI_ENV_KEYS = $null
}

function Run-AiEnvScript($argsList) {
    $escapedArgs = ($argsList | ForEach-Object { "`"$_`"" }) -join " "
    
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = "powershell.exe"
    $pinfo.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$AiEnvPs1`" $escapedArgs"
    $pinfo.RedirectStandardOutput = $true
    $pinfo.RedirectStandardError = $true
    $pinfo.UseShellExecute = $false
    $pinfo.CreateNoWindow = $true

    if ($env:AI_ENV_DIR) { $pinfo.EnvironmentVariables["AI_ENV_DIR"] = $env:AI_ENV_DIR }
    if ($env:AI_ENV_KEYS) { $pinfo.EnvironmentVariables["AI_ENV_KEYS"] = $env:AI_ENV_KEYS }

    $p = [System.Diagnostics.Process]::Start($pinfo)
    $stdout = $p.StandardOutput.ReadToEnd()
    $stderr = $p.StandardError.ReadToEnd()
    $p.WaitForExit()

    return @{
        ExitCode = $p.ExitCode
        Output   = $stdout + "`n" + $stderr
    }
}

# --- Tests ---

function Test-Version {
    Section "version command"
    $res = Run-AiEnvScript @("version")
    if ($res.Output -match "ai-env v") { Pass "version string matches" } else { Fail "version string failed" }
    if ($res.ExitCode -eq 0) { Pass "version exit code 0" } else { Fail "version exit code non-zero" }
}

function Test-Help {
    Section "help command"
    $res = Run-AiEnvScript @("help")
    if ($res.Output -match "AI API Key Manager") { Pass "help contains description" } else { Fail "help missing description" }
    if ($res.Output -match "set <KEY> <VALUE>") { Pass "help contains set usage" } else { Fail "help missing set usage" }
}

function Test-SetBasic {
    Section "set command - basic"
    $res = Run-AiEnvScript @("set", "OPENAI_API_KEY", "sk-test123")
    if ($res.ExitCode -eq 0) { Pass "set exit code 0" } else { Fail "set exit code non-zero" }
    if ($res.Output -match "OPENAI_API_KEY set") { Pass "set output confirms key set" } else { Fail "set output confirmation missing" }

    if (Test-Path $TestKeys) {
        $content = Get-Content $TestKeys -Raw
        if ($content -match "export OPENAI_API_KEY='sk-test123'") { Pass "keys file contains export line" } else { Fail "keys file missing export line" }
    } else {
        Fail "keys file not created"
    }
}

function Test-SetSpecialChars {
    Section "set command - special characters"
    Run-AiEnvScript @("set", "SPECIAL_KEY", "hello'world") | Out-Null
    $getRes = Run-AiEnvScript @("get", "SPECIAL_KEY")
    if ($getRes.Output -match "hello'world") { Pass "single quote preserved" } else { Fail "single quote not preserved ($($getRes.Output))" }
}

function Test-SetSpaces {
    Section "set command - spaces in value"
    Run-AiEnvScript @("set", "SPACES_KEY", '"hello world"') | Out-Null
    $getRes = Run-AiEnvScript @("get", "SPACES_KEY")
    if ($getRes.Output -match "hello world") { Pass "spaces preserved" } else { Fail "spaces not preserved ($($getRes.Output))" }
}

function Test-SetInvalidVarName {
    Section "set command - invalid variable names"
    $res1 = Run-AiEnvScript @("set", "123BAD", "val")
    if ($res1.ExitCode -ne 0) { Pass "rejects variable starting with number" } else { Fail "accepted invalid variable starting with number" }

    $res2 = Run-AiEnvScript @("set", "bad-name", "val")
    if ($res2.ExitCode -ne 0) { Pass "rejects variable with hyphen" } else { Fail "accepted invalid variable with hyphen" }
}

function Test-GetNotFound {
    Section "get command - not found"
    $res = Run-AiEnvScript @("get", "NONEXISTENT_KEY_XYZ")
    if ($res.ExitCode -ne 0) { Pass "get nonexistent key exits non-zero" } else { Fail "get nonexistent key exited 0" }
}

function Test-List {
    Section "list command"
    Run-AiEnvScript @("set", "LIST_KEY1", "sk-abc12345") | Out-Null
    $res = Run-AiEnvScript @("list")
    if ($res.Output -match "LIST_KEY1") { Pass "list contains LIST_KEY1" } else { Fail "list missing LIST_KEY1" }
    if ($res.Output -notmatch "sk-abc12345") { Pass "list masks full value" } else { Fail "list exposed full value" }
}

function Test-Remove {
    Section "remove command"
    Run-AiEnvScript @("set", "REMOVE_KEY", "temp_val") | Out-Null
    $res = Run-AiEnvScript @("remove", "REMOVE_KEY")
    if ($res.ExitCode -eq 0) { Pass "remove exit code 0" } else { Fail "remove exit code non-zero" }

    $content = Get-Content $TestKeys -Raw -ErrorAction SilentlyContinue
    if ($content -notmatch "REMOVE_KEY") { Pass "key removed from keys file" } else { Fail "key still present in file" }
}

function Test-Doctor {
    Section "doctor command"
    $res = Run-AiEnvScript @("doctor")
    if ($res.Output -match "ai-env doctor") { Pass "doctor output header present" } else { Fail "doctor output header missing" }
}

function Main {
    Write-Host "ai-env PowerShell Test Suite" -ForegroundColor Cyan
    Write-Host "══════════════════════════════════════`n"

    Setup
    try {
        Test-Version
        Test-Help
        Test-SetBasic
        Test-SetSpecialChars
        Test-SetSpaces
        Test-SetInvalidVarName
        Test-GetNotFound
        Test-List
        Test-Remove
        Test-Doctor
    } finally {
        Teardown
    }

    $total = $global:TestsPassed + $global:TestsFailed
    Write-Host "`n══════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "Results: $global:TestsPassed passed, $global:TestsFailed failed, $total total`n"

    if ($global:TestsFailed -eq 0) {
        Write-Host "All tests passed! ✅`n" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "Some tests failed! ❌`n" -ForegroundColor Red
        exit $global:TestsFailed
    }
}

Main
