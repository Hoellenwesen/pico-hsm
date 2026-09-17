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
