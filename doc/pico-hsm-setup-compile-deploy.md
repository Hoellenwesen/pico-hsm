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

## 4. Build unter Windows 11 (nativ, VS Code Extension)

### 4.1 Voraussetzungen

1. [Visual Studio Code](https://code.visualstudio.com/) installieren.
2. [Git for Windows](https://git-scm.com/download/win) installieren.
3. In VS Code: Extensions → **„Raspberry Pi Pico"** (offizielle Extension der Raspberry Pi Foundation) installieren.
   → installiert beim ersten Start automatisch Toolchain (arm-none-eabi-gcc), CMake, Ninja, Python, `picotool` und Pico SDK in `%USERPROFILE%\.pico-sdk` – kein manuelles Toolchain-Setup nötig.

### 4.2 Repo holen

```powershell
git clone https://github.com/Hoellenwesen/pico-hsm.git
cd pico-hsm
git submodule update --init --recursive
```

(Patches aus Abschnitt 1 vorher im Repo committet/gepusht haben, oder lokal anwenden.)

### 4.3 Projekt in der Extension importieren

1. Ordner `pico-hsm` in VS Code öffnen.
2. Command Palette (`Strg+Umschalt+P`) → **„Raspberry Pi Pico: Import Project"**.
3. SDK-Version **2.3.1** wählen (identisch zur Linux-Seite, für reproduzierbare Builds).
4. Board **Pico 2** (RP2350) auswählen.
5. Die Extension legt `.vscode/settings.json` mit den passenden CMake-Variablen an (`PICO_BOARD=pico2` etc.) und konfiguriert CMake automatisch neu.

Eigene VID/PID: in `.vscode/settings.json` unter `cmake.configureArgs` ergänzen:

```json
"cmake.configureArgs": ["-DUSB_VID=0x1234", "-DUSB_PID=0x5678"]
```

### 4.4 Bauen

Über die Statusleiste unten (Pico-Icon) → **„Compile Project"**, oder Command Palette → **„Raspberry Pi Pico: Compile Project"**.
Ergebnis: `build/pico_hsm.uf2`.

---

## 5. Flashen (Linux & Windows identisch)

1. Pico 2 mit gedrückter **BOOTSEL**-Taste per USB anschließen.
2. Gerät erscheint als Massenspeicher `RP2350` (bzw. `RPI-RP2`).
3. `pico_hsm.uf2` auf dieses Laufwerk kopieren.
4. Das Laufwerk trennt sich automatisch, Pico startet neu mit der Firmware.
5. LED blinkt → Firmware läuft.

Unter Windows geht das auch per Extension-Button **„Run Project"** (nutzt intern `picotool`, kein manuelles BOOTSEL nötig, wenn schon eine ältere Pico-HSM-Version läuft).

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

**Windows**: liegt bereits durch die VS-Code-Extension unter `%USERPROFILE%\.pico-sdk\picotool\<version>\picotool.exe` – Pfad zu `PATH` hinzufügen oder direkt aus dem Extension-Terminal aufrufen.

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
