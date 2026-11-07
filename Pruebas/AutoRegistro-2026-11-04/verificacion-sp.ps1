# Fase 3 (solo lectura): existe dbo.app_AutoRegistroCliente + sus GRANT. Nunca imprime la contraseña.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Security
Add-Type -AssemblyName System.Data
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$config = Join-Path $root 'LavaFacil.Web\Data\connection.dpapi'
$bytes = [Security.Cryptography.ProtectedData]::Unprotect([IO.File]::ReadAllBytes($config),$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)
$saved = [Text.Encoding]::UTF8.GetString($bytes).Replace('Trust Server Certificate','TrustServerCertificate').Replace('Encrypt=Mandatory','Encrypt=True')
$options = New-Object System.Data.SqlClient.SqlConnectionStringBuilder $saved
$conn = New-Object System.Data.SqlClient.SqlConnection $options.ConnectionString
try {
    $conn.Open()
    $q = {
        param($sql)
        $cmd = $conn.CreateCommand(); $cmd.CommandText = $sql
        $t = New-Object System.Data.DataTable; $t.Load($cmd.ExecuteReader()); return ,$t
    }
    $srv = & $q "SELECT @@SERVERNAME AS S, DB_NAME() AS D;"
    Write-Output ("Servidor=" + $srv.Rows[0].S + " Base=" + $srv.Rows[0].D)
    $sp = & $q "SELECT SCHEMA_NAME(schema_id) AS Esquema, name FROM sys.procedures WHERE name='app_AutoRegistroCliente';"
    Write-Output ("SP app_AutoRegistroCliente: " + $(if ($sp.Rows.Count -gt 0) {'EXISTE (' + $sp.Rows[0].Esquema + '.' + $sp.Rows[0].name + ')'} else {'NO EXISTE'}))
    $gr = & $q "SELECT dp.permission_name, dp.state_desc, USER_NAME(dp.grantee_principal_id) AS Grantee FROM sys.database_permissions dp JOIN sys.objects o ON o.object_id=dp.major_id WHERE o.name='app_AutoRegistroCliente';"
    if ($gr.Rows.Count -eq 0) { Write-Output "GRANTs: 0" }
    else { foreach ($r in $gr.Rows) { Write-Output ("GRANT: " + $r.state_desc + " " + $r.permission_name + " -> " + $r.Grantee) } }
} finally { $conn.Dispose() }
