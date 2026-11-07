$ErrorActionPreference='Stop'
$dir=Split-Path -Parent $MyInvocation.MyCommand.Path
$out=Join-Path $dir 'focalizado-directo.txt'
& sqlcmd -S MADRENZO -d LavaFacil -E -C -I -b -W -s '|' -i (Join-Path $dir 'focalizado-directo.sql') 2>&1 | Tee-Object -FilePath $out
if($LASTEXITCODE -ne 0){ throw "sqlcmd exit $LASTEXITCODE" }
$text=Get-Content $out -Raw
if($text -notmatch 'CLEANUP\s*\|PASS'){ throw 'La limpieza no quedó PASS.' }
if($text -match '\|FAIL\|'){ throw 'Se detectó FAIL en prueba focalizada.' }
Write-Output 'PASS: pruebas directas y limpieza'
