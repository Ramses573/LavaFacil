# Fase 4 - Pruebas SQL de dbo.app_AutoRegistroCliente (3.1-3.5).
# Crea SOLO datos de prueba con prefijo AUTOTEST-SQL / autotest.sql y los ELIMINA al final (confirmado).
# Nunca imprime la contrasena ni la cadena de conexion. Fuente ASCII puro (PS 5.1 lee sin BOM como ANSI).
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Security
Add-Type -AssemblyName System.Data
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$config = Join-Path $root 'LavaFacil.Web\Data\connection.dpapi'
$bytes = [Security.Cryptography.ProtectedData]::Unprotect([IO.File]::ReadAllBytes($config),$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)
$saved = [Text.Encoding]::UTF8.GetString($bytes).Replace('Trust Server Certificate','TrustServerCertificate').Replace('Encrypt=Mandatory','Encrypt=True')
$options = New-Object System.Data.SqlClient.SqlConnectionStringBuilder $saved
$script:conn = New-Object System.Data.SqlClient.SqlConnection $options.ConnectionString
$script:results = New-Object System.Collections.Generic.List[object]
function Add-R($id,$estado,$ev) {
    $script:results.Add([pscustomobject]@{ Prueba=$id; Estado=$estado; Evidencia=$ev })
    Write-Output ('RESULT|' + $id + '|' + $estado + '|' + $ev)
}
function Q([string]$sql) {
    $cmd = $script:conn.CreateCommand(); $cmd.CommandText = $sql
    $t = New-Object System.Data.DataTable; $t.Load($cmd.ExecuteReader()); return ,$t
}
# Ejecuta un SP esperando error de THROW; devuelve el numero de SqlException o 0 si no fallo.
function Exec-SP([string]$proc, [hashtable]$p) {
    $cmd = $script:conn.CreateCommand(); $cmd.CommandText = $proc; $cmd.CommandType = [System.Data.CommandType]::StoredProcedure
    foreach ($k in $p.Keys) { [void]$cmd.Parameters.AddWithValue($k, $p[$k]) }
    try { [void]$cmd.ExecuteNonQuery(); return 0 }
    catch [System.Data.SqlClient.SqlException] { return $_.Exception.Number }
}
# Hash realista con el formato del backend: PBKDF2-SHA256$iter$salt$hash (4 partes).
$rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
$saltB = New-Object byte[] 32; $rng.GetBytes($saltB)
$hashB = New-Object byte[] 32; $rng.GetBytes($hashB)
$Hash = 'PBKDF2-SHA256$210000$' + [Convert]::ToBase64String($saltB) + '$' + [Convert]::ToBase64String($hashB)
$ClavePlana = 'PlanaNoGuardar-2026-!Secreta'   # jamas debe persistirse

$Cedula = 'AUTOTEST-SQL-01'
$NombreUsuario = 'autotest.sql.1'
$Email = 'autotest.sql.1@example.test'

$script:conn.Open()
try {
    $who = Q "SELECT SYSTEM_USER AS U, USER_NAME() AS R, HAS_PERMS_BY_NAME('dbo.Clientes','OBJECT','DELETE') AS DelCli, HAS_PERMS_BY_NAME('dbo.Usuarios','OBJECT','DELETE') AS DelUsu;"
    Write-Output ('Conexion como: ' + $who.Rows[0].U + ' (rol ' + $who.Rows[0].R + ') DELETE Clientes=' + $who.Rows[0].DelCli + ' DELETE Usuarios=' + $who.Rows[0].DelUsu)

    # Limpieza previa por si quedo basura de corridas anteriores
    [void](Q "DELETE dbo.Usuarios WHERE NombreUsuario LIKE 'autotest.sql.%';")
    [void](Q "DELETE dbo.Clientes WHERE Cedula LIKE 'AUTOTEST-SQL-%' OR Email LIKE 'autotest.sql.%@example.test';")

    # 3.1 ejecucion valida
    $sql31 = "DECLARE @o TABLE(IdUsuario INT, IdCliente INT); INSERT @o EXEC dbo.app_AutoRegistroCliente @Cedula='" + $Cedula + "',@Nombre='PruebaAuto',@Apellidos='Registro SQL',@Telefono='099000001',@Email='" + $Email + "',@Direccion='Av. Prueba 123',@NombreUsuario='" + $NombreUsuario + "',@Hash='" + $Hash + "'; SELECT IdUsuario,IdCliente FROM @o;"
    $r = Q $sql31
    $IdUsuario = 0; $IdCliente = 0
    if ($r.Rows.Count -eq 1) { $IdUsuario = [int]$r.Rows[0].IdUsuario; $IdCliente = [int]$r.Rows[0].IdCliente }
    if ($IdUsuario -gt 0 -and $IdCliente -gt 0) {
        Add-R 'SQL-3.1 ejecucion valida devuelve IdUsuario/IdCliente' 'PASS' ('IdUsuario=' + $IdUsuario + ', IdCliente=' + $IdCliente)
    } else {
        Add-R 'SQL-3.1 ejecucion valida devuelve IdUsuario/IdCliente' 'FAIL' ('filas=' + $r.Rows.Count)
        throw '3.1 fallo: sin IdUsuario/IdCliente'
    }

    # 3.2 forma de fila
    $u = Q ('SELECT TipoUsuario,Activo,Clave,ClaveHash FROM dbo.Usuarios WHERE IdUsuario=' + $IdUsuario + ';')
    $c = Q ('SELECT Cedula,Nombre,Apellidos,Telefono,Email,Direccion,Activo FROM dbo.Clientes WHERE IdCliente=' + $IdCliente + ';')
    $ur = $u.Rows[0]; $cr = $c.Rows[0]
    $tipoOk = (([string]$ur.TipoUsuario -eq 'Cliente') -and ([int]$ur.Activo -eq 1) -and ([int]$cr.Activo -eq 1))
    Add-R 'SQL-3.2 TipoUsuario=Cliente y Activo=1 en Usuarios y Clientes' $(if ($tipoOk) {'PASS'} else {'FAIL'}) ('TipoUsuario=' + $ur.TipoUsuario + ', ActivoU=' + $ur.Activo + ', ActivoC=' + $cr.Activo)
    $hashOk = ([string]$ur.ClaveHash -like 'PBKDF2-SHA256$210000$*')
    Add-R 'SQL-3.2 ClaveHash con prefijo PBKDF2-SHA256$210000$' $(if ($hashOk) {'PASS'} else {'FAIL'}) ('inicio=' + ([string]$ur.ClaveHash).Substring(0,[Math]::Min(34,([string]$ur.ClaveHash).Length)))
    $guidOk = [regex]::IsMatch([string]$ur.Clave, '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
    $claveDistinta = (([string]$ur.Clave -ne $ClavePlana) -and ([string]$ur.ClaveHash -ne $ClavePlana) -and ([string]$ur.Clave -ne $Hash))
    Add-R 'SQL-3.2 Clave con forma de GUID (NEWID()) y distinta de la contrasena' $(if ($guidOk -and $claveDistinta) {'PASS'} else {'FAIL'}) ('Clave=' + $ur.Clave + ', distinta=' + $claveDistinta)
    # Sin texto plano: la contrasena en claro no puede aparecer en NINGUNA columna de las dos filas.
    # (El hash PBKDF2 SI debe estar en ClaveHash: eso es lo que se almacena por diseno.)
    $fugas = @()
    foreach ($kv in @(@('Usuarios.Clave',$ur.Clave), @('Usuarios.ClaveHash',$ur.ClaveHash), @('Usuarios.NombreUsuario',$ur.NombreUsuario), @('Usuarios.TipoUsuario',$ur.TipoUsuario), @('Clientes.Cedula',$cr.Cedula), @('Clientes.Nombre',$cr.Nombre), @('Clientes.Apellidos',$cr.Apellidos), @('Clientes.Telefono',$cr.Telefono), @('Clientes.Email',$cr.Email), @('Clientes.Direccion',$cr.Direccion))) {
        if ($null -ne $kv[1] -and ([string]$kv[1]).Contains($ClavePlana)) { $fugas += $kv[0] }
    }
    $hashEnClaveHash = ([string]$ur.ClaveHash -eq $Hash)
    Add-R 'SQL-3.2 sin texto plano de la contrasena en ninguna columna' $(if ($fugas.Count -eq 0) {'PASS'} else {'FAIL'}) ('columnas con fuga: ' + $(if ($fugas.Count) {$fugas -join ','} else {'ninguna'}))
    Add-R 'SQL-3.2 el hash recibido quedo en ClaveHash (no la contrasena)' $(if ($hashEnClaveHash) {'PASS'} else {'FAIL'}) ('ClaveHash==HashEnviado=' + $hashEnClaveHash)

    # 3.3 negativos
    $e1 = Exec-SP 'dbo.app_AutoRegistroCliente' @{ '@Cedula'=$Cedula; '@Nombre'='Otro'; '@Apellidos'='Cedula Dup'; '@Telefono'='099000002'; '@Email'='autotest.sql.1b@example.test'; '@Direccion'=$null; '@NombreUsuario'='autotest.sql.1b'; '@Hash'=$Hash }
    Add-R 'SQL-3.3 cedula repetida devuelve 50103' $(if ($e1 -eq 50103) {'PASS'} else {'FAIL'}) ('numero de error=' + $e1)
    $e2 = Exec-SP 'dbo.app_AutoRegistroCliente' @{ '@Cedula'='AUTOTEST-SQL-02'; '@Nombre'='Otro'; '@Apellidos'='Usuario Dup'; '@Telefono'='099000003'; '@Email'='autotest.sql.2@example.test'; '@Direccion'=$null; '@NombreUsuario'=$NombreUsuario; '@Hash'=$Hash }
    Add-R 'SQL-3.3 usuario repetido devuelve 50103' $(if ($e2 -eq 50103) {'PASS'} else {'FAIL'}) ('numero de error=' + $e2)
    $e3 = Exec-SP 'dbo.app_AutoRegistroCliente' @{ '@Cedula'='AUTOTEST-SQL-03'; '@Nombre'='   '; '@Apellidos'='Vacio'; '@Telefono'='099000004'; '@Email'='autotest.sql.3@example.test'; '@Direccion'=$null; '@NombreUsuario'='autotest.sql.3'; '@Hash'=$Hash }
    Add-R 'SQL-3.3 obligatorio vacio devuelve 50101' $(if ($e3 -eq 50101) {'PASS'} else {'FAIL'}) ('numero de error=' + $e3)
    $e4 = Exec-SP 'dbo.app_AutoRegistroCliente' @{ '@Cedula'='AUTOTEST-SQL-04'; '@Nombre'='Otro'; '@Apellidos'='Hash Malo'; '@Telefono'='099000005'; '@Email'='autotest.sql.4@example.test'; '@Direccion'=$null; '@NombreUsuario'='autotest.sql.4'; '@Hash'='1234567890' }
    Add-R 'SQL-3.3 Hash sin prefijo PBKDF2-SHA256 devuelve 50101' $(if ($e4 -eq 50101) {'PASS'} else {'FAIL'}) ('numero de error=' + $e4)

    # 3.4 atomicidad: ningun fallo deja Clientes/Usuarios huerfanos
    $orphan = Q "SELECT (SELECT COUNT(*) FROM dbo.Clientes WHERE Cedula IN ('AUTOTEST-SQL-02','AUTOTEST-SQL-03','AUTOTEST-SQL-04')) AS ClientesNuevos, (SELECT COUNT(*) FROM dbo.Usuarios WHERE NombreUsuario IN ('autotest.sql.1b','autotest.sql.2','autotest.sql.3','autotest.sql.4')) AS UsuariosNuevos;"
    $orphanOk = (([int]$orphan.Rows[0].ClientesNuevos -eq 0) -and ([int]$orphan.Rows[0].UsuariosNuevos -eq 0))
    Add-R 'SQL-3.4 atomicidad: sin Clientes ni Usuarios huerfanos tras los fallos' $(if ($orphanOk) {'PASS'} else {'FAIL'}) ('ClientesNuevos=' + $orphan.Rows[0].ClientesNuevos + ', UsuariosNuevos=' + $orphan.Rows[0].UsuariosNuevos)
    $cnt = Q "SELECT (SELECT COUNT(*) FROM dbo.Clientes WHERE Cedula='AUTOTEST-SQL-01') AS C, (SELECT COUNT(*) FROM dbo.Usuarios WHERE NombreUsuario='autotest.sql.1') AS U;"
    $cntOk = (([int]$cnt.Rows[0].C -eq 1) -and ([int]$cnt.Rows[0].U -eq 1))
    Add-R 'SQL-3.4 una sola fila por registro valido (sin duplicados)' $(if ($cntOk) {'PASS'} else {'FAIL'}) ('Clientes=' + $cnt.Rows[0].C + ', Usuarios=' + $cnt.Rows[0].U)

    # 3.5 limpieza
    [void](Q "DELETE dbo.Usuarios WHERE NombreUsuario LIKE 'autotest.sql.%';")
    [void](Q "DELETE dbo.Clientes WHERE Cedula LIKE 'AUTOTEST-SQL-%' OR Email LIKE 'autotest.sql.%@example.test';")
    $left = Q "SELECT (SELECT COUNT(*) FROM dbo.Usuarios WHERE NombreUsuario LIKE 'autotest.sql.%') AS U, (SELECT COUNT(*) FROM dbo.Clientes WHERE Cedula LIKE 'AUTOTEST-SQL-%' OR Email LIKE 'autotest.sql.%@example.test') AS C;"
    $leftOk = (([int]$left.Rows[0].U -eq 0) -and ([int]$left.Rows[0].C -eq 0))
    Add-R 'SQL-3.5 limpieza confirmada (0 filas de prueba)' $(if ($leftOk) {'PASS'} else {'FAIL'}) ('Usuarios autotest=' + $left.Rows[0].U + ', Clientes AUTOTEST-SQL=' + $left.Rows[0].C)
} finally {
    try {
        if ($script:conn.State -eq 'Open') {
            $cmd = $script:conn.CreateCommand()
            $cmd.CommandText = "DELETE dbo.Usuarios WHERE NombreUsuario LIKE 'autotest.sql.%'; DELETE dbo.Clientes WHERE Cedula LIKE 'AUTOTEST-SQL-%' OR Email LIKE 'autotest.sql.%@example.test';"
            [void]$cmd.ExecuteNonQuery()
        }
    } catch { Write-Output ('LIMPIEZA-EMERGENCIA-ERROR: ' + $_.Exception.Message) }
    $script:conn.Close()
}
$fail = @($script:results | Where-Object { $_.Estado -ne 'PASS' }).Count
Write-Output ('RESUMEN-FASE4: total=' + $script:results.Count + ' pass=' + ($script:results.Count - $fail) + ' fail=' + $fail)
$script:results | ConvertTo-Json -Depth 3 | Out-File -FilePath (Join-Path $PSScriptRoot 'fase4.json') -Encoding UTF8
