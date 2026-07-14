# ============================================
# Microsoft Graph vorbereiten
# ============================================

$RequiredScopes = @(
    "Policy.ReadWrite.ConditionalAccess",
    "Policy.Read.All",
    "NetworkAccess.ReadWrite.All"
)

$RequiredModules = @(
    "Microsoft.Graph.Authentication",
    "Microsoft.Graph.Identity.SignIns"
)

# Microsoft Graph Module installieren, falls nicht vorhanden
foreach ($Module in $RequiredModules) {

    if (-not (Get-Module $Module -ListAvailable)) {

        Write-Host "Microsoft Graph Modul $Module wird installiert..." -ForegroundColor Yellow

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
            exit
        }
    }

    Import-Module $Module -ErrorAction Stop
}


# Verbindung prüfen
try {
    $Context = Get-MgContext
}
catch {
    $Context = $null
}


if (-not $Context) {

    Write-Host "Verbinde mit Microsoft Graph..." -ForegroundColor Cyan

    Connect-MgGraph `
        -Scopes $RequiredScopes `
        -NoWelcome

    $Context = Get-MgContext


    if (-not $Context) {

        Write-Host "Verbindung zu Microsoft Graph konnte nicht hergestellt werden." -ForegroundColor Red
        exit
    }
}


Write-Host ""
Write-Host "Erfolgreich verbunden!" -ForegroundColor Green
Write-Host "Benutzer : $($Context.Account)"
Write-Host "Tenant  : $($Context.TenantId)"
Write-Host ""

# Microsoft Graph muss bereits verbunden sein:
# Connect-MgGraph -Scopes "Policy.ReadWrite.ConditionalAccess"

# -------------------------------
# Öffentliche IP automatisch abrufen
# -------------------------------
$PublicIP = (Invoke-RestMethod "https://api.ipify.org").Trim()

# Netzgröße abfragen (z.B. 32, 29, 28, 24 ...)
$Prefix = Read-Host "CIDR-Netzgröße eingeben (nur Zahl, z.B. 32, 29 oder 28)"

# CIDR-Adresse zusammensetzen
$TrustedIP = "$PublicIP/$Prefix"

Write-Host "Verwendete IP: $TrustedIP" -ForegroundColor Cyan

# -------------------------------
# Variablen
# -------------------------------
$trustedLocationName = "LocalOffice"
$policyName = "Bypass MFA from Local Network"

# -------------------------------
# Trusted Location erstellen
# -------------------------------
$namedLocation = New-MgIdentityConditionalAccessNamedLocationPolicy `
    -DisplayName $trustedLocationName `
    -Ip `
    -IpRanges @(
        @{
            "@odata.type" = "#microsoft.graph.iPv4CidrRange"
            CidrAddress = $TrustedIP
        }
    ) `
    -IsTrusted $true

Write-Host "Trusted Location erstellt: $($namedLocation.Id)" -ForegroundColor Green

# -------------------------------
# Conditional Access Policy erstellen
# -------------------------------
$policy = New-MgIdentityConditionalAccessPolicy `
    -DisplayName $policyName `
    -State "enabled" `
    -Conditions @{
        Users = @{
            IncludeUsers = @("All")
        }
        Applications = @{
            IncludeApplications = @("All")
        }
        Locations = @{
            IncludeLocations = @("All")
            ExcludeLocations = @($namedLocation.Id)
        }
    } `
    -GrantControls @{
        Operator = "OR"
        BuiltInControls = @("mfa")
    }

Write-Host "Conditional Access Policy erstellt: $($policy.Id)" -ForegroundColor Green
