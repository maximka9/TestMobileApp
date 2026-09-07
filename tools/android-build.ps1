param(
    [string]$Godot = '',
    [string]$JavaSdkPath = '',
    [string]$AndroidSdkPath = '',
    [string]$TemplatePath = ''
)

$ErrorActionPreference = 'Stop'
$sasaRoot = Split-Path -Parent $PSScriptRoot
if (-not $Godot) {
    $Godot = Join-Path $sasaRoot '.tools\godot\Godot_v4.7.2-stable_win64_console.exe'
}
if (-not $JavaSdkPath) {
    $sasaJdk = Get-ChildItem -LiteralPath (Join-Path $sasaRoot '.tools\jdk') -Directory |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'bin\java.exe') } |
        Sort-Object Name -Descending | Select-Object -First 1
    if ($null -eq $sasaJdk) { throw 'Install OpenJDK 17 under .tools/jdk or pass -JavaSdkPath.' }
    $JavaSdkPath = $sasaJdk.FullName
}
if (-not $AndroidSdkPath) { $AndroidSdkPath = Join-Path $sasaRoot '.tools\android-sdk' }
if (-not $TemplatePath) { $TemplatePath = Join-Path $sasaRoot '.tools\android-templates\4.7.2.stable' }

foreach ($sasaRequired in @($Godot, (Join-Path $JavaSdkPath 'bin\java.exe'),
    (Join-Path $AndroidSdkPath 'platform-tools\adb.exe'),
    (Join-Path $TemplatePath 'android_debug.apk'), (Join-Path $TemplatePath 'android_release.apk'))) {
    if (-not (Test-Path -LiteralPath $sasaRequired)) { throw "Missing Android build prerequisite: $sasaRequired" }
}

$Godot = (Resolve-Path -LiteralPath $Godot).Path
$JavaSdkPath = (Resolve-Path -LiteralPath $JavaSdkPath).Path
$AndroidSdkPath = (Resolve-Path -LiteralPath $AndroidSdkPath).Path
$TemplatePath = (Resolve-Path -LiteralPath $TemplatePath).Path
$sasaGodotVersion = [string](& $Godot --version)
if ($LASTEXITCODE -ne 0 -or $sasaGodotVersion -notmatch '^4\.7\.2\.stable\.') {
    throw "Godot 4.7.2 stable is required; found $sasaGodotVersion"
}

# Use a separate self-contained editor: settings, templates and debug keys stay
# in ignored .tools, without changing the normal editor or its user save path.
$sasaExporter = Join-Path $sasaRoot '.tools\android-export'
$sasaEditorData = Join-Path $sasaExporter 'editor_data'
$sasaInstalledTemplates = Join-Path $sasaEditorData 'export_templates\4.7.2.stable'
$sasaChecks = Join-Path $sasaRoot 'build\checks\v0.2'
$sasaApk = Join-Path $sasaRoot 'build\android\sasaclicker-debug.apk'
New-Item -ItemType Directory -Force -Path $sasaExporter, $sasaInstalledTemplates,
    $sasaChecks, (Split-Path -Parent $sasaApk) | Out-Null

$sasaExecutableName = Split-Path -Leaf $Godot
$sasaSourceExecutables = @($Godot)
if ($sasaExecutableName.EndsWith('_console.exe')) {
    $sasaSourceExecutables += $Godot.Replace('_console.exe', '.exe')
}
foreach ($sasaSource in $sasaSourceExecutables) {
    $sasaDestination = Join-Path $sasaExporter (Split-Path -Leaf $sasaSource)
    if (-not (Test-Path -LiteralPath $sasaDestination) -or
        (Get-Item -LiteralPath $sasaSource).LastWriteTimeUtc -ne (Get-Item -LiteralPath $sasaDestination).LastWriteTimeUtc) {
        Copy-Item -LiteralPath $sasaSource -Destination $sasaDestination -Force
    }
}
[IO.File]::WriteAllText((Join-Path $sasaExporter '_sc_'), '')
foreach ($sasaTemplate in @('android_debug.apk', 'android_release.apk', 'android_source.zip', 'version.txt')) {
    $sasaSource = Join-Path $TemplatePath $sasaTemplate
    $sasaDestination = Join-Path $sasaInstalledTemplates $sasaTemplate
    if ((Test-Path -LiteralPath $sasaSource) -and
        (-not (Test-Path -LiteralPath $sasaDestination) -or
        (Get-Item -LiteralPath $sasaSource).LastWriteTimeUtc -ne (Get-Item -LiteralPath $sasaDestination).LastWriteTimeUtc)) {
        Copy-Item -LiteralPath $sasaSource -Destination $sasaDestination -Force
    }
}
$sasaSettings = @'
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/java_sdk_path="{JAVA_PATH}"
export/android/android_sdk_path="{ANDROID_PATH}"
'@
$sasaSettings = $sasaSettings.Replace('{JAVA_PATH}', $JavaSdkPath.Replace('\', '/')).
    Replace('{ANDROID_PATH}', $AndroidSdkPath.Replace('\', '/'))
[IO.File]::WriteAllText((Join-Path $sasaEditorData 'editor_settings-4.7.tres'), $sasaSettings)

$env:JAVA_HOME = $JavaSdkPath
$env:ANDROID_HOME = $AndroidSdkPath
$env:ANDROID_SDK_ROOT = $AndroidSdkPath
$env:ANDROID_USER_HOME = Join-Path $sasaRoot '.tools\android-user'
$sasaRunner = Join-Path $sasaExporter $sasaExecutableName
$sasaLog = Join-Path $sasaChecks 'android-export.log'
$sasaPreviousPreference = $ErrorActionPreference
try {
    $ErrorActionPreference = 'Continue'
    $sasaOutput = & $sasaRunner --headless --path $sasaRoot --export-debug Android $sasaApk 2>&1
    $sasaExportExit = $LASTEXITCODE
} finally {
    $ErrorActionPreference = $sasaPreviousPreference
}
$sasaOutput | ForEach-Object { [string]$_ } | Set-Content -LiteralPath $sasaLog -Encoding UTF8
if ($sasaExportExit -ne 0 -or ($sasaOutput -match 'SCRIPT ERROR:|ERROR:|Export failed')) {
    Get-Content -LiteralPath $sasaLog -Tail 50
    throw "Android export failed (exit $sasaExportExit). See $sasaLog"
}

$sasaBuildTools = Get-ChildItem -LiteralPath (Join-Path $AndroidSdkPath 'build-tools') -Directory |
    Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'aapt.exe') } |
    Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
if ($null -eq $sasaBuildTools) { throw 'Android build-tools with aapt are required.' }
$sasaAapt = Join-Path $sasaBuildTools.FullName 'aapt.exe'
$sasaBadging = & $sasaAapt dump badging $sasaApk
if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect APK metadata.' }
$sasaBadging | Set-Content -LiteralPath (Join-Path $sasaChecks 'android-apk-badging.txt') -Encoding UTF8
if (-not ($sasaBadging -match "package: name='com.maximka9.sasaclicker' versionCode='2' versionName='0.2.0'")) {
    throw 'Unexpected APK package or version.'
}
$sasaManifest = & $sasaAapt dump xmltree $sasaApk AndroidManifest.xml
if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect APK manifest.' }
$sasaManifest | Set-Content -LiteralPath (Join-Path $sasaChecks 'android-apk-manifest.txt') -Encoding UTF8
if (-not ($sasaManifest -match 'android:screenOrientation.*\(type 0x10\)0x1\s*$')) {
    throw 'APK activity must use portrait orientation (screenOrientation=1).'
}
$sasaSigner = Join-Path $sasaBuildTools.FullName 'lib\apksigner.jar'
$sasaSignature = & (Join-Path $JavaSdkPath 'bin\java.exe') -jar $sasaSigner verify --verbose $sasaApk
if ($LASTEXITCODE -ne 0) { throw 'APK signature verification failed.' }
$sasaSignature | Set-Content -LiteralPath (Join-Path $sasaChecks 'android-apk-signature.txt') -Encoding UTF8
$sasaHash = (Get-FileHash -LiteralPath $sasaApk -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText((Join-Path $sasaChecks 'android-apk-sha256.txt'), "$sasaHash  sasaclicker-debug.apk`n")
$sasaDevices = & (Join-Path $AndroidSdkPath 'platform-tools\adb.exe') devices -l
if ($LASTEXITCODE -ne 0) { throw 'adb device enumeration failed.' }
$sasaDevices | Set-Content -LiteralPath (Join-Path $sasaChecks 'android-adb-devices.txt') -Encoding UTF8
Write-Output "APK: $sasaApk"
Write-Output "Version: 0.2.0 (2); package: com.maximka9.sasaclicker; orientation: portrait"
Write-Output "SHA256: $sasaHash"
Write-Output "Evidence: $sasaChecks"
$sasaDevices
