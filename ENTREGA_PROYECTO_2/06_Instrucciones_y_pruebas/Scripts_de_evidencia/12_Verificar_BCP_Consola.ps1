$Host.UI.RawUI.WindowTitle = 'Verificacion BCP real'
Set-Location $PSScriptRoot
$sql = Join-Path $PSScriptRoot '12_Verificar_BCP_Consola.sql'
Write-Host 'sqlcmd -S .\SQLEXPRESS -E -d LavaFacil -C -b'
Write-Host '       -i 12_Verificar_BCP_Consola.sql'
& 'C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\SQLCMD.EXE' -S '.\SQLEXPRESS' -E -d LavaFacil -C -b -i $sql
if ($LASTEXITCODE -ne 0) { throw 'Fallo la verificacion SQL.' }
