# Fase 2/3a - Verifica la definicion real del SP en BD (OBJECT_DEFINITION) contra el script fuente.
# Solo lectura. No imprime contrasenas ni cadenas de conexion. Fuente ASCII puro.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Security
Add-Type -AssemblyName System.Data
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$bytes = [Security.Cryptography.ProtectedData]::Unprotect([IO.File]::ReadAllBytes((Join-Path $root 'LavaFacil.Web\Data\connection.dpapi')),$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)
$saved = [Text.Encoding]::UTF8.GetString($bytes).Replace('Trust Server Certificate','TrustServerCertificate').Replace('Encrypt=Mandatory','Encrypt=True')
$csb = New-Object System.Data.SqlClient.SqlConnectionStringBuilder $saved
$conn = New-Object System.Data.SqlClient.SqlConnection $csb.ConnectionString
$results = New-Object System.Collections.Generic.List[object]
function Add-R($id,$estado,$ev) {
    $script:results.Add([pscustomobject]@{ Prueba=$id; Estado=$estado; Evidencia=$ev })
    Write-Output ('RESULT|' + $id + '|' + $estado + '|' + $ev)
}
$script:results = $results
$src = [IO.File]::ReadAllText((Join-Path $root 'SQL\04_Mejoras_Aplicativo.sql'), [Text.Encoding]::UTF8)
# Solo el bloque del SP: los archivos contienen otros procedures con THROW 50101/50102 ajenos.
$srcBlock = [regex]::Match($src, 'CREATE OR ALTER PROCEDURE dbo\.app_AutoRegistroCliente[\s\S]*?END;\s*GO').Value
$conn.Open()
try {
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = "SELECT OBJECT_DEFINITION(OBJECT_ID('dbo.app_AutoRegistroCliente')) AS Def, (SELECT COUNT(*) FROM sys.procedures WHERE name='app_AutoRegistroCliente') AS Existe;"
    $r = $cmd.ExecuteReader(); [void]$r.Read()
    $def = $r.GetValue(0); $existe = [int]$r.GetValue(1); $r.Close()
    Add-R 'SP-1 dbo.app_AutoRegistroCliente existe en BD' $(if ($existe -eq 1) {'PASS'} else {'FAIL'}) ('filas=' + $existe)

    # --- guard H-01 (50102) ---
    $msg50102src = [regex]::Match($src, "THROW 50102,'([^']*)'").Groups[1].Value
    $m50102db = [regex]::Matches($def, "THROW 50102,'([^']*)'")
    $guardOk = ($m50102db.Count -eq 1 -and $m50102db[0].Groups[1].Value -eq $msg50102src)
    Add-R 'SP-2 guard 50102 presente con el mismo mensaje que el script fuente' $(if ($guardOk) {'PASS'} else {'FAIL'}) ('ocurrencias=' + $m50102db.Count + ', coincide=' + ($m50102db.Count -gt 0 -and $m50102db[0].Groups[1].Value -eq $msg50102src))

    $tabx = [regex]::Matches($def, 'WITH\(TABLOCKX,HOLDLOCK\)').Count
    Add-R 'SP-3 guard usa TABLOCKX,HOLDLOCK' $(if ($tabx -eq 1) {'PASS'} else {'FAIL'}) ('ocurrencias=' + $tabx)

    # posicion: BEGIN TRANSACTION < guard < primer duplicado
    $iTx = $def.IndexOf('BEGIN TRANSACTION')
    $iGuard = $def.IndexOf('THROW 50102')
    $iDup = $def.IndexOf('WITH(UPDLOCK,HOLDLOCK)')
    $ordenOk = ($iTx -ge 0 -and $iGuard -gt $iTx -and $iDup -gt $iGuard)
    Add-R 'SP-4 orden: BEGIN TRANSACTION -> guard 50102 -> primer duplicado (dentro de la transaccion)' $(if ($ordenOk) {'PASS'} else {'FAIL'}) ('idxTx=' + $iTx + ', idxGuard=' + $iGuard + ', idxPrimerDuplicado=' + $iDup)

    # --- 50103 unico ---
    $msg50103src = [regex]::Match($src, "THROW 50103,'([^']*)'").Groups[1].Value
    $m50103 = [regex]::Matches($def, "THROW 50103,'([^']*)'")
    $todosIguales = $true
    $diffs = @()
    foreach ($m in $m50103) { if ($m.Groups[1].Value -cne $msg50103src) { $todosIguales = $false; $diffs += $m.Groups[1].Value } }
    Add-R 'SP-5 hay 4 THROW 50103 (cedula, correo, usuario activo, usuario desactivado)' $(if ($m50103.Count -eq 4) {'PASS'} else {'FAIL'}) ('ocurrencias=' + $m50103.Count)
    Add-R 'SP-6 los 4 mensajes 50103 son IDENTICOS byte a byte y iguales al del script fuente' $(if ($m50103.Count -eq 4 -and $todosIguales) {'PASS'} else {'FAIL'}) ('iguales=' + $todosIguales + ', diferencias=' + $(if ($diffs.Count) {($diffs -join ' || ')} else {'ninguna'}))
    Add-R 'SP-7 los 4 50103 usan WITH(UPDLOCK,HOLDLOCK)' $(if ([regex]::Matches($def, 'WITH\(UPDLOCK,HOLDLOCK\)').Count -eq 4) {'PASS'} else {'FAIL'}) ('ocurrencias UPDLOCK=' + [regex]::Matches($def, 'WITH\(UPDLOCK,HOLDLOCK\)').Count)

    # mensajes viejos eliminados
    $viejos = @('Ya existe un cliente con esa cédula','Ya existe un cliente con ese correo','Ese nombre de usuario ya está en uso','Ese nombre de usuario pertenece a una cuenta desactivada')
    $restantes = @($viejos | Where-Object { $def.Contains($_) })
    Add-R 'SP-8 mensajes 50103 viejos (que enumeraban el dato) eliminados' $(if ($restantes.Count -eq 0) {'PASS'} else {'FAIL'}) ('restantes=' + $(if ($restantes.Count) {$restantes -join ' | '} else {'ninguno'}))

    # 50101 intactos (comparados dentro del bloque del SP, no en todo el archivo)
    $m50101 = [regex]::Matches($def, "THROW 50101,'([^']*)'")
    $src50101 = [regex]::Matches($srcBlock, "THROW 50101,'([^']*)'")
    $i1 = ($m50101.Count -eq 2 -and $src50101.Count -eq 2 -and $m50101[0].Groups[1].Value -ceq $src50101[0].Groups[1].Value -and $m50101[1].Groups[1].Value -ceq $src50101[1].Groups[1].Value)
    Add-R 'SP-9 los 2 mensajes 50101 siguen identicos al script fuente' $(if ($i1) {'PASS'} else {'FAIL'}) ('ocurrencias BD=' + $m50101.Count + ' fuente=' + $src50101.Count + ', coinciden=' + $i1)

    # GRANT
    $g = $conn.CreateCommand()
    $g.CommandText = "SELECT COUNT(*) FROM sys.database_permissions dp JOIN sys.objects o ON o.object_id=dp.major_id WHERE o.name='app_AutoRegistroCliente' AND dp.permission_name='EXECUTE' AND dp.state_desc='GRANT' AND USER_NAME(dp.grantee_principal_id)='ramses_proyecto';"
    $gc = [int]$g.ExecuteScalar()
    Add-R 'SP-10 GRANT EXECUTE a ramses_proyecto' $(if ($gc -eq 1) {'PASS'} else {'FAIL'}) ('grants=' + $gc)

    # Las 4 replicas del script fuente: se compara SOLO el bloque del SP (los archivos ENTREGA
    # traen ademas un THROW 50102 preexistente y ajeno en app_CrearAdministradorInicial, linea ~924).
    $replicas = @('SQL\04_Mejoras_Aplicativo.sql','Proyecto2\01-Script\02_Mejoras_Aplicativo.sql','Proyecto2\01-Script\00_LavaFacil_Proyecto2_ENTREGA_FINAL.sql','ENTREGA_PROYECTO_2\01_Base_de_datos\00_LavaFacil_Proyecto2_ENTREGA_FINAL.sql')
    $malos = @(); $detalles = @()
    foreach ($rep in $replicas) {
        $txt = [IO.File]::ReadAllText((Join-Path $root $rep), [Text.Encoding]::UTF8)
        $defs = [regex]::Matches($txt, 'CREATE\s+(OR\s+ALTER\s+)?PROC(EDURE)?\s+(dbo\.)?app_AutoRegistroCliente').Count
        $seg = [regex]::Match($txt, 'CREATE OR ALTER PROCEDURE dbo\.app_AutoRegistroCliente[\s\S]*?END;\s*GO').Value
        $c1 = [regex]::Matches($seg, "THROW 50102,'([^']*)'").Count
        $c3 = [regex]::Matches($seg, "THROW 50103,'([^']*)'")
        $c101 = [regex]::Matches($seg, "THROW 50101,'([^']*)'").Count
        $ok = ($defs -eq 1 -and $seg.Length -gt 0 -and $c1 -eq 1 -and $c3.Count -eq 4 -and $c101 -eq 2)
        foreach ($m in $c3) { if ($m.Groups[1].Value -cne $msg50103src) { $ok = $false } }
        foreach ($m in [regex]::Matches($seg, "THROW 50102,'([^']*)'")) { if ($m.Groups[1].Value -cne $msg50102src) { $ok = $false } }
        $detalles += ($rep + ': defs=' + $defs + ' len=' + $seg.Length + ' 50102=' + $c1 + ' 50103=' + $c3.Count + ' 50101=' + $c101)
        if (-not $ok) { $malos += $rep }
    }
    Add-R 'SP-11 las 4 copias del script (SQL/04 + 3 replicas): bloque identico, guard 50102 y 4x50103 unico' $(if ($malos.Count -eq 0) {'PASS'} else {'FAIL'}) ('copias=' + $replicas.Count + ', con diferencias=' + $(if ($malos.Count) {$malos -join ','} else {'ninguna'}) + ' | ' + ($detalles -join ' | '))
} finally { $conn.Dispose() }
$fail = @($script:results | Where-Object { $_.Estado -ne 'PASS' }).Count
Write-Output ('RESUMEN-FASE2: total=' + $script:results.Count + ' pass=' + ($script:results.Count - $fail) + ' fail=' + $fail)
$script:results | ConvertTo-Json -Depth 3 | Out-File -FilePath (Join-Path $PSScriptRoot 'fase2.json') -Encoding UTF8
