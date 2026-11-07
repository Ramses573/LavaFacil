# Diagnostico de los 2 FAIL de fase2: compara el bloque del SP dentro de cada copia del script. Solo lectura.
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$files = @('SQL\04_Mejoras_Aplicativo.sql','Proyecto2\01-Script\02_Mejoras_Aplicativo.sql','Proyecto2\01-Script\00_LavaFacil_Proyecto2_ENTREGA_FINAL.sql','ENTREGA_PROYECTO_2\01_Base_de_datos\00_LavaFacil_Proyecto2_ENTREGA_FINAL.sql')
foreach ($f in $files) {
    $t = [IO.File]::ReadAllText((Join-Path $root $f), [Text.Encoding]::UTF8)
    $pat = 'CREATE OR ALTER PROCEDURE dbo\.app_AutoRegistroCliente[\s\S]*?END;\s*GO'
    $blk = [regex]::Match($t, $pat)
    $seg = if ($blk.Success) { $blk.Value } else { '' }
    Write-Output ('FILE=' + $f)
    Write-Output ('  bloqueEncontrado=' + $blk.Success + ' len=' + $seg.Length)
    if ($seg.Length -gt 0) {
        $m1 = [regex]::Matches($seg, "THROW 50101,'([^']*)'")
        $m2 = [regex]::Matches($seg, "THROW 50103,'([^']*)'")
        $m3 = [regex]::Matches($seg, "THROW 50102,'([^']*)'")
        Write-Output ('  en bloque: 50101=' + $m1.Count + ' 50102=' + $m3.Count + ' 50103=' + $m2.Count)
        foreach ($x in $m1) { Write-Output ('    50101: ' + $x.Groups[1].Value) }
        $uniq = @($m2 | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
        Write-Output ('    50103 unicos=' + $uniq.Count + ' -> ' + ($uniq -join ' || '))
    }
    $all = [regex]::Matches($t, "THROW 50103,'([^']*)'")
    $allU = @($all | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
    Write-Output ('  50103 en todo el archivo=' + $all.Count + ' textosUnicos=' + $allU.Count)
    foreach ($u in $allU) { Write-Output ('    txt: ' + $u) }
}
