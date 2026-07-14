[README.md](https://github.com/user-attachments/files/29995684/README.md)
# Entra ID Conditional Access – Trusted Location Creator

## Übersicht

Dieses PowerShell-Skript automatisiert die Erstellung einer **vertrauenswürdigen Named Location (Trusted Location)** sowie einer **Conditional Access-Richtlinie** in Microsoft Entra ID.

Das Skript richtet sich an Administratoren, die eine MFA-Ausnahme für einen vertrauenswürdigen Internetanschluss schnell und reproduzierbar einrichten möchten.

## Funktionen

- Automatische Installation des Microsoft Graph PowerShell SDK (falls nicht vorhanden)
- Automatische Verbindung mit Microsoft Graph
- Anmeldung mit einem Microsoft-365-Administratorkonto
- Ermittlung der aktuellen öffentlichen IPv4-Adresse
- Abfrage der gewünschten CIDR-Netzgröße (z. B. /29 oder /28)
- Erstellung einer Trusted Named Location
- Erstellung einer Conditional Access-Richtlinie
- Markierung der Named Location als vertrauenswürdig
- Vollständig automatisierter Ablauf mit minimalem Benutzereingriff

## Voraussetzungen

- Windows PowerShell 5.1 oder PowerShell 7+
- Internetverbindung
- Microsoft Entra ID
- Rolle **Globaler Administrator** oder **Conditional Access Administrator**
- Berechtigung zur Installation von PowerShell-Modulen (beim ersten Start)

## Ablauf

1. Prüft, ob das Microsoft Graph PowerShell SDK installiert ist.
2. Installiert das SDK bei Bedarf automatisch.
3. Stellt eine Verbindung zu Microsoft Graph her.
4. Ermittelt die aktuelle öffentliche IPv4-Adresse.
5. Fragt die gewünschte CIDR-Netzgröße ab.
6. Erstellt eine vertrauenswürdige Named Location.
7. Erstellt und aktiviert die Conditional Access-Richtlinie.

## Hinweis

Vor dem produktiven Einsatz sollten Conditional Access-Richtlinien immer zunächst mit einer Testgruppe oder in einem Test-Tenant geprüft werden. Fehlerhafte Richtlinien können Administratoranmeldungen verhindern.


## Ausführung

Das Skript kann direkt über PowerShell aus dem GitHub-Repository geladen und ausgeführt werden.

PowerShell als Administrator öffnen und ausführen:

```powershell
irm https://raw.githubusercontent.com/SzaboAtti/Bypass-365-MFA-from-Localnet/main/Bypass-365-MFA-from-Localnet.ps1 | iex
