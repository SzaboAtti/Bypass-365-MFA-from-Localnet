# ============================================================
# Microsoft Entra ID - Trusted Location Creator
#
# Erstellt:
#   - Trusted Named Location
#   - Conditional Access Policy MFA Ausnahme
#
# Microsoft Graph PowerShell SDK v2.x
#
# ============================================================

Clear-Host

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Entra ID Trusted Location Creator" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# Voraussetzungen
# ============================================================

$RequiredModules = @(
    "Microsoft.Graph.Authentication",
    "Microsoft.Graph.Identity.SignIns"
)

$RequiredScopes = @(
    "Policy.ReadWrite.ConditionalAccess"
)

# ============================================================
# Module prüfen / installieren
# ============================================================

foreach ($Module in $RequiredModules) {
    if (-not (Get-Module -ListAvailable -Name $Module)) {
        Write-Host "Installiere Modul: $Module" -ForegroundColor Yellow
        try {
            Install-Module `
                -Name $Module `
                -Scope CurrentUser `
                -Repository PSGallery `
                -Force `
                -AllowClobber
        }
        catch {
            Write-Host "Fehler beim Installieren von $Module" -ForegroundColor Red
            Write-Host $_.Exception.Message
            exit 1
        }
    }
    Import-Module $Module -ErrorAction Stop
}

# ============================================================
# Graph Verbindung
# ============================================================

$Context = Get-MgContext

if (-not $Context) {
    Write-Host "Verbinde mit Microsoft Graph..." -ForegroundColor Cyan
    try {
        Connect-MgGraph `
            -Scopes $RequiredScopes `
            -NoWelcome
    }
    catch {
        Write-Host "Graph Anmeldung fehlgeschlagen." -ForegroundColor Red
        Write-Host $_.Exception.Message
        exit 1
    }
    $Context = Get-MgContext
}

if (-not $Context) {
    Write-Host "Keine Microsoft Graph Verbindung vorhanden." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Erfolgreich verbunden!" -ForegroundColor Green
Write-Host "Benutzer : $($Context.Account)"
Write-Host "Tenant   : $($Context.TenantId)"
Write-Host ""

# ============================================================
# Öffentliche IP ermitteln
# ============================================================

try {
    $PublicIP = Invoke-RestMethod `
        -Uri "https://api.ipify.org" `
        -ErrorAction Stop
}
catch {
    Write-Host "Öffentliche IP konnte nicht ermittelt werden." -ForegroundColor Red
    exit 1
}

Write-Host "Öffentliche IP: $PublicIP" -ForegroundColor Cyan

# ============================================================
# CIDR Größe abfragen
# ============================================================

do {
    $Prefix = Read-Host "CIDR Netzgröße eingeben (z.B. 32, 29, 28, 24)"
}
until ($Prefix -match "^(8|9|1[0-9]|2[0-9]|3[0-2])$")

$CIDR = "$PublicIP/$Prefix"
Write-Host ""
Write-Host "Verwendetes Netzwerk: $CIDR" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# Namen
# ============================================================

$TrustedLocationName = "Trusted Location - $PublicIP"
$PolicyName = "Bypass MFA from Trusted Network"

# ============================================================
# Prüfen ob Location existiert
# ============================================================

Write-Host "Prüfe bestehende Named Locations..." -ForegroundColor Yellow

$ExistingLocation = Get-MgIdentityConditionalAccessNamedLocation -All |
Where-Object {
    $_.DisplayName -eq $TrustedLocationName
}

if ($ExistingLocation) {
    Write-Host ""
    Write-Host "Named Location existiert bereits:" -ForegroundColor Yellow
    Write-Host "ID: $($ExistingLocation.Id)"
    Write-Host "Name: $($ExistingLocation.DisplayName)"
    exit
}

# ============================================================
# Trusted Location erstellen
# ============================================================

Write-Host "Erstelle Trusted Location..." -ForegroundColor Cyan

try {
    # Korrekte Erstellung der Location
    $LocationParams = @{
        DisplayName = $TrustedLocationName
        IsTrusted = $true
        IpRanges = @(
            @{
                "@odata.type" = "#microsoft.graph.iPv4CidrRange"
                CidrAddress = $CIDR
            }
        )
    }
    
    $NamedLocation = New-MgIdentityConditionalAccessNamedLocation `
        -BodyParameter $LocationParams
}
catch {
    Write-Host ""
    Write-Host "Fehler beim Erstellen der Trusted Location" -ForegroundColor Red
    Write-Host $_.Exception.Message
    exit 1
}

# Robustere Prüfung ob die Location erfolgreich erstellt wurde
if (-not $NamedLocation -or -not $NamedLocation.Id) {
    Write-Host "Keine Location-ID erhalten. Erstellung fehlgeschlagen." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Trusted Location erstellt:" -ForegroundColor Green
Write-Host "ID: $($NamedLocation.Id)"
Write-Host "Name: $($NamedLocation.DisplayName)"

# ============================================================
# Conditional Access Policy
# ============================================================

Write-Host ""
Write-Host "Erstelle Conditional Access Policy..." -ForegroundColor Cyan

try {
    # Korrekte Policy-Erstellung mit der Location-ID
    $PolicyParams = @{
        DisplayName = $PolicyName
        State = "enabled"
        Conditions = @{
            Users = @{
                IncludeUsers = @("All")
            }
            Applications = @{
                IncludeApplications = @("All")
            }
            Locations = @{
                IncludeLocations = @("All")
                ExcludeLocations = @($NamedLocation.Id)
            }
        }
        GrantControls = @{
            Operator = "OR"
            BuiltInControls = @("mfa")
        }
    }
    
    $Policy = New-MgIdentityConditionalAccessPolicy `
        -BodyParameter $PolicyParams
}
catch {
    Write-Host ""
    Write-Host "Fehler beim Erstellen der Conditional Access Policy" -ForegroundColor Red
    Write-Host $_.Exception.Message
    
    # Zusätzliche Fehlerinformationen anzeigen
    if ($_.Exception.Response) {
        $response = $_.Exception.Response
        $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd()
        Write-Host "Server-Antwort: $responseBody" -ForegroundColor Red
    }
    exit 1
}

if ($Policy -and $Policy.Id) {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "Fertig!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Named Location:" -ForegroundColor Cyan
    Write-Host "  ID: $($NamedLocation.Id)"
    Write-Host "  Name: $($NamedLocation.DisplayName)"
    Write-Host "  Netzwerk: $CIDR"
    Write-Host ""
    Write-Host "Conditional Access Policy:" -ForegroundColor Cyan
    Write-Host "  ID: $($Policy.Id)"
    Write-Host "  Name: $($Policy.DisplayName)"
    Write-Host "  Status: $($Policy.State)"
    Write-Host "============================================" -ForegroundColor Green
}
else {
    Write-Host "Policy wurde nicht erstellt." -ForegroundColor Red
    exit 1
}
