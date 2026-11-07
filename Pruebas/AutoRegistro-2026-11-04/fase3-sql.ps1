# Fase 3 - Pruebas SQL de dbo.app_AutoRegistroCliente (corrida 2).
# Datos de prueba con prefijo AUTOTEST-R2 / autotest.r2 -> se ELIMINAN al final (confirmado).
# Nunca imprime contrasenas ni cadenas de conexion. Fuente ASCII puro (PS 5.1 lee sin BOM como ANSI).
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
function Q([string]$sql) {
    $cmd = $script:conn.CreateCommand(); $cmd.CommandText = $sql
    $t = New-Object System.Data.DataTable; $t.Load($cmd.ExecuteReader()); return ,$t
}
# Devuelve un objeto con Num (numero de THROW) y Msg (texto) o Num=0 si no fallo.
function Exec-SP([hashtable]$p) {
    $cmd = $script:conn.CreateCommand(); $cmd.CommandText = 'dbo.app_AutoRegistroCliente'; $cmd.CommandType = [System.Data.CommandType]::StoredProcedure
    foreach ($k in $p.Keys) { [void]$cmd.Parameters.AddWithValue($k, $p[$k]) }
    try { [void]$cmd.ExecuteNonQuery(); return [pscustomobject]@{ Num=0; Msg='' } }
    catch [System.Data.SqlClient.SqlException] { return [pscustomobject]@{ Num=$_.Exception.Number; Msg=$_.Exception.Message } }
}
$rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
$s1 = New-Object byte[] 32; $rng.GetBytes($s1)
$h1 = New-Object byte[] 32; $rng.GetBytes($h1)
$Hash = 'PBKDF2-SHA256$210000$' + [Convert]::ToBase64String($s1) + '$' + [Convert]::ToBase64String($h1)
$ClavePlana = 'PlanaNoGuardar-R2-!Secreta'
$src = [IO.File]::ReadAllText((Join-Path $root 'SQL\04_Mejoras_Aplicativo.sql'), [Text.Encoding]::UTF8)
$srcBlock = [regex]::Match($src, 'CREATE OR ALTER PROCEDURE dbo\.app_AutoRegistroCliente[\s\S]*?END;\s*GO').Value
$Msg50103Esperado = [regex]::Match($srcBlock, "THROW 50103,'([^']*)'").Groups[1].Value
$Msg50101a = [regex]::Matches($srcBlock, "THROW 50101,'([^']*)'")[0].Groups[1].Value
$Msg50101b = [regex]::Matches($srcBlock, "THROW 50101,'([^']*)'")[1].Groups[1].Value

function Params($cedula,$nombre,$apellidos,$tel,$email,$user,$hash) {
    return @{ '@Cedula'=$cedula; '@Nombre'=$nombre; '@Apellidos'=$apellidos; '@Telefono'=$tel
              '@Email'=$email; '@Direccion'='Av. Prueba R2'; '@NombreUsuario'=$user; '@Hash'=$hash }
}
$script:conn.Open()
try {
    # Limpieza previa
    [void](Q "DELETE dbo.Usuarios WHERE NombreUsuario LIKE 'autotest.r2.%';")
    [void](Q "DELETE dbo.Clientes WHERE Cedula LIKE 'AUTOTEST-R2-%' OR Email LIKE 'autotest.r2.%@example.test';")

    # 3.1 registro valido
    $r = Q ("DECLARE @o TABLE(IdUsuario INT, IdCliente INT); INSERT @o EXEC dbo.app_AutoRegistroCliente @Cedula='AUTOTEST-R2-01',@Nombre='PruebaR2',@Apellidos='Registro R2',@Telefono='099222001',@Email='autotest.r2.1@example.test',@Direccion='Av. Prueba R2',@NombreUsuario='autotest.r2.1',@Hash='" + $Hash + "'; SELECT IdUsuario,IdCliente FROM @o;")
    $IdU = 0; $IdC = 0
    if ($r.Rows.Count -eq 1) { $IdU = [int]$r.Rows[0].IdUsuario; $IdC = [int]$r.Rows[0].IdCliente }
    if ($IdU -gt 0 -and $IdC -gt 0) { Add-R 'SQL-3.1 registro valido -> IdUsuario/IdCliente' 'PASS' ('IdUsuario=' + $IdU + ', IdCliente=' + $IdC) }
    else { Add-R 'SQL-3.1 registro valido -> IdUsuario/IdCliente' 'FAIL' ('filas=' + $r.Rows.Count); throw '3.1 fallo' }

    # 3.2 forma de fila
    $u = Q ('SELECT TipoUsuario,Activo,Clave,ClaveHash FROM dbo.Usuarios WHERE IdUsuario=' + $IdU + ';')
    $c = Q ('SELECT Activo FROM dbo.Clientes WHERE IdCliente=' + $IdC + ';')
    $ur = $u.Rows[0]
    $guidOk = [regex]::IsMatch([string]$ur.Clave, '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
    $hashOk = ([string]$ur.ClaveHash -eq $Hash)
    $tipoOk = ([string]$ur.TipoUsuario -eq 'Cliente' -and [int]$ur.Activo -eq 1 -and [int]$c.Rows[0].Activo -eq 1)
    $fugas = @()
    foreach ($v in @($ur.Clave,$ur.ClaveHash,$ur.TipoUsuario)) { if ($null -ne $v -and ([string]$v).Contains($ClavePlana)) { $fugas += $v } }
    Add-R 'SQL-3.2 TipoUsuario=Cliente y Activo=1' $(if ($tipoOk) {'PASS'} else {'FAIL'}) ('TipoUsuario=' + $ur.TipoUsuario + ', ActivoU=' + $ur.Activo + ', ActivoC=' + $c.Rows[0].Activo)
    Add-R 'SQL-3.2 ClaveHash = hash enviado (PBKDF2-SHA256$210000$...), Clave GUID distinta' $(if ($hashOk -and $guidOk -and $fugas.Count -eq 0) {'PASS'} else {'FAIL'}) ('hashOk=' + $hashOk + ', guidOk=' + $guidOk + ', fugas=' + $fugas.Count)

    # 3.3 duplicados -> 50103 con MISMO mensaje (byte a byte)
    $msgs = @{}
    $e1 = Exec-SP (Params 'AUTOTEST-R2-01' 'Otro' 'Cedula Dup' '099222002' 'autotest.r2.1b@example.test' 'autotest.r2.1b' $Hash)
    $msgs['cedula'] = $e1.Msg
    Add-R 'SQL-3.3 cedula duplicada -> 50103' $(if ($e1.Num -eq 50103) {'PASS'} else {'FAIL'}) ('num=' + $e1.Num)
    $e2 = Exec-SP (Params 'AUTOTEST-R2-02' 'Otro' 'Correo Dup' '099222003' 'autotest.r2.1@example.test' 'autotest.r2.2' $Hash)
    $msgs['correo'] = $e2.Msg
    Add-R 'SQL-3.3 correo duplicado -> 50103' $(if ($e2.Num -eq 50103) {'PASS'} else {'FAIL'}) ('num=' + $e2.Num)
    $e3 = Exec-SP (Params 'AUTOTEST-R2-03' 'Otro' 'Usuario Dup' '099222004' 'autotest.r2.3@example.test' 'autotest.r2.1' $Hash)
    $msgs['usuarioActivo'] = $e3.Msg
    Add-R 'SQL-3.3 usuario duplicado (activo) -> 50103' $(if ($e3.Num -eq 50103) {'PASS'} else {'FAIL'}) ('num=' + $e3.Num)
    # usuario desactivado: se desactiva la cuenta creada en 3.1 y se reintenta con datos nuevos
    [void](Q "UPDATE dbo.Usuarios SET Activo=0 WHERE IdUsuario=$IdU;")
    $e4 = Exec-SP (Params 'AUTOTEST-R2-04' 'Otro' 'Usuario Inactivo' '099222005' 'autotest.r2.4@example.test' 'autotest.r2.1' $Hash)
    $msgs['usuarioInactivo'] = $e4.Msg
    Add-R 'SQL-3.3 usuario desactivado -> 50103' $(if ($e4.Num -eq 50103) {'PASS'} else {'FAIL'}) ('num=' + $e4.Num)

    $claves = @($msgs.Keys)
    $iguales = $true; $detalle = @()
    foreach ($k in $claves) {
        $ok = ($msgs[$k] -ceq $Msg50103Esperado)
        if (-not $ok) { $iguales = $false }
        $detalle += ($k + '=' + $(if ($ok) {'IGUAL'} else {'DIFIERE'}))
    }
    Add-R 'SQL-3.4 los 4 mensajes 50103 son IDENTICOS byte a byte entre si y con el del script' $(if ($iguales -and $claves.Count -eq 4) {'PASS'} else {'FAIL'}) (($detalle -join ', ') + ' | longitud=' + $Msg50103Esperado.Length)

    # 3.5 50101 intactos
    $n1 = Exec-SP (Params 'AUTOTEST-R2-05' '   ' 'Vacio' '099222006' 'autotest.r2.5@example.test' 'autotest.r2.5' $Hash)
    $n2 = Exec-SP (Params 'AUTOTEST-R2-06' 'Otro' 'Hash Malo' '099222007' 'autotest.r2.6@example.test' 'autotest.r2.6' '1234567890')
    $v1 = ($n1.Num -eq 50101 -and $n1.Msg -ceq $Msg50101a)
    $v2 = ($n2.Num -eq 50101 -and $n2.Msg -ceq $Msg50101b)
    Add-R 'SQL-3.5 obligatorio vacio -> 50101 con el mismo mensaje' $(if ($v1) {'PASS'} else {'FAIL'}) ('num=' + $n1.Num + ', coincide=' + ($n1.Msg -ceq $Msg50101a))
    Add-R 'SQL-3.5 Hash sin prefijo PBKDF2-SHA256 -> 50101 con el mismo mensaje' $(if ($v2) {'PASS'} else {'FAIL'}) ('num=' + $n2.Num + ', coincide=' + ($n2.Msg -ceq $Msg50101b))

    # 3.6 atomicidad: ningun fallo deja filas nuevas
    $orphan = Q "SELECT (SELECT COUNT(*) FROM dbo.Clientes WHERE Cedula IN ('AUTOTEST-R2-02','AUTOTEST-R2-03','AUTOTEST-R2-04','AUTOTEST-R2-05','AUTOTEST-R2-06')) AS C, (SELECT COUNT(*) FROM dbo.Usuarios WHERE NombreUsuario IN ('autotest.r2.1b','autotest.r2.2','autotest.r2.5','autotest.r2.6')) AS U;"
    $orphanOk = ([int]$orphan.Rows[0].C -eq 0 -and [int]$orphan.Rows[0].U -eq 0)
    Add-R 'SQL-3.6 atomicidad: 0 filas nuevas tras los 6 fallos' $(if ($orphanOk) {'PASS'} else {'FAIL'}) ('Clientes=' + $orphan.Rows[0].C + ', Usuarios=' + $orphan.Rows[0].U)
    $cnt = Q "SELECT (SELECT COUNT(*) FROM dbo.Clientes WHERE Cedula='AUTOTEST-R2-01') AS C, (SELECT COUNT(*) FROM dbo.Usuarios WHERE NombreUsuario='autotest.r2.1') AS U;"
    Add-R 'SQL-3.6 una sola fila por el registro valido' $(if ([int]$cnt.Rows[0].C -eq 1 -and [int]$cnt.Rows[0].U -eq 1) {'PASS'} else {'FAIL'}) ('Clientes=' + $cnt.Rows[0].C + ', Usuarios=' + $cnt.Rows[0].U)

    # 3.7 limpieza
    [void](Q "DELETE dbo.Usuarios WHERE NombreUsuario LIKE 'autotest.r2.%';")
    [void](Q "DELETE dbo.Clientes WHERE Cedula LIKE 'AUTOTEST-R2-%' OR Email LIKE 'autotest.r2.%@example.test';")
    $left = Q "SELECT (SELECT COUNT(*) FROM dbo.Usuarios WHERE NombreUsuario LIKE 'autotest.r2.%') AS U, (SELECT COUNT(*) FROM dbo.Clientes WHERE Cedula LIKE 'AUTOTEST-R2-%' OR Email LIKE 'autotest.r2.%@example.test') AS C;"
    $leftOk = ([int]$left.Rows[0].U -eq 0 -and [int]$left.Rows[0].C -eq 0)
    Add-R 'SQL-3.7 limpieza confirmada (0 filas de prueba)' $(if ($leftOk) {'PASS'} else {'FAIL'}) ('Usuarios=' + $left.Rows[0].U + ', Clientes=' + $left.Rows[0].C)
} finally {
    try {
        if ($script:conn.State -eq 'Open') {
            $cmd = $script:conn.CreateCommand()
            $cmd.CommandText = "DELETE dbo.Usuarios WHERE NombreUsuario LIKE 'autotest.r2.%'; DELETE dbo.Clientes WHERE Cedula LIKE 'AUTOTEST-R2-%' OR Email LIKE 'autotest.r2.%@example.test';"
            [void]$cmd.ExecuteNonQuery()
        }
    } catch { Write-Output ('LIMPIEZA-EMERGENCIA-ERROR: ' + $_.Exception.Message) }
    $script:conn.Close()
}
$fail = @($script:results | Where-Object { $_.Estado -ne 'PASS' }).Count
Write-Output ('RESUMEN-FASE3: total=' + $script:results.Count + ' pass=' + ($script:results.Count - $fail) + ' fail=' + $fail)
$script:results | ConvertTo-Json -Depth 3 | Out-File -FilePath (Join-Path $PSScriptRoot 'fase3.json') -Encoding UTF8
