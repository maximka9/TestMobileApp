# Android verification — SASAclicker 0.2.0

Validation date: 2026-09-07. Workspace: `R:\Python\Sasavot`.

## Installed toolchain

| Tool | Installed version | Local location |
| --- | --- | --- |
| Godot | `4.7.2.stable.official.ed1daf0bf` | `.tools/godot/` |
| OpenJDK | Eclipse Temurin `17.0.20.1+1` | `.tools/jdk/jdk-17.0.20.1+1/` |
| Android command-line tools | `22.0`, archive `15859902` | `.tools/android-sdk/cmdline-tools/latest/` |
| Android platform-tools | `37.0.1-15733141`, adb `1.0.41` | `.tools/android-sdk/platform-tools/` |
| Android build-tools | `36.1.0` | `.tools/android-sdk/build-tools/36.1.0/` |
| Android SDK platform | Android 16, API 36, revision 2 | `.tools/android-sdk/platforms/android-36/` |
| Android export templates | `4.7.2.stable` | `.tools/android-templates/4.7.2.stable/` |

The existing system Java was Oracle JDK 17. A separate OpenJDK 17 installation was downloaded for this project. All new toolchain files remain in the workspace. The non-Gradle APK export uses the official prebuilt Android templates; no NDK or CMake compilation is required for this path.

Downloads came from the [official Godot release](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable), [Android developer tools](https://developer.android.com/studio#command-line-tools-only), and [Eclipse Temurin](https://adoptium.net/temurin/releases/?version=17). The JDK and command-line tools SHA256 checksums and full Godot template archive SHA512 checksum were verified against the publishers' metadata before extraction.

| Archive | Verified digest |
| --- | --- |
| OpenJDK 17, SHA256 | `e53a79c3c3d86865bd7e787903884331068e71321714ffd44f145785affc7cb0` |
| Android command-line tools, SHA256 | `90ae805d20434428bffcb699c290860f19bb5f66a67e6b330067e3de801fb04a` |
| Godot templates, SHA512 | `ca4d71c4d7b81dfc15d1a98baa07534aa95b03fdda78a0075b06672e1648d2e5f40980c9adc28d23e1b92e732ee7bf3461997aa804af74ec2fcd7a93ccb84079` |

## Build and inspect

From the repository root in PowerShell:

```powershell
.\tools\android-build.ps1
```

The script supports `-Godot`, `-JavaSdkPath`, `-AndroidSdkPath`, and `-TemplatePath` for other local installations. Its default paths are listed above. Godot is copied into `.tools/android-export/` in self-contained mode. Android editor settings, templates and the generated debug keystore live inside that folder. Normal desktop Godot settings and desktop save paths are not modified.

The SDK was installed with the official SDK manager, accepting the Android SDK license for the requested packages:

```powershell
$env:JAVA_HOME = "$PWD\.tools\jdk\jdk-17.0.20.1+1"
$env:ANDROID_HOME = "$PWD\.tools\android-sdk"
$env:ANDROID_USER_HOME = "$PWD\.tools\android-user"
& "$env:ANDROID_HOME\cmdline-tools\latest\bin\sdkmanager.bat" `
  --sdk_root=$env:ANDROID_HOME 'platform-tools' 'build-tools;36.1.0' 'platforms;android-36'
```

The final export command used by the script is:

```powershell
& '.\.tools\android-export\Godot_v4.7.2-stable_win64_console.exe' `
  --headless --path . --export-debug Android 'build/android/sasaclicker-debug.apk'
```

Godot 4.7.2 requires `rendering/textures/vram_compression/import_etc2_astc=true` for Android export. This enables the importer capability; the pixel-art textures themselves use lossless import and nearest filtering.

The build script fails on export errors, unexpected package/version, non-portrait manifest orientation or invalid APK signature. It records APK SHA256, manifest, badging, signature verification, export log and `adb devices -l` in ignored `build/checks/v0.2/`.

## APK result

Build and verification **PASS** on 2026-09-07. Artifact: `build/android/sasaclicker-debug.apk` (57,896,797 bytes), package `com.maximka9.sasaclicker`, version name `0.2.0`, version code `2`, portrait orientation. Export, aapt manifest/badging checks and apksigner signature verification succeeded.

SHA256: `e7d1f0987cb939aee1a7f6344b0521ce4d0bbdea3c1b1eca196e46cbf92a709b`.

## Physical device status

`adb devices -l` returned an empty device list on 2026-09-07. No physical Android device or emulator was available through adb. No on-device installation, launch, touch, safe-area, persistence, background/resume, FPS or finger interaction result is claimed.

| Check | Result |
| --- | --- |
| Physical device available | NO DEVICE |
| Launch and crash-free runtime | NOT RUN on Android |
| Portrait rotation behavior | NOT RUN on Android; manifest checked by build script |
| One gameplay click per touch | NOT RUN on Android; automated input tests are separate |
| Safe area, scaling and modal finger targets | NOT RUN on Android; desktop visual checks are separate |
| Save after app restart | NOT RUN on Android |
| Background/resume | NOT RUN on Android |
| FPS near 60 and frame time | NOT MEASURED on Android |

When a physical device is connected with USB debugging authorized, run:

```powershell
$adb = '.\.tools\android-sdk\platform-tools\adb.exe'
& $adb devices -l
& $adb -s DEVICE_SERIAL install -r '.\build\android\sasaclicker-debug.apk'
& $adb -s DEVICE_SERIAL shell am start -n 'com.maximka9.sasaclicker/com.godot.game.GodotApp'
```

On the device, verify portrait rotation, the visible room without large black bands, all primary buttons and modal targets, one click per tap, and unobscured controls around display cutouts/navigation gestures. Start a stream, make clicks, send the app to the background and resume; record the state, then force-stop and relaunch without clearing app data. Check the debug FPS display and app-specific logcat for crashes. Record device model, Android version, display size/cutout, observed FPS and actual outcomes here. Desktop or simulated input results must not be recorded as physical Android results.

## Artifact policy

`.tools/`, `build/`, export credentials and `*.keystore` remain ignored by Git. SDK archives, installed tools, debug keys, APKs and local evidence are not committed. The shared files are the export preset, build script and this verification record.

Configuration references: [Godot Android export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html), [Android SDK manager](https://developer.android.com/tools/sdkmanager), [Android APK signing tool](https://developer.android.com/tools/apksigner).
