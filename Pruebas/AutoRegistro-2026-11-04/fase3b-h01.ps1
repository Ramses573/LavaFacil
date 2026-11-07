# Fase 3b - Prueba RUNTIME del guard H-01 (50102) en una BD TEMPORAL.
# Crea LavaFacil_H01_TMP, instala ahi el SP leido de LavaFacil, prueba y la ELIMINA.
# LavaFacil NO se modifica: solo se leen OBJECT_DEFINITION y los conteos base/final.
# Fuente ASCII puro. No imprime contrasenas.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Security
Add-Type -AssemblyName System.Data
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$bytes = [Security.Cryptography.ProtectedData]::Unprotect([IO.File]::ReadAllBytes((Join-Path $root 'LavaFacil.Web\Data\connection.dpapi')),$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)
$saved = [Text.Encoding]::UTF8.GetString($bytes).Replace('Trust Server Certificate','TrustServerCertificate').Replace('Encrypt=Mandatory','Encrypt=True')
$csb = New-Object System.Data.SqlClient.SqlConnectionStringBuilder $saved
$script:conn = New-Object System.Data.SqlClient.SqlConnection $csb.ConnectionString
$script:results = New-Object System.Collections.Generic.List[object]
function Add-R($id,$estado,$ev) {
    $script:results.Add([pscustomobject]@{ Prueba=$id; Estado=$estado; Evidencia=$ev })
    Write-Output ('RESULT|' + $id + '|' + $estado + '|' + $ev)
}
function Exec([string]$sql) { $c=$script:conn.CreateCommand(); $c.CommandText=$sql; return $c.ExecuteScalar() }
function ExecNone([string]$sql) { $c=$script:conn.CreateCommand(); $c.CommandText=$sql; [void]$c.ExecuteNonQuery() }
function ExecProc([string]$db) {
    $c=$script:conn.CreateCommand(); $c.CommandText = $db + '.dbo.app_AutoRegistroCliente'
    $c.CommandType=[System.Data.CommandType]::StoredProcedure
    foreach ($k in @('@Cedula','@Nombre','@Apellidos','@Telefono','@Email','@Direccion','@NombreUsuario','@Hash')) {
        [void]$c.Parameters.AddWithValue($k, $p[$k])
    }
    try { [void]$c.ExecuteNonQuery(); return [pscustomobject]@{ Num=0; Msg='' } }
    catch [System.Data.SqlClient.SqlException] { return [pscustomobject]@{ Num=$_.Exception.Number; Msg=$_.Exception.Message } }
}
$rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
$s1 = New-Object byte[] 32; $rng.GetBytes($s1); $h1 = New-Object byte[] 32; $rng.GetBytes($h1)
$Hash = 'PBKDF2-SHA256$210000$' + [Convert]::ToBase64String($s1) + '$' + [Convert]::ToBase64String($h1)
$src = [IO.File]::ReadAllText((Join-Path $root 'SQL\04_Mejoras_Aplicativo.sql'), [Text.Encoding]::UTF8)
$srcBlock = [regex]::Match($src, 'CREATE OR ALTER PROCEDURE dbo\.app_AutoRegistroCliente[\s\S]*?END;\s*GO').Value
$Msg102 = [regex]::Match($srcBlock, "THROW 50102,'([^']*)'").Groups[1].Value
$Msg103 = [regex]::Match($srcBlock, "THROW 50103,'([^']*)'").Groups[1].Value
$Tmp = 'LavaFacil_H01_TMP'
$script:conn.Open()
try {
    # --- base de referencia: LavaFacil intacto ---
    $baseU = [int](Exec "SELECT COUNT(*) FROM LavaFacil.dbo.Usuarios;")
    $baseC = [int](Exec "SELECT COUNT(*) FROM LavaFacil.dbo.Clientes;")
    Write-Output ('BASE LavaFacil: Usuarios=' + $baseU + ' Clientes=' + $baseC)
    $def = [string](Exec "SELECT OBJECT_DEFINITION(OBJECT_ID('LavaFacil.dbo.app_AutoRegistroCliente'));")
    if ([string]::IsNullOrEmpty($def)) { throw 'No se pudo leer OBJECT_DEFINITION de LavaFacil' }

    # --- crear BD temporal limpia ---
    ExecNone "IF DB_ID('$Tmp') IS NOT NULL BEGIN ALTER DATABASE [$Tmp] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$Tmp]; END;"
    ExecNone "CREATE DATABASE [$Tmp];"
    Write-Output ('BD temporal creada: ' + $Tmp)
    ExecNone "USE [$Tmp]; SELECT * INTO dbo.Usuarios FROM LavaFacil.dbo.Usuarios WHERE 1=0; SELECT * INTO dbo.Clientes FROM LavaFacil.dbo.Clientes WHERE 1=0;"
    # SELECT INTO no copia defaults; se recrean para que los INSERT del SP funcionen
    ExecNone "USE [$Tmp]; ALTER TABLE dbo.Usuarios ADD CONSTRAINT DF_tmp_FechaCreacion DEFAULT (getdate()) FOR FechaCreacion;"
    ExecNone "USE [$Tmp]; ALTER TABLE dbo.Usuarios ADD CONSTRAINT DF_tmp_UsuActivo DEFAULT (1) FOR Activo;"
    ExecNone "USE [$Tmp]; ALTER TABLE dbo.Clientes ADD CONSTRAINT DF_tmp_FechaRegistro DEFAULT (getdate()) FOR FechaRegistro;"
    ExecNone "USE [$Tmp]; ALTER TABLE dbo.Clientes ADD CONSTRAINT DF_tmp_CliActivo DEFAULT (1) FOR Activo;"
    # instala el SP tal cual esta en LavaFacil
    $c = $script:conn.CreateCommand(); $c.CommandText = $def; [void]$c.ExecuteNonQuery()
    $n = [int](Exec "USE [$Tmp]; SELECT COUNT(*) FROM sys.procedures WHERE name='app_AutoRegistroCliente';")
    Add-R 'H01-A la BD temporal tiene el SP instalado' $(if ($n -eq 1) {'PASS'} else {'FAIL'}) ('procedures=' + $n)

    # --- A1: Usuarios VACIO -> debe saltar 50102 ---
    $p = @{ '@Cedula'='H01-EMPTY-01'; '@Nombre'='Prueba'; '@Apellidos'='H01'; '@Telefono'='099333001'
            '@Email'='h01.empty@example.test'; '@Direccion'=$null; '@NombreUsuario'='h01.empty'; '@Hash'=$Hash }
    $a1 = & (Get-Command ExecProc) $Tmp
    $okA1 = ($a1.Num -eq 50102 -and $a1.Msg -ceq $Msg102)
    Add-R 'H01-BD vacia: registro valido devuelve 50102 (no 50103 ni exito)' $(if ($okA1) {'PASS'} else {'FAIL'}) ('num=' + $a1.Num + ', msgIgual=' + ($a1.Msg -ceq $Msg102))
    $uTmp = [int](Exec "USE [$Tmp]; SELECT COUNT(*) FROM dbo.Usuarios;")
    $cTmp = [int](Exec "USE [$Tmp]; SELECT COUNT(*) FROM dbo.Clientes;")
    Add-R 'H01-BD vacia: no se creo nada (0 filas)' $(if ($uTmp -eq 0 -and $cTmp -eq 0) {'PASS'} else {'FAIL'}) ('Usuarios=' + $uTmp + ', Clientes=' + $cTmp)

    # --- A2: existe un cliente con la MISMA cedula pero Usuarios sigue vacio -> 50102 (prueba el ORDEN) ---
    ExecNone "USE [$Tmp]; INSERT dbo.Clientes(Cedula,Nombre,Apellidos,Telefono,Email) VALUES('H01-DUP-01','Ya','Existe','099333002','h01.dup@example.test');"
    $p = @{ '@Cedula'='H01-DUP-01'; '@Nombre'='Prueba'; '@Apellidos'='H01'; '@Telefono'='099333002'
            '@Email'='h01.dup@example.test'; '@Direccion'=$null; '@NombreUsuario'='h01.dup'; '@Hash'=$Hash }
    $a2 = & (Get-Command ExecProc) $Tmp
    $okA2 = ($a2.Num -eq 50102 -and $a2.Msg -ceq $Msg102)
    Add-R 'H01-orden en runtime: cedula ya existente con Usuarios vacio -> 50102 (el guard va ANTES de duplicados)' $(if ($okA2) {'PASS'} else {'FAIL'}) ('num=' + $a2.Num + ', msgIgual=' + ($a2.Msg -ceq $Msg102))
    $cTmp2 = [int](Exec "USE [$Tmp]; SELECT COUNT(*) FROM dbo.Clientes;")
    Add-R 'H01-orden: tampoco se creo un cliente nuevo (solo el preexistente)' $(if ($cTmp2 -eq 1) {'PASS'} else {'FAIL'}) ('Clientes=' + $cTmp2)

    # --- B: ya hay un usuario (simula administrador) -> el guard NO salta y el registro funciona ---
    ExecNone "USE [$Tmp]; INSERT dbo.Usuarios(NombreUsuario,Clave,ClaveHash,TipoUsuario,IdEmpleado,Activo) VALUES('h01.admin.tmp','x','y','Administrador',NULL,1);"
    $p = @{ '@Cedula'='H01-OK-01'; '@Nombre'='Prueba'; '@Apellidos'='H01'; '@Telefono'='099333003'
            '@Email'='h01.ok@example.test'; '@Direccion'=$null; '@NombreUsuario'='h01.ok'; '@Hash'=$Hash }
    $b1 = & (Get-Command ExecProc) $Tmp
    $okB = ($b1.Num -eq 0)
    Add-R 'H01-con usuario existente: el guard NO salta y el registro termina bien' $(if ($okB) {'PASS'} else {'FAIL'}) ('num=' + $b1.Num + ', msg=' + $b1.Msg.Substring(0,[Math]::Min(80,$b1.Msg.Length)))
    $okIds = $false
    if ($okB) {
        $ids = [int](Exec "USE [$Tmp]; SELECT COUNT(*) FROM dbo.Usuarios WHERE NombreUsuario='h01.ok' AND TipoUsuario='Cliente';")
        $cli = [int](Exec "USE [$Tmp]; SELECT COUNT(*) FROM dbo.Clientes WHERE Cedula='H01-OK-01';")
        $okIds = ($ids -eq 1 -and $cli -eq 1)
    }
    Add-R 'H01-con usuario existente: filas creadas (1 usuario cliente + 1 cliente)' $(if ($okIds) {'PASS'} else {'FAIL'}) ('ok=' + $okIds)

    # --- C: con usuario existente, la cedula duplicada ahora SI da 50103 ---
    $p = @{ '@Cedula'='H01-OK-01'; '@Nombre'='Prueba'; '@Apellidos'='Otra'; '@Telefono'='099333004'
            '@Email'='h01.ok2@example.test'; '@Direccion'=$null; '@NombreUsuario'='h01.ok2'; '@Hash'=$Hash }
    $c1 = & (Get-Command ExecProc) $Tmp
    $okC = ($c1.Num -eq 50103 -and $c1.Msg -ceq $Msg103)
    Add-R 'H01-con usuario existente: cedula duplicada -> 50103 con el mensaje generico' $(if ($okC) {'PASS'} else {'FAIL'}) ('num=' + $c1.Num + ', msgIgual=' + ($c1.Msg -ceq $Msg103))
} finally {
    # --- eliminar BD temporal y confirmar LavaFacil intacto ---
    try {
        if ($script:conn.State -eq 'Open') {
            ExecNone "USE master; IF DB_ID('$Tmp') IS NOT NULL BEGIN ALTER DATABASE [$Tmp] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$Tmp]; END;"
            $still = [int](Exec "SELECT CASE WHEN DB_ID('$Tmp') IS NULL THEN 0 ELSE 1 END;")
            $finU = [int](Exec "SELECT COUNT(*) FROM LavaFacil.dbo.Usuarios;")
            $finC = [int](Exec "SELECT COUNT(*) FROM LavaFacil.dbo.Clientes;")
            Add-R 'H01-limpieza: BD temporal eliminada' $(if ($still -eq 0) {'PASS'} else {'FAIL'}) ('existe=' + $still)
            Add-R 'H01-limpieza: LavaFacil intacto (mismos conteos que al inicio)' $(if ($finU -eq $baseU -and $finC -eq $baseC) {'PASS'} else {'FAIL'}) ('base Usuarios=' + $baseU + ' Clientes=' + $baseC + ' -> final Usuarios=' + $finU + ' Clientes=' + $finC)
        }
    } catch { Add-R 'H01-limpieza: BD temporal eliminada' 'FAIL' ('error=' + $_.Exception.Message) }
    $script:conn.Close()
}
$fail = @($script:results | Where-Object { $_.Estado -ne 'PASS' }).Count
Write-Output ('RESUMEN-FASE3B: total=' + $script:results.Count + ' pass=' + ($script:results.Count - $fail) + ' fail=' + $fail)
$script:results | ConvertTo-Json -Depth 3 | Out-File -FilePath (Join-Path $PSScriptRoot 'fase3b-h01.json') -Encoding UTF8
