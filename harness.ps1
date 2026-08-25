[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$HarnessArgs
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
    throw 'WSL이 필요합니다. 관리자 PowerShell에서 wsl --install -d Ubuntu를 먼저 실행하세요.'
}

$wslRepo = (& wsl.exe wslpath -a -u $PSScriptRoot).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($wslRepo)) {
    throw '저장소 경로를 WSL 경로로 변환하지 못했습니다.'
}

& wsl.exe bash "$wslRepo/bin/gcp-lab-harness" @HarnessArgs
exit $LASTEXITCODE
