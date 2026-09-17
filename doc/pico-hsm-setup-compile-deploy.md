# Pico HSM – Setup, Compile & Deploy (Raspberry Pi Pico 2 / RP2350)

Repo: `https://github.com/Hoellenwesen/pico-hsm` (Submodule: `https://github.com/Hoellenwesen/pico-keys-sdk`)

---

## 1. Repo-Vorbereitung (Patches im eigenen Fork)

Zwei Anpassungen vor dem ersten Build, gelten für Linux und Windows gleichermaßen.

### 1.1 `pico-keys-sdk` Submodule auf eigenen Fork umbiegen

`.gitmodules` aktuell zeigt noch auf den Upstream:

```diff
 [submodule "pico-keys-sdk"]
     path = pico-keys-sdk
-    url = https://github.com/polhenarejos/pico-keys-sdk
+    url = https://github.com/Hoellenwesen/pico-keys-sdk
```

Submodule-Pointer danach auf den `main`-Branch des eigenen Forks ziehen:

```bash
git submodule sync
cd pico-keys-sdk
git fetch origin
git checkout main
git pull
cd ..
git add .gitmodules pico-keys-sdk
git commit -m "Submodule auf eigenen pico-keys-sdk Fork umgestellt"
```

### 1.2 USB VID/PID wirklich per `-D` konfigurierbar machen

`CMakeLists.txt` setzt VID/PID aktuell unbedingt hart:

```cmake
set(USB_VID 0x2E8A)
set(USB_PID 0x10FD)
```

Das SDK (`picokeys_sdk_import.cmake`) hat bereits ein `if(NOT DEFINED USB_VID) ... endif()`-Guard – der greift aber nie, weil pico-hsm den Wert vorher schon unbedingt setzt. Ein `-DUSB_VID=...` beim CMake-Aufruf wird dadurch stillschweigend ignoriert (nur die benannten `-DVIDPID=<Profil>`-Presets wie `Yubikey5` funktionieren, weil die den Wert danach nochmal unbedingt überschreiben).

Fix – gleiches Guard-Pattern wie im SDK:

```diff
 cmake_minimum_required(VERSION 3.13)
 
-set(USB_VID 0x2E8A)
-set(USB_PID 0x10FD)
+if(NOT DEFINED USB_VID)
+    set(USB_VID 0x2E8A)
+endif()
+if(NOT DEFINED USB_PID)
+    set(USB_PID 0x10FD)
+endif()
 
 if(ESP_PLATFORM)
```

Ergebnis: Default bleibt `2E8A:10FD` (Raspberry Pis offiziell zugeteilte ID), `-DUSB_VID=0x1234 -DUSB_PID=0x5678` überschreibt es jetzt tatsächlich, `-DVIDPID=Yubikey5` funktioniert unverändert weiter.

```bash
git add CMakeLists.txt
git commit -m "USB_VID/USB_PID per -D überschreibbar machen, Default bleibt 2E8A:10FD"
git push
```

---

## 2. Voraussetzungen

- Raspberry Pi Pico 2 (RP2350), USB-Kabel mit Datenleitung
- Pico SDK **≥ 2.0.0** zwingend für RP2350; aktuell stabil: **2.3.1**
- Board-Kennung im Build: `-DPICO_BOARD=pico2`

---

## 3. Build unter Linux

### 3.1 Pakete

```bash
sudo apt update
sudo apt install -y build-essential cmake git python3 \
    gcc-arm-none-eabi libnewlib-arm-none-eabi \
    libstdc++-arm-none-eabi-newlib ninja-build pkg-config \
    libusb-1.0-0-dev
```

Falls `gcc-arm-none-eabi` in der Distro veraltet ist (< v12), stattdessen den offiziellen Arm-Toolchain nehmen:

```bash
wget https://developer.arm.com/-/media/Files/downloads/gnu/13.3.rel1/binrel/arm-gnu-toolchain-13.3.rel1-x86_64-arm-none-eabi.tar.xz
sudo tar xf arm-gnu-toolchain-13.3.rel1-x86_64-arm-none-eabi.tar.xz -C /opt
echo 'export PATH=/opt/arm-gnu-toolchain-13.3.rel1-x86_64-arm-none-eabi/bin:$PATH' >> ~/.bashrc
source ~/.bashrc
```

### 3.2 Pico SDK holen

```bash
cd ~
git clone -b 2.3.1 https://github.com/raspberrypi/pico-sdk.git
cd pico-sdk
git submodule update --init --recursive
export PICO_SDK_PATH=$(pwd)
echo "export PICO_SDK_PATH=$(pwd)" >> ~/.bashrc
```

### 3.3 pico-hsm holen (mit Patches aus Abschnitt 1)

```bash
cd ~
git clone https://github.com/Hoellenwesen/pico-hsm.git
cd pico-hsm
git submodule update --init --recursive
```

### 3.4 Konfigurieren & Bauen

```bash
mkdir build && cd build
cmake .. -G Ninja -DPICO_BOARD=pico2
ninja
```

Erzeugt `pico_hsm.uf2` im `build`-Verzeichnis.

Eigene VID/PID (funktioniert dank Patch 1.2):

```bash
cmake .. -G Ninja -DPICO_BOARD=pico2 -DUSB_VID=0x1234 -DUSB_PID=0x5678
```

---

## 4. Build unter Windows 11 (nativ, ohne VS Code Extension)

VS Code bleibt die IDE zum Coden (Editor/IntelliSense). Build und Flash laufen über eigene, reproduzierbare CLI-Tools und ein PowerShell-Skript – keine Abhängigkeit von der Pico-VS-Code-Extension.

### 4.1 Benötigte Tools

`pico-sdk` kompiliert bei jedem Konfigurieren zusätzlich ein paar Host-Werkzeuge (`pioasm`, `elf2uf2`, `picotool`), die auf dem PC selbst laufen, nicht auf dem Pico. Dafür reicht der Arm-Cross-Compiler nicht aus – es wird zusätzlich ein **nativer Windows-Compiler** gebraucht. Unter Linux übernimmt das automatisch das mit `build-essential` installierte native `gcc`; unter Windows genügt dafür MSVC aus den **Visual Studio Build Tools** (Workload „Desktop development with C++"), sofern diese Komponente installiert ist.

| Tool | Zweck | winget-ID |
|---|---|---|
| Git for Windows | Repo/Submodule | `Git.Git` |
| CMake | Build-Konfiguration | `Kitware.CMake` |
| Ninja | Build-Ausführung | `Ninja-build.Ninja` |
| Python 3 | von CMake/SDK-Skripten benötigt | `Python.Python.3.12` |
| Arm GNU Toolchain | Cross-Compiler für RP2350 (**zwingend, kein Ersatz**) | `Arm.ArmGnuToolchain` |
| VS Build Tools (C++ Workload) | nativer Host-Compiler für pioasm/elf2uf2/picotool | `Microsoft.VisualStudio.BuildTools` |
| Visual Studio Code | IDE zum Coden | `Microsoft.VisualStudioCode` |

`setup-toolchain.ps1` (einmalig, als normaler Nutzer ausführen – winget ist auf Windows 11 vorinstalliert):

```powershell
#Requires -Version 5.1
<#
    Einmalige Tool-Installation für den nativen pico-hsm Windows-Build.
#>

$ErrorActionPreference = "Stop"

function Install-Winget {
    param([string]$Id, [string[]]$Override)
    Write-Host "==> $Id"
    if ($Override) {
        winget install --id $Id --silent --accept-package-agreements --accept-source-agreements --override ($Override -join " ")
    } else {
        winget install --id $Id --silent --accept-package-agreements --accept-source-agreements
    }
}

Install-Winget "Git.Git"
Install-Winget "Kitware.CMake"
Install-Winget "Ninja-build.Ninja"
Install-Winget "Python.Python.3.12"
Install-Winget "Microsoft.VisualStudioCode"
Install-Winget "Arm.ArmGnuToolchain"

Write-Host "`n==> VS Build Tools: C++ Workload sicherstellen (idempotent, ergaenzt fehlende Komponenten)"
Install-Winget "Microsoft.VisualStudio.BuildTools" -Override @("--quiet", "--wait", "--add", "Microsoft.VisualStudio.Workload.VCTools", "--includeRecommended")

Write-Host "`nFertig. Neues PowerShell-Fenster oeffnen (PATH-Aenderungen greifen erst dann), danach build.ps1 verwenden."
Write-Host "Hinweis: Arm.ArmGnuToolchain ueberschreibt teils die bestehende User-PATH-Variable - `$env:Path danach kurz pruefen."
```

> **Bekannter winget-Bug:** `Arm.ArmGnuToolchain` überschreibt beim Installieren teils die komplette user-scope `PATH`-Variable statt daran anzuhängen ([microsoft/winget-pkgs#123489](https://github.com/microsoft/winget-pkgs/issues/123489)). Nach der Installation `$env:Path` kurz prüfen. `build.ps1` unten verlässt sich deshalb bewusst **nicht** auf permanente PATH-Einträge, sondern setzt die nötigen Compiler-Pfade pro Aufruf selbst.

### 4.2 Repos holen

```powershell
git clone https://github.com/Hoellenwesen/pico-hsm.git
cd pico-hsm
git submodule update --init --recursive

cd ..
git clone -b 2.3.1 https://github.com/raspberrypi/pico-sdk.git
cd pico-sdk
git submodule update --init --recursive
```

(Patches aus Abschnitt 1 vorher im `pico-hsm`-Repo committet/gepusht haben, oder lokal anwenden.)

Layout danach:
```
C:\dev\
├── pico-hsm\
└── pico-sdk\
```

### 4.3 `build.ps1`

Im Root von `pico-hsm` als `build.ps1` ablegen:

```powershell
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
```

Aufruf:

```powershell
cd C:\dev\pico-hsm
.\build.ps1
```

Ergebnis: `build\pico_hsm.uf2`. Eigene VID/PID: `.\build.ps1 -UsbVid 0x1234 -UsbPid 0x5678`. Clean-Rebuild: `.\build.ps1 -Clean`.

### 4.4 VS Code als reines Editor/IntelliSense-Setup

`build.ps1` setzt `-DCMAKE_EXPORT_COMPILE_COMMANDS=ON`, damit die normale **C/C++ Extension** von Microsoft (nicht die Pico-Extension) korrektes IntelliSense bekommt. In `pico-hsm\.vscode\settings.json`:

```json
{
    "C_Cpp.default.compileCommands": "${workspaceFolder}/build/compile_commands.json",
    "cmake.configureOnOpen": false
}
```

`.vscode/` bleibt trotzdem im `.gitignore`, da `compile_commands.json`-Pfade und ggf. weitere Extension-Settings maschinenspezifisch sind.

---

## 5. Flashen (Linux & Windows identisch)

1. Pico 2 mit gedrückter **BOOTSEL**-Taste per USB anschließen.
2. Gerät erscheint als Massenspeicher `RP2350` (bzw. `RPI-RP2`).
3. `pico_hsm.uf2` auf dieses Laufwerk kopieren.
4. Das Laufwerk trennt sich automatisch, Pico startet neu mit der Firmware.
5. LED blinkt → Firmware läuft.

Alternativ per `picotool` (Abschnitt 7.1) ohne manuelles BOOTSEL, wenn bereits eine ältere Pico-HSM-Version läuft: `picotool load -f build\pico_hsm.uf2`.

---

## 6. Funktionstest

Mit installiertem [OpenSC](https://github.com/OpenSC/OpenSC):

```bash
opensc-tool -an
```

Erwartete Ausgabe (Auszug):

```
Using reader with a card: ...
SmartCard-HSM
```

Falls eine eigene VID/PID gebaut wurde, muss die CCID-Treiber-Konfiguration (`Info.plist` bzw. `libccid`) diese VID/PID kennen, sonst wird das Gerät nicht als Smartcard-Reader erkannt.

---

## 7. Optional: RP2350 Secure Boot

> **Warnung – irreversibel:** RP2350 OTP-Speicher kann nur 0→1 geschrieben werden, nie zurück. Ist `SECURE_BOOT_ENABLE` einmal gesetzt, akzeptiert der Chip **dauerhaft nur noch mit dem hinterlegten Key signierte Firmware**. Ein Fehler dabei (z. B. kein gültiger Bootkey gesetzt, PICOBOOT-Interface deaktiviert) kann den Pico 2 permanent unbrauchbar machen ("brick"). Vor dem OTP-Fusing unbedingt mit signierter, aber noch nicht enforced Firmware testen (Schritt 7.5).

### 7.1 `picotool` besorgen

**Linux** (aus Quelle, benötigt `PICO_SDK_PATH` aus Abschnitt 3.2 und `libusb-1.0-0-dev` aus 3.1):

```bash
cd ~
git clone https://github.com/raspberrypi/picotool.git
cd picotool
mkdir build && cd build
cmake .. -DPICOTOOL_FLAT_INSTALL=1
make -j$(nproc)
sudo make install
```

**Windows**: fertige Binaries von `https://github.com/raspberrypi/pico-sdk-tools/releases` laden (enthält `picotool.exe` für Windows x64) – einfachster Weg, kein eigener Build nötig. Alternativ selbst aus Quelle bauen, mit denselben Tools wie in Abschnitt 4.1 (`PICO_SDK_PATH` wie in `build.ps1` setzen, dann `cmake -G Ninja -DPICOTOOL_FLAT_INSTALL=1` + `ninja` im `picotool`-Checkout).

### 7.2 Signierschlüssel erzeugen

RP2350 Secure Boot verwendet ECDSA auf der Kurve `secp256k1`:

```bash
openssl ecparam -name secp256k1 -genkey -noout -out ec_private_key.pem
openssl ec -in ec_private_key.pem -pubout -out ec_public_key.pem
```

`ec_private_key.pem` wie ein Root-Signaturschlüssel behandeln – wer ihn hat, kann Firmware für dieses Gerät signieren.

### 7.3 Firmware signieren + OTP-Konfiguration erzeugen

```bash
cd build
picotool seal --verbose --sign --major 1 --minor 0 \
    pico_hsm.uf2 pico_hsm_signed.uf2 \
    ../../ec_private_key.pem otp_config.json
```

Erzeugt:
- `pico_hsm_signed.uf2` – signierte (und gehashte) Firmware
- `otp_config.json` – enthält Bootkey-Slot 0 sowie `secure_boot_enable: 1`

Alternativ kann das Signieren auch direkt beim CMake-Build erfolgen (`-DSECURE_BOOT_PKEY=/pfad/zu/ec_private_key.pem`, so wie es `build_pico_hsm.sh` im Repo tut) – das erzeugt aber **kein** `otp_config.json`. Für das OTP-Fusing in Schritt 7.4 wird trotzdem `picotool seal` benötigt.

### 7.4 Vor dem Fusing testen

`pico_hsm_signed.uf2` ganz normal flashen (Abschnitt 5). Solange Secure Boot am Chip noch nicht aktiviert ist, läuft signierte wie unsignierte Firmware gleichermaßen – so lässt sich die signierte Version funktional prüfen, **bevor** der Punkt ohne Rückweg kommt.

### 7.5 OTP dauerhaft programmieren (Punkt ohne Rückweg)

```bash
picotool otp load otp_config.json
```

Das schreibt den Bootkey-Hash **und** setzt `SECURE_BOOT_ENABLE` – ab diesem Zeitpunkt bootet der Chip nur noch Images, die mit `ec_private_key.pem` signiert sind.

### 7.6 Verifikation

```bash
picotool info -d
```

Erwartete Ausgabe (Auszug):

```
secure boot:          1
```
