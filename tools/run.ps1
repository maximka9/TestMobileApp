param([string]$Godot = '')
$ErrorActionPreference = 'Stop'
$sasaRoot = Split-Path -Parent $PSScriptRoot
if (-not $Godot) {
    $sasaLocal = Join-Path $sasaRoot '.tools\godot\Godot_v4.7.2-stable_win64.exe'
    if (Test-Path -LiteralPath $sasaLocal) { $Godot = $sasaLocal }
    else { $Godot = (Get-Command godot -ErrorAction Stop).Source }
}
& $Godot --path $sasaRoot
