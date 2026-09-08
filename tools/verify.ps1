param([string]$Godot = '', [switch]$Targeted, [switch]$SkipVisual, [switch]$NegativeControl)
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
try {
    if ($NegativeControl) {
        $sasaNegative = Join-Path $sasaRoot 'build/checks/negative_control.gd'
        New-Item -ItemType Directory -Force (Split-Path $sasaNegative) | Out-Null
        [IO.File]::WriteAllText($sasaNegative, "extends SceneTree`nfunc _initialize():`n`tprinterr('FAIL: controlled negative check')`n`tquit(1)`n")
        try { Invoke-SasaCheck @('--headless', '--path', $sasaRoot, '--script', $sasaNegative) }
        finally { Remove-Item -LiteralPath $sasaNegative }
        throw 'Negative control unexpectedly passed.'
    }
    Invoke-SasaCheck @('--headless', '--editor', '--path', $sasaRoot, '--quit')
    $sasaSuites = @('v051_stabilization', 'v05_systems')
    if (-not $Targeted) {
        $sasaSuites += @('test_runner', 'career_phase9', 'career_phase1', 'career_phase2', 'career_phase3', 'career_phase4a', 'career_phase4b')
    }
    foreach ($sasaSuite in $sasaSuites) {
        Invoke-SasaCheck @('--headless', '--path', $sasaRoot, '--script', "tests/$sasaSuite.gd")
    }
    if (-not $Targeted) {
        $sasaTag = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds().ToString()
        Invoke-SasaCheck @('--headless', '--path', $sasaRoot, '--script', 'tests/restart_probe.gd', '--', 'write', $sasaTag)
        Invoke-SasaCheck @('--headless', '--path', $sasaRoot, '--script', 'tests/restart_probe.gd', '--', 'read', $sasaTag)
    }
    $ErrorActionPreference = 'Continue'
    $sasaPython = & python (Join-Path $sasaRoot 'tests/test_streamer_import.py') 2>&1
    $sasaPythonExit = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    $sasaPython | ForEach-Object { Write-Output ([string]$_) }
    if ($sasaPythonExit -ne 0) { throw "Importer tests failed ($sasaPythonExit)" }
    if (-not $SkipVisual) {
        $sasaSmokes = @('v051_ui_smoke')
        if (-not $Targeted) { $sasaSmokes += @('typography_smoke', 'collaboration_ui_smoke', 'career_final_smoke', 'v05_ui_smoke', 'visual_smoke') }
        foreach ($sasaSmoke in $sasaSmokes) {
            Invoke-SasaCheck @('--path', $sasaRoot, '--script', "tests/$sasaSmoke.gd")
        }
    }
    Write-Output 'VERIFY PASS'
    exit 0
} catch {
    Write-Output ("VERIFY FAILED: " + $_.Exception.Message)
    exit 1
}
