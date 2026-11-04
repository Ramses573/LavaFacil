$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent $projectRoot
$evidencePath = Join-Path $projectRoot '05-Capturas\Reales_20261104'
$bcpPath = (Get-Command bcp -ErrorAction Stop).Source
$sqlcmdPath = (Get-Command sqlcmd -ErrorAction Stop).Source

foreach ($item in @(
    @{Table='Usuarios'; File='06_Usuarios.csv'},
    @{Table='Recolecciones'; File='08_Recolecciones.csv'},
    @{Table='DetallePedido'; File='09_DetallePedido.csv'}
)) {
    $table = $item.Table
    $csvPath = Join-Path $projectRoot ('02-Datos-Carga\Ramses-SSMS\' + $item.File)
    $guard = "IF EXISTS (SELECT 1 FROM EvidenciaSSMS20261104.[$table]) THROW 51000, 'La tabla auxiliar ya tiene datos. No se repetira la carga.', 1;"
    & $sqlcmdPath -S '.\SQLEXPRESS' -E -d LavaFacil -C -b -Q $guard
    if ($LASTEXITCODE -ne 0) { throw "La tabla auxiliar $table no está vacía." }
    $stdoutPath = Join-Path $evidencePath ($table + '_BCP_Salida_Real.txt')
    $stderrPath = Join-Path $evidencePath ($table + '_BCP_Error_Real.txt')
    $arguments = @("LavaFacil.EvidenciaSSMS20261104.$table", 'in', $csvPath, '-S', '.\SQLEXPRESS', '-T', '-c', '-C', '65001', '-t', ';', '-r', '0x0a', '-F', '2', '-E', '-k', '-b', '1000', '-m', '1')
    $process = Start-Process -FilePath $bcpPath -ArgumentList $arguments -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -WindowStyle Hidden -Wait -PassThru
    Get-Content -LiteralPath $stdoutPath
    if ($process.ExitCode -ne 0) { throw "BCP falló para $table; revisar su salida real." }
}
