param([string]$Godot = '', [switch]$Visual)
$ErrorActionPreference = 'Stop'
$sasaRoot = Split-Path -Parent $PSScriptRoot
if (-not $Godot) {
    $sasaLocal = Join-Path $sasaRoot '.tools\godot\Godot_v4.7.2-stable_win64_console.exe'
    if (Test-Path -LiteralPath $sasaLocal) { $Godot = $sasaLocal }
    else { $Godot = (Get-Command godot -ErrorAction Stop).Source }
}
function Invoke-SasaCheck([string[]]$Arguments) {
    $sasaPreviousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $sasaOutput = & $Godot @Arguments 2>&1
        $sasaExit = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $sasaPreviousPreference
    }
    $sasaOutput | ForEach-Object { Write-Output ([string]$_) }
    if ($sasaExit -ne 0 -or ($sasaOutput -match 'SCRIPT ERROR:|ERROR:|WARNING:|FAIL:')) {
        throw "Godot verification failed (exit $sasaExit)."
    }
}
Invoke-SasaCheck @('--headless', '--editor', '--path', $sasaRoot, '--quit')
Invoke-SasaCheck @('--headless', '--path', $sasaRoot, '--script', 'tests/test_runner.gd')
Invoke-SasaCheck @('--headless', '--path', $sasaRoot, '--script', 'tests/career_phase9.gd')
foreach ($sasaPhase in @('career_phase1', 'career_phase2', 'career_phase3', 'career_phase4a', 'career_phase4b', 'v05_systems')) {
    Invoke-SasaCheck @('--headless', '--path', $sasaRoot, '--script', "tests/$sasaPhase.gd")
}
$sasaTag = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds().ToString()
Invoke-SasaCheck @('--headless', '--path', $sasaRoot, '--script', 'tests/restart_probe.gd', '--', 'write', $sasaTag)
Invoke-SasaCheck @('--headless', '--path', $sasaRoot, '--script', 'tests/restart_probe.gd', '--', 'read', $sasaTag)
if ($Visual) {
    foreach ($sasaSmoke in @('typography_smoke', 'collaboration_ui_smoke', 'career_final_smoke', 'v05_ui_smoke')) {
        Invoke-SasaCheck @('--path', $sasaRoot, '--script', "tests/$sasaSmoke.gd")
    }
    Invoke-SasaCheck @('--path', $sasaRoot, '--script', 'tests/visual_smoke.gd', '--resolution', '360x640')
}
