# Aplica exclusivamente la actualización incremental al principal configurado.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Security
Add-Type -AssemblyName System.Data
$project = Split-Path -Parent $PSScriptRoot
$config = Join-Path $project 'LavaFacil.Web\Data\connection.dpapi'
$scriptPath = Join-Path $PSScriptRoot '04_Mejoras_Aplicativo.sql'
if (-not (Test-Path -LiteralPath $config)) { throw 'Falta la conexión cifrada de esta instalación. Configurá el aplicativo primero.' }
if (-not (Test-Path -LiteralPath $scriptPath)) { throw 'No se encontró 04_Mejoras_Aplicativo.sql junto al activador.' }
$bytes = [Security.Cryptography.ProtectedData]::Unprotect([IO.File]::ReadAllBytes($config),$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)
$saved = [Text.Encoding]::UTF8.GetString($bytes).Replace('Trust Server Certificate','TrustServerCertificate').Replace('Encrypt=Mandatory','Encrypt=True')
$options = New-Object System.Data.SqlClient.SqlConnectionStringBuilder $saved
$options['Connect Timeout'] = 12
$connection = New-Object System.Data.SqlClient.SqlConnection $options.ConnectionString
$tx = $null
try {
    $connection.Open()
    $check = $connection.CreateCommand()
    $check.CommandText = "SELECT @@SERVERNAME AS Servidor,DB_NAME() AS BaseDatos,mirroring_role_desc AS Rol FROM sys.database_mirroring WHERE database_id=DB_ID();"
    $table = New-Object System.Data.DataTable
    $table.Load($check.ExecuteReader())
    if ($table.Rows.Count -ne 1 -or $table.Rows[0].BaseDatos -ne 'LavaFacil' -or
        $table.Rows[0].Servidor -notin @('MADRENZO','LAPTOP-D0TECCJR\LAVAFACIL2022') -or
        $table.Rows[0].Rol -ne 'PRINCIPAL') {
        throw 'No se aplicó nada: la conexión no corresponde a LavaFacil en un principal conocido o faltan permisos para consultar su rol.'
    }
    Write-Output ('Servidor principal confirmado: ' + $table.Rows[0].Servidor)
    $script = [IO.File]::ReadAllText($scriptPath)
    $script = $script -replace '(?im)^USE \[LavaFacil\];',''
    $tx = $connection.BeginTransaction()
    foreach ($batch in [regex]::Split($script,'(?im)^GO\s*\r?$')) {
        if ([string]::IsNullOrWhiteSpace($batch)) { continue }
        $cmd = $connection.CreateCommand()
        $cmd.Transaction = $tx
        $cmd.CommandTimeout = 60
        $cmd.CommandText = $batch
        [void]$cmd.ExecuteNonQuery()
        $cmd.Dispose()
    }
    $tx.Commit()
    $tx = $null
    Write-Output 'Actualización confirmada. Reiniciá Iniciar.cmd y recargá el navegador.'
} catch {
    if ($null -ne $tx) { try { $tx.Rollback() } catch { } }
    throw
} finally { $connection.Dispose() }
