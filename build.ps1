#Requires -Version 5.1
<#
    Baut die pico-hsm Firmware fuer den Raspberry Pi Pico 2 (RP2350).
    Setzt PICO_SDK_PATH und Compiler-Pfade nur fuer diesen Skript-Lauf.

    Beispiele:
      .\build.ps1
      .\build.ps1 -UsbVid 0x1234 -UsbPid 0x5678
      .\build.ps1 -Clean
#>
param(
    [string]$PicoSdkPath = (Join-Path $PSScriptRoot "..\pico-sdk"),
    [string]$UsbVid,
    [string]$UsbPid,
    [switch]$Clean
)

$ErrorActionPreference = "Stop"

# --- Arm GNU Toolchain (Ziel-Compiler fuer RP2350) ---
$armRoot = "C:\Program Files (x86)\Arm GNU Toolchain arm-none-eabi"
if (-not (Test-Path $armRoot)) { throw "Arm GNU Toolchain nicht gefunden unter '$armRoot' - setup-toolchain.ps1 ausgefuehrt?" }
$armBin = Get-ChildItem $armRoot -Directory |
    Sort-Object Name -Descending |
    Select-Object -First 1 |
    ForEach-Object { Join-Path $_.FullName "bin" }

$env:PATH = "$armBin;$env:PATH"

# --- MSVC (nativer Host-Compiler fuer pioasm/elf2uf2/picotool) aus VS Build Tools laden ---
function Import-VisualStudioEnvironment {
    param([string]$Arch = "x64")
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path $vswhere)) { throw "vswhere.exe nicht gefunden - VS Build Tools installiert?" }
    $vsPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if (-not $vsPath) { throw "VS Build Tools ohne C++ Workload gefunden - setup-toolchain.ps1 erneut ausfuehren (installiert die Workload nach)." }
    $vcvars = Join-Path $vsPath "VC\Auxiliary\Build\vcvarsall.bat"
    $tempFile = [System.IO.Path]::GetTempFileName()
    cmd /c "`"$vcvars`" $Arch && set > `"$tempFile`""
    Get-Content $tempFile | ForEach-Object {
        if ($_ -match "^([^=]+)=(.*)$") {
            [System.Environment]::SetEnvironmentVariable($matches[1], $matches[2])
        }
    }
    Remove-Item $tempFile
}
Import-VisualStudioEnvironment

if (-not (Test-Path $PicoSdkPath)) { throw "pico-sdk nicht gefunden unter '$PicoSdkPath' (Parameter -PicoSdkPath anpassen)" }
$env:PICO_SDK_PATH = (Resolve-Path $PicoSdkPath).Path

Write-Host "PICO_SDK_PATH : $env:PICO_SDK_PATH"
Write-Host "Arm Toolchain : $armBin"
Write-Host "MSVC (Host)   : $(Get-Command cl.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source)"

Push-Location $PSScriptRoot
try {
    git submodule update --init --recursive
    if ($LASTEXITCODE -ne 0) { throw "git submodule update fehlgeschlagen" }

    $buildDir = Join-Path $PSScriptRoot "build"
    if ($Clean -and (Test-Path $buildDir)) {
        Remove-Item $buildDir -Recurse -Force
    }

    $cmakeArgs = @(
        "-S", $PSScriptRoot, "-B", $buildDir,
        "-G", "Ninja",
        "-DPICO_BOARD=pico2",
        "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON"
    )
    if ($UsbVid) { $cmakeArgs += "-DUSB_VID=$UsbVid" }
    if ($UsbPid) { $cmakeArgs += "-DUSB_PID=$UsbPid" }

    cmake @cmakeArgs
    if ($LASTEXITCODE -ne 0) { throw "cmake configure fehlgeschlagen" }

    cmake --build $buildDir
    if ($LASTEXITCODE -ne 0) { throw "Build fehlgeschlagen" }

    $uf2 = Join-Path $buildDir "pico_hsm.uf2"
    if (Test-Path $uf2) {
        Write-Host "`nBuild OK: $uf2"
    } else {
        Write-Warning "Build durchgelaufen, aber pico_hsm.uf2 nicht unter '$uf2' gefunden."
    }
}
finally {
    Pop-Location
}
