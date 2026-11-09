<# Rendert die Shader-Vitrine mit echter GPU und prüft Compiler-/Laufzeitfehler.
Vorher Ressourcen mit tools/windows.ps1 -Tool tools/godot_import.sh importieren.
#>
[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$Godot)
$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
& (Join-Path $repo 'tools/render_windows.ps1') -Godot $Godot -Scene 'res://tools/shaders/probe.tscn' -Name 'shader-probe'
foreach ($quality in 0..2) {
    $file = Join-Path $repo ".godot/shader-probe-$quality.png"
    if (-not (Test-Path -LiteralPath $file)) { throw "Bild fehlt: $file" }
}
Write-Output 'Shader-Vitrine: drei Qualitätsstufen ohne Shader-/Scriptfehler gerendert'
