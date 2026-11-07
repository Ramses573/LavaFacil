# Permisos para probar H-01 en una BD temporal. Solo lectura. Fuente ASCII puro.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Security
Add-Type -AssemblyName System.Data
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$bytes = [Security.Cryptography.ProtectedData]::Unprotect([IO.File]::ReadAllBytes((Join-Path $root 'LavaFacil.Web\Data\connection.dpapi')),$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)
$saved = [Text.Encoding]::UTF8.GetString($bytes).Replace('Trust Server Certificate','TrustServerCertificate').Replace('Encrypt=Mandatory','Encrypt=True')
$csb = New-Object System.Data.SqlClient.SqlConnectionStringBuilder $saved
Write-Output ('InitialCatalog=' + $csb.InitialCatalog + ' (esperado LavaFacil)')
$conn = New-Object System.Data.SqlClient.SqlConnection $csb.ConnectionString
$conn.Open()
try {
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = "SELECT SYSTEM_USER, IS_SRVROLEMEMBER('sysadmin'), HAS_PERMS_BY_NAME(NULL,NULL,'CREATE DATABASE'), (SELECT COUNT(*) FROM dbo.Usuarios), (SELECT COUNT(*) FROM dbo.Clientes);"
    $r = $cmd.ExecuteReader(); [void]$r.Read()
    Write-Output ('Usuario=' + $r.GetValue(0) + ' sysadmin=' + $r.GetValue(1) + ' CREATE_DATABASE=' + $r.GetValue(2))
    Write-Output ('Usuarios=' + $r.GetValue(3) + ' Clientes=' + $r.GetValue(4))
    $r.Close()
    # bases existentes para no chocar
    $c2 = $conn.CreateCommand(); $c2.CommandText = "SELECT name FROM sys.databases WHERE name LIKE 'LavaFacil%';"
    $t = New-Object System.Data.DataTable; $t.Load($c2.ExecuteReader())
    Write-Output ('Bases LavaFacil*: ' + (($t.Rows | ForEach-Object { $_[0] }) -join ', '))
} finally { $conn.Dispose() }
