$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Security
Add-Type -AssemblyName System.Data
$root=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$cfg=Join-Path $root 'LavaFacil.Web\Data\connection.dpapi'
$raw=[Security.Cryptography.ProtectedData]::Unprotect([IO.File]::ReadAllBytes($cfg),$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)
$saved=[Text.Encoding]::UTF8.GetString($raw).Replace('Trust Server Certificate','TrustServerCertificate').Replace('Encrypt=Mandatory','Encrypt=True')
$c=New-Object System.Data.SqlClient.SqlConnection((New-Object System.Data.SqlClient.SqlConnectionStringBuilder $saved).ConnectionString)
try {
  $c.Open(); $q=$c.CreateCommand(); $q.CommandText=@"
SELECT p.name AS Nombre,
       CAST(CASE WHEN p.object_id IS NULL THEN 0 ELSE 1 END AS bit) AS Existe,
       CAST(CASE WHEN sm.definition LIKE '%ClaveVersion%' THEN 1 ELSE 0 END AS bit) AS IncluyeClaveVersion
FROM (VALUES ('usp_ValidarLogin')) v(name)
LEFT JOIN sys.procedures p ON p.schema_id=SCHEMA_ID('dbo') AND p.name=v.name
LEFT JOIN sys.sql_modules sm ON sm.object_id=p.object_id;
"@;
  $r=$q.ExecuteReader();[void]$r.Read();[pscustomobject]@{Nombre=$r.GetString(0);Existe=$r.GetBoolean(1);IncluyeClaveVersion=$r.GetBoolean(2)}|ConvertTo-Json
} finally { if($c){$c.Dispose()} }
