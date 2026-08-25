[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ProjectId
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
    throw 'WSL이 필요합니다. 관리자 PowerShell에서 wsl --install -d Ubuntu를 먼저 실행하세요.'
}

$wslRepo = (& wsl.exe wslpath -a -u $PSScriptRoot).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($wslRepo)) {
    throw '저장소 경로를 WSL 경로로 변환하지 못했습니다.'
}

& wsl.exe bash "$wslRepo/bootstrap.sh" $ProjectId
if ($LASTEXITCODE -ne 0) {
    throw "bootstrap.sh 실행이 종료 코드 $LASTEXITCODE 로 실패했습니다."
}

Write-Host ''
Write-Host '다음 명령으로 Command Code 구현 세션을 시작하세요:'
Write-Host '  .\harness.ps1 start --run lab-20260825-01'
