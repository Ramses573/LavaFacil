$ErrorActionPreference = 'Stop'
$docxPath = Join-Path $PSScriptRoot 'Manual_Proyecto2_LavaFacil_COMPLETO.docx'
$pdfPath = Join-Path $PSScriptRoot 'Manual_Proyecto2_LavaFacil_COMPLETO.pdf'
$word = New-Object -ComObject Word.Application
$word.Visible = $false
$word.DisplayAlerts = 0
try {
    $document = $word.Documents.Open($docxPath, $false, $false)
    $document.Fields.Update() | Out-Null
    $document.Save()
    $document.ExportAsFixedFormat($pdfPath, 17)
    Write-Output ('Páginas: ' + $document.ComputeStatistics(2))
    $document.Close($false)
}
finally {
    $word.Quit()
    [Runtime.InteropServices.Marshal]::ReleaseComObject($word) | Out-Null
}
