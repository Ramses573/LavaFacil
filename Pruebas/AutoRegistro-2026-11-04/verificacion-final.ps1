# Verificacion final (solo lectura): datos de prueba y entorno. Fuente ASCII puro. No imprime la contrasena.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Security
Add-Type -AssemblyName System.Data
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$bytes = [Security.Cryptography.ProtectedData]::Unprotect([IO.File]::ReadAllBytes((Join-Path $root 'LavaFacil.Web\Data\connection.dpapi')),$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)
$saved = [Text.Encoding]::UTF8.GetString($bytes).Replace('Trust Server Certificate','TrustServerCertificate').Replace('Encrypt=Mandatory','Encrypt=True')
$csb = New-Object System.Data.SqlClient.SqlConnectionStringBuilder $saved
$conn = New-Object System.Data.SqlClient.SqlConnection $csb.ConnectionString
try {
    $conn.Open()
    $q = { param($sql) $c=$conn.CreateCommand(); $c.CommandText=$sql; $t=New-Object System.Data.DataTable; $t.Load($c.ExecuteReader()); return ,$t }
    $sp = & $q "SELECT SCHEMA_NAME(schema_id) AS s, name FROM sys.procedures WHERE name='app_AutoRegistroCliente';"
    Write-Output ("SP app_AutoRegistroCliente: " + $(if ($sp.Rows.Count -gt 0) {'EXISTE (' + $sp.Rows[0].s + '.' + $sp.Rows[0].name + ')'} else {'NO EXISTE'}))
    $gr = & $q "SELECT dp.permission_name, dp.state_desc, USER_NAME(dp.grantee_principal_id) AS g FROM sys.database_permissions dp JOIN sys.objects o ON o.object_id=dp.major_id WHERE o.name='app_AutoRegistroCliente';"
    foreach ($r in $gr.Rows) { Write-Output ("GRANT: " + $r.state_desc + " " + $r.permission_name + " -> " + $r.g) }
    if ($gr.Rows.Count -eq 0) { Write-Output "GRANTs: 0" }
    $u = & $q "SELECT COUNT(*) AS C FROM dbo.Usuarios WHERE NombreUsuario IN ('autotest.cliente','autotest.api.1','autotest.sql.1','autotest.sql.1b','autotest.sql.2','autotest.sql.3','autotest.sql.4') OR NombreUsuario LIKE 'autotest.%';"
    Write-Output ("Usuarios de prueba restantes: " + $u.Rows[0].C)
    $c2 = & $q "SELECT COUNT(*) AS C FROM dbo.Clientes WHERE Cedula IN ('AUTOTEST-20261104','AUTOTEST-API-01','AUTOTEST-SQL-01','AUTOTEST-SQL-02','AUTOTEST-SQL-03','AUTOTEST-SQL-04') OR Cedula LIKE 'AUTOTEST-%' OR Email LIKE 'autotest.%@example.test';"
    Write-Output ("Clientes de prueba restantes: " + $c2.Rows[0].C)
} finally { $conn.Dispose() }
Write-Output '--- entorno ---'
$procs = Get-Process | Where-Object { $_.ProcessName -match 'LavaFacil' }
Write-Output ("Procesos LavaFacil: " + $(if ($procs) { ($procs | ForEach-Object { $_.ProcessName + ' ' + $_.Id }) -join ', ' } else { '0' }))
$ns = netstat -ano | Select-String ':5088\s'
Write-Output ("Lineas netstat con :5088: " + $(if ($ns) { $ns.Count } else { 0 }))
