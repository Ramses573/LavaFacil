param(
    [Parameter(Mandatory)]
    [ValidateSet('Clientes','Servicios','Promociones','Pedidos','Pagos')]
    [string]$Tabla
)

$ErrorActionPreference = 'Stop'
$Host.UI.RawUI.WindowTitle = "BCP real Rachel - $Tabla"
$files = @{
    Clientes = '01_Clientes.csv'
    Servicios = '03_Servicios.csv'
    Promociones = '04_Promociones.csv'
    Pedidos = '07_Pedidos.csv'
    Pagos = '10_Pagos.csv'
}
$projectRoot = Split-Path -Parent $PSScriptRoot
$csvRoot = Join-Path $projectRoot '02-Datos-Carga\Rachel-BCP'
Set-Location $csvRoot
$bcp = 'C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\bcp.exe'
$sqlcmd = 'C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\SQLCMD.EXE'
$schema = 'EvidenciaBCPFinal20261117'
$file = $files[$Tabla]

& $sqlcmd -S '.\SQLEXPRESS' -E -d LavaFacil -C -b -Q "IF EXISTS (SELECT 1 FROM [$schema].[$Tabla]) THROW 51000, 'La tabla auxiliar ya contiene datos.', 1;"
if ($LASTEXITCODE -ne 0) { throw 'Carga cancelada: la tabla auxiliar no esta vacia.' }

Write-Host "METODO BCP - TABLA $Tabla"
Write-Host "Archivo: $file"
Write-Host "Comando ejecutado:"
Write-Host "bcp LavaFacil.$schema.$Tabla in $file"
Write-Host "    -S .\SQLEXPRESS -T -c -C 65001 -t ';' -r 0x0a -F 2 -E -k"
Write-Host ''
& $bcp "LavaFacil.$schema.$Tabla" in $file -S '.\SQLEXPRESS' -T -c -C 65001 -t ';' -r 0x0a -F 2 -E -k
if ($LASTEXITCODE -ne 0) { throw 'BCP fallo.' }
Write-Host ''
Write-Host 'Verificacion del numero de filas mediante SQLCMD:'
& $sqlcmd -S '.\SQLEXPRESS' -E -d LavaFacil -C -b -Q "SET NOCOUNT ON; SELECT COUNT(*) AS Filas FROM [$schema].[$Tabla];"
if ($LASTEXITCODE -ne 0) { throw 'Fallo la verificacion.' }

