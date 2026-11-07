# Diagnóstico (solo lectura): muestra los valores de la precondición de Activar-Mejoras.ps1
# Nunca imprime la contraseña ni la cadena completa.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Security
Add-Type -AssemblyName System.Data
$project = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)   # repo root
if (-not $project) { $project = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }
$config = Join-Path $project 'LavaFacil.Web\Data\connection.dpapi'
$bytes = [Security.Cryptography.ProtectedData]::Unprotect([IO.File]::ReadAllBytes($config),$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)
$saved = [Text.Encoding]::UTF8.GetString($bytes).Replace('Trust Server Certificate','TrustServerCertificate').Replace('Encrypt=Mandatory','Encrypt=True')
$options = New-Object System.Data.SqlClient.SqlConnectionStringBuilder $saved
$csb = New-Object System.Data.SqlClient.SqlConnectionStringBuilder $options.ConnectionString
Write-Output ("DataSource = " + $csb.DataSource)
Write-Output ("InitialCatalog = " + $csb.InitialCatalog)
Write-Output ("UserID = " + $csb.UserID)
Write-Output ("Password presente en cadena: " + (-not [string]::IsNullOrEmpty($csb.Password)))
$csb.Password = ''   # no usar contraseña en la consulta de diagnóstico si no hace falta
$conn = New-Object System.Data.SqlClient.SqlConnection $options.ConnectionString
try {
    $conn.Open()
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = "SELECT @@SERVERNAME AS Servidor, DB_NAME() AS BaseDatos, mirroring_role_desc AS Rol FROM sys.database_mirroring WHERE database_id=DB_ID();"
    $t = New-Object System.Data.DataTable
    $t.Load($cmd.ExecuteReader())
    if ($t.Rows.Count -eq 0) {
        Write-Output "FILA: 0 (sin resultado en sys.database_mirroring para esta base)"
    } else {
        $r = $t.Rows[0]
        Write-Output ("Servidor = [" + $r.Servidor + "]")
        Write-Output ("BaseDatos = [" + $r.BaseDatos + "]")
        Write-Output ("Rol = [" + ($r.Rol -as [string]) + "] (null=" + [string]::IsNullOrEmpty($r.Rol) + ")")
    }
    $cmd2 = $conn.CreateCommand()
    $cmd2.CommandText = "SELECT name FROM sys.procedures WHERE name='app_AutoRegistroCliente';"
    $t2 = New-Object System.Data.DataTable
    $t2.Load($cmd2.ExecuteReader())
    Write-Output ("SP app_AutoRegistroCliente existe: " + ($t2.Rows.Count -gt 0))
} finally { $conn.Dispose() }
