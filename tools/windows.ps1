<#!
Startet vorhandene Bash-Werkzeuge unter Windows, ohne deren Testlogik zu duplizieren.
Beispiel: ./tools/windows.ps1 -Godot C:/tools/godot.exe -Python C:/tools/python.exe -ToolArgs visuals,systeme
Benutzerdateien bleiben im übergeordneten Workspace unter .tdhub-test-profile statt im echten Spielprofil.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Godot,
    [Parameter(Mandatory = $true)][string]$Python,
    [string]$Tool = 'tools/run_tests.sh',
    [string[]]$ToolArgs = @('geaendert'),
    [string]$ProjectPath = '',
    [int]$Jobs = 4
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
if ($ProjectPath) { $repo = (Resolve-Path -LiteralPath $ProjectPath).Path }
$bash = Join-Path $env:ProgramFiles 'Git/bin/bash.exe'
if (-not (Test-Path -LiteralPath $bash)) { throw 'Git Bash fehlt.' }
$keys = @('GODOT', 'TDHUB_PYTHON', 'PYTHONUTF8', 'APPDATA', 'JOBS', 'LOG_DIR')
$before = @{}
foreach ($key in $keys) { $before[$key] = [Environment]::GetEnvironmentVariable($key, 'Process') }
Push-Location $repo
try {
    $env:GODOT = (Resolve-Path -LiteralPath $Godot).Path.Replace('\', '/')
    $env:TDHUB_PYTHON = (Resolve-Path -LiteralPath $Python).Path.Replace('\', '/')
    $env:PYTHONUTF8 = '1'
    $env:APPDATA = Join-Path (Split-Path $repo -Parent) '.tdhub-test-profile'
    $env:JOBS = [string]$Jobs
    $env:LOG_DIR = (Join-Path $repo '.godot/test-logs').Replace('\', '/')
    New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
    if ($Tool -in @('tools/run_tests.sh', 'tools/prs.sh')) {
        $ToolArgs = @($ToolArgs | ForEach-Object { $_ -split ',' })
    }
    $bootstrap = 'python3() { "$TDHUB_PYTHON" -X utf8 "$@"; }; export -f python3; bash "$@"'
    & $bash -c $bootstrap tdhub $Tool @ToolArgs
    $result = $LASTEXITCODE
}
finally {
    Pop-Location
    foreach ($key in $keys) { [Environment]::SetEnvironmentVariable($key, $before[$key], 'Process') }
}
exit $result
