param([ValidateSet('Usuarios','Recolecciones','DetallePedido')][string]$Tabla = 'Usuarios', [ValidatePattern('^[A-Za-z0-9_]+$')][string]$Esquema = 'EvidenciaConsolaFinal')
$ErrorActionPreference = 'Stop'
$Host.UI.RawUI.WindowTitle = "BCP real - $Tabla"
$files = @{Usuarios='06_Usuarios.csv'; Recolecciones='08_Recolecciones.csv'; DetallePedido='09_DetallePedido.csv'}
$projectRoot = Split-Path -Parent $PSScriptRoot
$csvRoot = Join-Path $projectRoot '02-Datos-Carga\Ramses-SSMS'
if (-not (Test-Path -LiteralPath $csvRoot)) {
    $csvRoot = Join-Path (Split-Path -Parent $projectRoot) '04_Archivos_originales_de_carga\Ramses-SSMS'
}
Set-Location $csvRoot
$bcp = 'C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\bcp.exe'
$sqlcmd = 'C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\SQLCMD.EXE'
& $sqlcmd -S '.\SQLEXPRESS' -E -d LavaFacil -C -b -Q "IF EXISTS (SELECT 1 FROM [$Esquema].[$Tabla]) THROW 51000, 'La tabla auxiliar ya tiene datos.', 1;"
if ($LASTEXITCODE -ne 0) { throw 'Carga cancelada: tabla no vacia.' }
$file = $files[$Tabla]
Write-Host "Servidor: .\SQLEXPRESS   Base: LavaFacil   Tabla auxiliar: $Esquema.$Tabla"
Write-Host "Comando ejecutado (dividido en dos lineas para lectura):"
Write-Host "bcp LavaFacil.$Esquema.$Tabla in $file"
Write-Host "    -S .\SQLEXPRESS -T -c -C 65001 -t ';' -r 0x0a -F 2 -E -k"
& $bcp "LavaFacil.$Esquema.$Tabla" in $file -S '.\SQLEXPRESS' -T -c -C 65001 -t ';' -r 0x0a -F 2 -E -k
if ($LASTEXITCODE -ne 0) { throw 'BCP fallo.' }
Write-Host 'Verificacion SQL del numero de registros:'
& $sqlcmd -S '.\SQLEXPRESS' -E -d LavaFacil -C -b -Q "SET NOCOUNT ON; SELECT COUNT(*) AS Filas FROM [$Esquema].[$Tabla];"
