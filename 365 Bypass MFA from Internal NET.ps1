# ============================================================
# Microsoft Entra ID - Trusted Location Creator
# Erstellt:
#   - Trusted Named Location
#   - Conditional Access Policy für MFA-Ausnahme
#
# Voraussetzungen:
#   - Entra ID
#   - Conditional Access Lizenz
#   - Global Administrator oder Conditional Access Administrator
#
# ============================================================


# ============================================================
# Microsoft Graph Module vorbereiten
# ============================================================

$RequiredModules = @(
    "Microsoft.Graph.Authentication",
    "Microsoft.Graph.Identity.SignIns"
)

$RequiredScopes = @(
    "Policy.ReadWrite.ConditionalAccess",
    "NetworkAccess.ReadWrite.All"
)


Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Entra ID Trusted Location Creator" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""


foreach ($Module in $RequiredModules) {

    if (-not (Get-Module -ListAvailable -Name $Module)) {

        Write-Host "Installiere Microsoft Graph Modul: $Module" -ForegroundColor Yellow

        try {

            Install-Module `
                -Name $Module `
                -Scope CurrentUser `
                -Force `
                -AllowClobber `
                -Repository PSGallery

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
# Microsoft Graph Verbindung
# ============================================================


$GraphContext = Get-MgContext


if (-not $GraphContext) {

    Write-Host "Verbinde mit Microsoft Graph..." -ForegroundColor Cyan

    try {

        Connect-MgGraph `
            -Scopes $RequiredScopes `
            -NoWelcome

    }
    catch {

        Write-Host "Microsoft Graph Anmeldung fehlgeschlagen." -ForegroundColor Red
        Write-Host $_.Exception.Message
        exit 1
    }


    $GraphContext = Get-MgContext
}


if (-not $GraphContext) {

    Write-Host "Keine Graph-Verbindung vorhanden." -ForegroundColor Red
    exit 1
}


Write-Host ""
Write-Host "Erfolgreich verbunden!" -ForegroundColor Green
Write-Host "Benutzer : $($GraphContext.Account)"
Write-Host "Tenant   : $($GraphContext.TenantId)"
Write-Host ""


# ============================================================
# Öffentliche IP ermitteln
# ============================================================


try {

    $PublicIP = (Invoke-RestMethod `
        -Uri "https://api.ipify.org" `
        -ErrorAction Stop).Trim()

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

    $Prefix = Read-Host `
    "CIDR-Netzgröße eingeben (z.B. 32, 29, 28, 24)"

}
until ($Prefix -match "^(8|9|1[0-9]|2[0-9]|3[0-2])$")


$TrustedIP = "$PublicIP/$Prefix"


Write-Host ""
Write-Host "Verwendetes Netzwerk:"
Write-Host $TrustedIP -ForegroundColor Cyan
Write-Host ""


# ============================================================
# Namen definieren
# ============================================================


$TrustedLocationName = "LocalOffice-$PublicIP"
$PolicyName = "Bypass MFA from Local Network"


# ============================================================
# Prüfen ob Named Location bereits existiert
# ============================================================


Write-Host "Prüfe vorhandene Trusted Locations..." -ForegroundColor Yellow


$ExistingLocation = Get-MgIdentityConditionalAccessNamedLocation |
Where-Object {
    $_.DisplayName -eq $TrustedLocationName
}


if ($ExistingLocation) {

    Write-Host ""
    Write-Host "Trusted Location existiert bereits:" -ForegroundColor Yellow
    Write-Host $ExistingLocation.Id
    exit
}



# ============================================================
# Trusted Named Location erstellen
# ============================================================


Write-Host "Erstelle Trusted Location..." -ForegroundColor Cyan


try {


    $LocationBody = @{

        "@odata.type" = "#microsoft.graph.ipNamedLocation"

        displayName = $TrustedLocationName

        isTrusted = $true

        ipRanges = @(

            @{
                "@odata.type" = "#microsoft.graph.iPv4CidrRange"
                cidrAddress = $TrustedIP
            }

        )

    }



    $NamedLocation = New-MgIdentityConditionalAccessNamedLocation `
        -BodyParameter $LocationBody


}
catch {

    Write-Host ""
    Write-Host "Fehler beim Erstellen der Trusted Location." -ForegroundColor Red
    Write-Host $_.Exception.Message
    exit 1
}



if (-not $NamedLocation.Id) {

    Write-Host "Trusted Location wurde nicht erstellt." -ForegroundColor Red
    exit 1

}


Write-Host ""
Write-Host "Trusted Location erstellt:" -ForegroundColor Green
Write-Host $NamedLocation.Id



# ============================================================
# Conditional Access Policy erstellen
# ============================================================


Write-Host ""
Write-Host "Erstelle Conditional Access Policy..." -ForegroundColor Cyan


try {


$PolicyBody = @{

    displayName = $PolicyName

    state = "enabled"


    conditions = @{

        users = @{

            includeUsers = @(
                "All"
            )

        }


        applications = @{

            includeApplications = @(
                "All"
            )

        }


        locations = @{

            includeLocations = @(
                "All"
            )

            excludeLocations = @(
                $NamedLocation.Id
            )

        }

    }


    grantControls = @{

        operator = "OR"

        builtInControls = @(
            "mfa"
        )

    }

}



$Policy = New-MgIdentityConditionalAccessPolicy `
    -BodyParameter $PolicyBody



}
catch {

    Write-Host ""
    Write-Host "Fehler beim Erstellen der Conditional Access Policy." -ForegroundColor Red
    Write-Host $_.Exception.Message
    exit 1

}



if ($Policy.Id) {

    Write-Host ""
    Write-Host "============================================" -ForegroundColor Green
    Write-Host " Conditional Access Policy erstellt" -ForegroundColor Green
    Write-Host " ID: $($Policy.Id)" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green

}
else {

    Write-Host "Policy konnte nicht erstellt werden." -ForegroundColor Red

}
