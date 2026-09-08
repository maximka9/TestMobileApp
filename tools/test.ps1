param([string]$Godot = '', [switch]$Visual)
& (Join-Path $PSScriptRoot 'verify.ps1') -Godot $Godot -SkipVisual:(-not $Visual)
exit $LASTEXITCODE
