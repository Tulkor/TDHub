<# Windows-Einstieg für vorhandene Godot-Aufnahme-/Messszenen; nutzt die echte GPU.
Beispiel: ./tools/render_windows.ps1 -Godot C:/tools/godot.exe -OptionsJson '["--map=eeve","--phase=welle","--messen=3"]'
Ressourcen vorher über tools/windows.ps1 -Tool tools/godot_import.sh importieren.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Godot,
    [string]$Scene = 'res://tools/screenshot.tscn',
    [string]$OptionsJson = '[]',
    [switch]$EngineVerbose,
    [ValidatePattern('^[a-zA-Z0-9_-]+$')][string]$Name = 'render',
    [int]$TimeoutSeconds = 120
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$stdout = Join-Path $repo ".godot/$Name.log"
$stderr = Join-Path $repo ".godot/$Name-errors.log"
# Isolierter Projekt-Header: NO_FOCUS muss bereits vor der nativen Fenstererzeugung gelten.
# Ressourcen/Importcache werden per Junction geteilt; das echte Projekt bleibt interaktiv.
# Je Repo-Ordner ein eigenes Testprojekt (z. B. Worktree neben dem Klon), sonst zeigen die Junctions auf den anderen Ordner.
$leaf = Split-Path $repo -Leaf
$qaProject = Join-Path (Split-Path $repo -Parent) $(if ($leaf -eq 'TDHub') { '.tdhub-render-project' } else { '.tdhub-render-' + $leaf })
New-Item -ItemType Directory -Force -Path $qaProject | Out-Null
foreach ($directory in @('assets','data','docs','export','scenes','scripts','tests','tools','.godot')) {
    $target = Join-Path $repo $directory
    $link = Join-Path $qaProject $directory
    if (-not (Test-Path -LiteralPath $target)) { continue }
    if (-not (Test-Path -LiteralPath $link)) {
        New-Item -ItemType Junction -Path $link -Target $target | Out-Null
    }
    $item = Get-Item -LiteralPath $link
    if ($item.LinkType -ne 'Junction' -or [IO.Path]::GetFullPath([string]$item.Target) -ne [IO.Path]::GetFullPath($target)) {
        throw "Testprojekt verweist auf einen unerwarteten Ressourcenordner: $link"
    }
}
$projectText = [IO.File]::ReadAllText((Join-Path $repo 'project.godot'))
$projectText = $projectText.Replace('[display]', "[display]`nwindow/size/no_focus=true`nwindow/size/initial_screen=1`nwindow/size/initial_position_type=2`nwindow/size/mode=0")
$projectText += "`n[tdhub]`nqa_window=true`nqa_screen=1`n"
$qaConfig = Join-Path $qaProject 'project.godot'
if (-not (Test-Path -LiteralPath $qaConfig) -or [IO.File]::ReadAllText($qaConfig) -ne $projectText) {
    [IO.File]::WriteAllText($qaConfig,$projectText,[Text.UTF8Encoding]::new($false))
}
$before = $env:APPDATA
try {
    $env:APPDATA = Join-Path (Split-Path $repo -Parent) '.tdhub-test-profile'
    $options = @((ConvertFrom-Json $OptionsJson) | ForEach-Object { $_ })
    $arguments = @('--audio-driver', 'Dummy', '--path', ('"' + $qaProject + '"'), '--screen', '1', '--windowed', '--resolution', '1600x1000', $Scene)
    if (-not @($options | Where-Object { [string]$_ -like '--messen=*' }).Count) { $arguments += @('--max-fps','30') }
    if ($EngineVerbose) { $arguments = @('--verbose') + $arguments }
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
        $parseErrors = @(Select-String -LiteralPath $stdout, $stderr -Pattern 'SCRIPT ERROR: Parse Error|Failed to load script' -ErrorAction SilentlyContinue)
        if ($parseErrors.Count) {
            $process.Kill()
            $parseErrors | Select-Object -First 6 | ForEach-Object { Write-Output $_.Line }
            throw "Godot-Parserfehler; Details in $stderr"
        }
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
    Get-Content -LiteralPath $stdout | Where-Object { $_ -match '^(BILD|GPU|Vulkan|MESSUNG|QA_FENSTER)' }
}
finally { $env:APPDATA = $before }
