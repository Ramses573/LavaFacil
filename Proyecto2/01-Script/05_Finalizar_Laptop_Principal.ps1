$ErrorActionPreference = 'Stop'

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Ejecute este archivo con PowerShell como administrador.'
}

$ruleName = 'LavaFacil SQL Rachel Tailscale'
$existing = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
if ($existing) {
    Remove-NetFirewallRule -DisplayName $ruleName
}

New-NetFirewallRule `
    -DisplayName $ruleName `
    -Direction Inbound `
    -Action Allow `
    -Protocol TCP `
    -LocalAddress '100.70.40.33' `
    -LocalPort 1433 `
    -RemoteAddress '100.117.134.120' `
    -Profile Any | Out-Null

Restart-Service -Name 'MSSQL$SQLEXPRESS' -Force
Start-Sleep -Seconds 5

Get-Service -Name 'MSSQL$SQLEXPRESS','Tailscale' |
    Select-Object Name, Status, StartType

Write-Host ''
Write-Host 'Servidor para Rachel: 100.70.40.33,1433'
Write-Host 'Base de datos: LavaFacil'
Write-Host 'Configuracion terminada.'
