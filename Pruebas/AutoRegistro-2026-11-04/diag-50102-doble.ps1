# Diagnostico 3: en que procedimiento esta cada THROW 50102 de las copias ENTREGA. Solo lectura.
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$files = @('SQL\04_Mejoras_Aplicativo.sql','Proyecto2\01-Script\00_LavaFacil_Proyecto2_ENTREGA_FINAL.sql','ENTREGA_PROYECTO_2\01_Base_de_datos\00_LavaFacil_Proyecto2_ENTREGA_FINAL.sql')
foreach ($f in $files) {
    $t = [IO.File]::ReadAllText((Join-Path $root $f), [Text.Encoding]::UTF8)
    Write-Output ('FILE=' + $f)
    foreach ($m in [regex]::Matches($t, "THROW 50102,'([^']*)'")) {
        $antes = $t.Substring(0, $m.Index)
        $procs = [regex]::Matches($antes, '(CREATE\s+(OR\s+ALTER\s+)?PROC(EDURE)?\s+(dbo\.)?([A-Za-z0-9_]+))')
        $nombre = if ($procs.Count -gt 0) { $procs[$procs.Count - 1].Groups[5].Value } else { '(ninguno)' }
        $linea = ($antes -split "`n").Count
        Write-Output ('  linea~' + $linea + ' procedimiento=' + $nombre + ' mensaje=' + $m.Groups[1].Value)
    }
    # cuenta de definiciones del SP en el archivo
    $defs = [regex]::Matches($t, 'CREATE\s+(OR\s+ALTER\s+)?PROC(EDURE)?\s+(dbo\.)?app_AutoRegistroCliente')
    Write-Output ('  definiciones de app_AutoRegistroCliente en el archivo=' + $defs.Count)
    foreach ($d in $defs) { Write-Output ('    linea~' + (($t.Substring(0, $d.Index) -split "`n").Count)) }
}
