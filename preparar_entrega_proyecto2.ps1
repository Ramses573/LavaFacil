$ErrorActionPreference = 'Stop'
$repoRoot = $PSScriptRoot
$projectRoot = Join-Path $repoRoot 'Proyecto2'
$deliveryRoot = Join-Path $repoRoot 'ENTREGA_PROYECTO_2'
$zipPath = Join-Path $repoRoot 'ENTREGA_PROYECTO_2.zip'
if (Test-Path -LiteralPath $deliveryRoot) { throw 'La carpeta de entrega ya existe. No se sobrescribe.' }
if (Test-Path -LiteralPath $zipPath) { throw 'El ZIP de entrega ya existe. No se sobrescribe.' }
foreach ($folder in @('01_Base_de_datos','02_Manual','03_Codigo_APIs','04_Archivos_originales_de_carga','05_Evidencias_reales','06_Instrucciones_y_pruebas')) {
    New-Item -ItemType Directory -Path (Join-Path $deliveryRoot $folder) -Force | Out-Null
}
Copy-Item -LiteralPath (Join-Path $projectRoot '01-Script\00_LavaFacil_Proyecto2_ENTREGA_FINAL.sql') -Destination (Join-Path $deliveryRoot '01_Base_de_datos')
foreach ($name in @('Manual_Proyecto2_LavaFacil_COMPLETO.docx','Manual_Proyecto2_LavaFacil_COMPLETO.pdf')) {
    Copy-Item -LiteralPath (Join-Path $projectRoot ('04-Documentacion\' + $name)) -Destination (Join-Path $deliveryRoot '02_Manual')
}
Copy-Item -LiteralPath (Join-Path $projectRoot '02-Datos-Carga\Rachel-BCP') -Destination (Join-Path $deliveryRoot '04_Archivos_originales_de_carga') -Recurse
Copy-Item -LiteralPath (Join-Path $projectRoot '02-Datos-Carga\Ramses-SSMS') -Destination (Join-Path $deliveryRoot '04_Archivos_originales_de_carga') -Recurse

$sourceCode = Join-Path $projectRoot '03-Backend-GraphQL'
foreach ($file in Get-ChildItem -LiteralPath $sourceCode -File -Recurse) {
    $relative = $file.FullName.Substring($sourceCode.Length + 1)
    if ($relative -match '(^|\\)(bin|obj|keys|\.git|\.vs)(\\|$)') { continue }
    if ($file.Name -eq 'appsettings.Development.json' -or $file.Extension -in @('.user','.suo','.pfx','.key','.dpapi')) { continue }
    $target = Join-Path (Join-Path $deliveryRoot '03_Codigo_APIs') $relative
    New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force | Out-Null
    Copy-Item -LiteralPath $file.FullName -Destination $target
}
foreach ($folder in @('Reales_20261104','GraphQL')) {
    Copy-Item -LiteralPath (Join-Path $projectRoot ('05-Capturas\' + $folder)) -Destination (Join-Path $deliveryRoot '05_Evidencias_reales') -Recurse
}
Copy-Item -LiteralPath (Join-Path $projectRoot '04-Documentacion\Evidencias-Ramses\01_Empleados_3_filas_transferidas.png') -Destination (Join-Path $deliveryRoot '05_Evidencias_reales')
Copy-Item -LiteralPath (Join-Path $projectRoot '04-Documentacion\work_tmp\evidencias_rachel_originales') -Destination (Join-Path $deliveryRoot '05_Evidencias_reales\BCP_Rachel_originales') -Recurse
foreach ($name in @('INSTALACION_GRAPHQL.md','PRUEBAS_GRAPHQL.md','AUDITORIA_CAPTURAS_REALES.md','LavaFacil_Operaciones_GraphQL.graphql','LavaFacil_GraphQL.postman_collection.json')) {
    Copy-Item -LiteralPath (Join-Path $projectRoot ('04-Documentacion\' + $name)) -Destination (Join-Path $deliveryRoot '06_Instrucciones_y_pruebas')
}
New-Item -ItemType Directory -Path (Join-Path $deliveryRoot '06_Instrucciones_y_pruebas\Scripts_de_evidencia') -Force | Out-Null
foreach ($name in @('08_Demostracion_BULK_INSERT_Segura.sql','09_Preparar_Evidencias_Auxiliares.sql','09_Repetir_BCP_Evidencias.ps1','10_Verificar_Repeticion_BCP.sql')) {
    Copy-Item -LiteralPath (Join-Path $projectRoot ('01-Script\' + $name)) -Destination (Join-Path $deliveryRoot '06_Instrucciones_y_pruebas\Scripts_de_evidencia')
}
Copy-Item -LiteralPath (Join-Path $repoRoot 'LEER_ENTREGA_PROYECTO_2.md') -Destination (Join-Path $deliveryRoot '00_LEER_PRIMERO.md')

$csvCount = @(Get-ChildItem -LiteralPath (Join-Path $deliveryRoot '04_Archivos_originales_de_carga') -Recurse -File -Filter '*.csv').Count
if ($csvCount -ne 10) { throw "Se esperaban 10 CSV, se encontraron $csvCount." }
$privateFiles = @(Get-ChildItem -LiteralPath $deliveryRoot -Recurse -File | Where-Object { $_.Name -eq 'appsettings.Development.json' -or $_.FullName -match '\\(bin|obj|keys)\\' })
if ($privateFiles.Count -gt 0) { throw 'Se detectó configuración privada o archivos de ejecución.' }
$manifestFiles = @(Get-ChildItem -LiteralPath $deliveryRoot -Recurse -File | Where-Object { $_.Name -ne 'MANIFIESTO_ARCHIVOS.csv' })
$manifestFiles | ForEach-Object {
    [PSCustomObject]@{Archivo=$_.FullName.Substring($deliveryRoot.Length + 1); Bytes=$_.Length; SHA256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}
} | Export-Csv -LiteralPath (Join-Path $deliveryRoot 'MANIFIESTO_ARCHIVOS.csv') -NoTypeInformation -Encoding utf8
Compress-Archive -LiteralPath $deliveryRoot -DestinationPath $zipPath -CompressionLevel Optimal
Write-Output "CARPETA=$deliveryRoot"
Write-Output "ZIP=$zipPath"
Write-Output "CSV=$csvCount"
