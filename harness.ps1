[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$HarnessArgs
)

$ErrorActionPreference = 'Stop'

$gitCommand = Get-Command git -ErrorAction Stop
$gitRoot = Split-Path (Split-Path $gitCommand.Source -Parent) -Parent
$bashCandidates = @(
    (Join-Path $gitRoot 'bin\bash.exe'),
    (Join-Path $env:ProgramFiles 'Git\bin\bash.exe')
)
if (${env:ProgramFiles(x86)}) {
    $bashCandidates += Join-Path ${env:ProgramFiles(x86)} 'Git\bin\bash.exe'
}
$bashExe = $bashCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $bashExe) { throw 'Git for Windows의 bash.exe가 필요합니다. WSL은 필요하지 않습니다.' }

$env:Path = "$(Join-Path $PSScriptRoot 'scripts\windows-bin');$env:Path"
$env:HARNESS_WINDOWS_REPO = $PSScriptRoot
$repoUnix = (& $bashExe -lc 'cygpath -u "$HARNESS_WINDOWS_REPO"').Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($repoUnix)) {
    throw '저장소 경로를 Git Bash 경로로 변환하지 못했습니다.'
}

$needsCommandCode = $HarnessArgs.Count -gt 0 -and (
    $HarnessArgs[0] -in @('start', 'cmd') -or
    ($HarnessArgs[0] -eq 'run-all' -and $HarnessArgs -notcontains '--dry-run')
)
if ($needsCommandCode) {
    $commandCode = $env:COMMAND_CODE_BIN
    if (-not $commandCode) {
        $commandCode = [Environment]::GetEnvironmentVariable('COMMAND_CODE_BIN', 'User')
    }
    if (-not $commandCode) {
        throw 'Command Code CLI의 전체 경로를 사용자 환경 변수 COMMAND_CODE_BIN에 지정하세요. Windows System32의 cmd.exe는 사용할 수 없습니다.'
    }
    if (Test-Path $commandCode) {
        $env:HARNESS_WINDOWS_COMMAND_CODE = (Resolve-Path $commandCode).Path
        $env:COMMAND_CODE_BIN = (& $bashExe -lc 'cygpath -u "$HARNESS_WINDOWS_COMMAND_CODE"').Trim()
    } else {
        $env:COMMAND_CODE_BIN = $commandCode
    }
}

Push-Location $PSScriptRoot
try {
    & $bashExe "$repoUnix/bin/gcp-lab-harness" @HarnessArgs
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
