<# Windows-Einstieg für vorhandene Godot-Aufnahme-/Messszenen; nutzt die echte GPU.
Beispiel: ./tools/render_windows.ps1 -Godot C:/tools/godot.exe -OptionsJson '["--map=eeve","--phase=welle","--messen=3"]'
Ressourcen vorher über tools/windows.ps1 -Tool tools/godot_import.sh importieren.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Godot,
    [string]$Scene = 'res://tools/screenshot.tscn',
    [string]$OptionsJson = '[]',
    [ValidatePattern('^[a-zA-Z0-9_-]+$')][string]$Name = 'render',
    [int]$TimeoutSeconds = 120
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$stdout = Join-Path $repo ".godot/$Name.log"
$stderr = Join-Path $repo ".godot/$Name-errors.log"
$before = $env:APPDATA
try {
    $env:APPDATA = Join-Path (Split-Path $repo -Parent) '.tdhub-test-profile'
    $options = @(ConvertFrom-Json $OptionsJson)
    $arguments = @('--path', ('"' + $repo + '"'), '--resolution', '1600x1000', $Scene)
    if ($options.Count) {
        $arguments += '--'
        foreach ($option in $options) {
            if ([string]$option -match '["\r\n]') { throw 'Option enthält ungültige Zeichen.' }
            $arguments += '"' + [string]$option + '"'
        }
    }
    $process = Start-Process -FilePath $Godot -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    while (-not $process.WaitForExit(1000)) {
        if ([DateTime]::UtcNow -gt $deadline) {
            $process.Kill()
            throw "Godot-Aufnahme: Timeout; Details in $stderr"
        }
    }
    $errors = @(Select-String -LiteralPath $stdout, $stderr -Pattern 'SCRIPT ERROR|SHADER ERROR|^ERROR:|Parse Error')
    if ($process.ExitCode -ne 0 -or $errors.Count) {
        $errors | Select-Object -First 12 | ForEach-Object { Write-Output $_.Line }
        throw "Godot-Aufnahme fehlgeschlagen; Logs in .godot/$Name*.log"
    }
    Get-Content -LiteralPath $stdout | Where-Object { $_ -match '^(BILD|GPU|Vulkan|MESSUNG)' }
}
finally { $env:APPDATA = $before }
