# Diagnostico 2: causas exactas de los FAIL SP-9 y SP-11 (nivel de archivo vs nivel de bloque). Solo lectura.
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$files = @('SQL\04_Mejoras_Aplicativo.sql','Proyecto2\01-Script\02_Mejoras_Aplicativo.sql','Proyecto2\01-Script\00_LavaFacil_Proyecto2_ENTREGA_FINAL.sql','ENTREGA_PROYECTO_2\01_Base_de_datos\00_LavaFacil_Proyecto2_ENTREGA_FINAL.sql')
foreach ($f in $files) {
    $t = [IO.File]::ReadAllText((Join-Path $root $f), [Text.Encoding]::UTF8)
    $c102 = [regex]::Matches($t, "THROW 50102,'([^']*)'").Count
    $c101 = [regex]::Matches($t, "THROW 50101,'([^']*)'").Count
    Write-Output ('FILE=' + $f + ' -> 50102 en TODO el archivo=' + $c102 + ', 50101 en TODO el archivo=' + $c101)
}
# 50101: bloque del SP en el fuente vs definicion real en BD
Add-Type -AssemblyName System.Security
Add-Type -AssemblyName System.Data
$bytes = [Security.Cryptography.ProtectedData]::Unprotect([IO.File]::ReadAllBytes((Join-Path $root 'LavaFacil.Web\Data\connection.dpapi')),$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)
$saved = [Text.Encoding]::UTF8.GetString($bytes).Replace('Trust Server Certificate','TrustServerCertificate').Replace('Encrypt=Mandatory','Encrypt=True')
$csb = New-Object System.Data.SqlClient.SqlConnectionStringBuilder $saved
$conn = New-Object System.Data.SqlClient.SqlConnection $csb.ConnectionString
$conn.Open()
try {
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = "SELECT OBJECT_DEFINITION(OBJECT_ID('dbo.app_AutoRegistroCliente'));"
    $def = [string]$cmd.ExecuteScalar()
    $src = [IO.File]::ReadAllText((Join-Path $root 'SQL\04_Mejoras_Aplicativo.sql'), [Text.Encoding]::UTF8)
    $seg = [regex]::Match($src, 'CREATE OR ALTER PROCEDURE dbo\.app_AutoRegistroCliente[\s\S]*?END;\s*GO').Value
    $a = @([regex]::Matches($def, "THROW 50101,'([^']*)'") | ForEach-Object { $_.Groups[1].Value })
    $b = @([regex]::Matches($seg, "THROW 50101,'([^']*)'") | ForEach-Object { $_.Groups[1].Value })
    Write-Output ('BD 50101 count=' + $a.Count + ' | FUENTE(bloque) 50101 count=' + $b.Count)
    $same = ($a.Count -eq $b.Count)
    for ($i = 0; $i -lt [Math]::Min($a.Count, $b.Count); $i++) {
        $eq = ($a[$i] -ceq $b[$i])
        if (-not $eq) { $same = $false }
        Write-Output ('  [' + $i + '] coincide=' + $eq + ' lenBD=' + $a[$i].Length + ' lenFuente=' + $b[$i].Length)
        if (-not $eq) {
            Write-Output ('    BD     : ' + $a[$i])
            Write-Output ('    FUENTE : ' + $b[$i])
        }
    }
    Write-Output ('50101 IDENTICOS=' + $same)
} finally { $conn.Dispose() }
