[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ProjectId,

    [Parameter(Mandatory = $false)]
    [string]$CommandCodePath
)

$ErrorActionPreference = 'Stop'

function Refresh-ProcessPath {
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$machinePath;$userPath;$env:Path"
}

function Install-WingetCommand {
    param([string]$CommandName, [string]$PackageId)
    if (Get-Command $CommandName -ErrorAction SilentlyContinue) { return }
    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        throw "필수 명령 '$CommandName'이 없고 winget도 없습니다. Microsoft App Installer를 설치한 뒤 다시 실행하세요."
    }
    & winget.exe install --id $PackageId --exact --silent --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) { throw "winget 패키지 설치 실패: $PackageId" }
    Refresh-ProcessPath
}

Install-WingetCommand -CommandName git -PackageId Git.Git
Install-WingetCommand -CommandName gcloud -PackageId Google.CloudSDK
Install-WingetCommand -CommandName terraform -PackageId Hashicorp.Terraform
Install-WingetCommand -CommandName jq -PackageId jqlang.jq
Install-WingetCommand -CommandName rg -PackageId BurntSushi.ripgrep.MSVC
Install-WingetCommand -CommandName python -PackageId Python.Python.3.12

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
if (-not $bashExe) { throw 'Git for Windows의 bash.exe를 찾지 못했습니다.' }

$windowsBin = Join-Path $PSScriptRoot 'scripts\windows-bin'
$env:Path = "$windowsBin;$env:Path"
$env:HARNESS_WINDOWS_REPO = $PSScriptRoot
$repoUnix = (& $bashExe -lc 'cygpath -u "$HARNESS_WINDOWS_REPO"').Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($repoUnix)) {
    throw '저장소 경로를 Git Bash 경로로 변환하지 못했습니다.'
}

& $bashExe "$repoUnix/scripts/bootstrap-windows.sh" $ProjectId
if ($LASTEXITCODE -ne 0) {
    throw "Windows bootstrap이 종료 코드 $LASTEXITCODE 로 실패했습니다."
}

$shimDir = Join-Path $HOME '.local\bin'
New-Item -ItemType Directory -Force -Path $shimDir | Out-Null
$shimPath = Join-Path $shimDir 'gcp-lab-harness.cmd'
$shim = "@echo off`r`npowershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$PSScriptRoot\harness.ps1`" %*`r`n"
[IO.File]::WriteAllText($shimPath, $shim, [Text.UTF8Encoding]::new($false))
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if (($userPath -split ';') -notcontains $shimDir) {
    [Environment]::SetEnvironmentVariable('Path', "$shimDir;$userPath", 'User')
    $env:Path = "$shimDir;$env:Path"
}

if ($CommandCodePath) {
    $resolvedCommandCode = (Resolve-Path $CommandCodePath).Path
    if ($resolvedCommandCode -ieq (Join-Path $env:SystemRoot 'System32\cmd.exe')) {
        throw 'Windows 명령 프롬프트 cmd.exe가 아니라 Command Code CLI 실행 파일 경로가 필요합니다.'
    }
    [Environment]::SetEnvironmentVariable('COMMAND_CODE_BIN', $resolvedCommandCode, 'User')
    $env:COMMAND_CODE_BIN = $resolvedCommandCode
} else {
    Write-Warning 'Command Code CLI 경로가 Windows cmd.exe와 충돌할 수 있습니다. 사용할 경우 -CommandCodePath 또는 사용자 환경 변수 COMMAND_CODE_BIN을 지정하세요.'
}

Write-Host ''
Write-Host 'WSL 없이 준비되었습니다. 새 PowerShell에서 다음 명령으로 시작하세요:'
Write-Host '  .\harness.ps1 run-all --run lab-20260825-01'
