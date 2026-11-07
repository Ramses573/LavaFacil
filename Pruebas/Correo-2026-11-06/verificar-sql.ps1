$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Security
Add-Type -AssemblyName System.Data
$root=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$cfg=Join-Path $root 'LavaFacil.Web\Data\connection.dpapi'
$raw=[Security.Cryptography.ProtectedData]::Unprotect([IO.File]::ReadAllBytes($cfg),$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)
$saved=[Text.Encoding]::UTF8.GetString($raw).Replace('Trust Server Certificate','TrustServerCertificate').Replace('Encrypt=Mandatory','Encrypt=True')
$cs=(New-Object System.Data.SqlClient.SqlConnectionStringBuilder $saved).ConnectionString
$c=New-Object System.Data.SqlClient.SqlConnection $cs
try {
 $c.Open(); $cmd=$c.CreateCommand()
 $cmd.CommandText=@"
SELECT 'SP' AS Tipo, p.name AS Nombre, CAST(1 AS bit) AS Existe
FROM sys.procedures p WHERE p.schema_id=SCHEMA_ID('dbo') AND p.name IN ('app_CorreoEstado','app_CrearTokenCorreo','app_SolicitarRecuperacion','app_ConfirmarCorreo','app_RestablecerClave')
UNION ALL SELECT 'COLUMN','Usuarios.EmailVerificado',CAST(CASE WHEN COL_LENGTH('dbo.Usuarios','EmailVerificado') IS NULL THEN 0 ELSE 1 END AS bit)
UNION ALL SELECT 'COLUMN','Usuarios.EmailVerificadoEn',CAST(CASE WHEN COL_LENGTH('dbo.Usuarios','EmailVerificadoEn') IS NULL THEN 0 ELSE 1 END AS bit)
UNION ALL SELECT 'COLUMN','Usuarios.ClaveVersion',CAST(CASE WHEN COL_LENGTH('dbo.Usuarios','ClaveVersion') IS NULL THEN 0 ELSE 1 END AS bit)
UNION ALL SELECT 'DEFAULT','Usuarios.ClaveVersion=((0))',CAST(CASE WHEN EXISTS (SELECT 1 FROM sys.default_constraints dc JOIN sys.columns col ON dc.parent_object_id=col.object_id AND dc.parent_column_id=col.column_id JOIN sys.tables t ON t.object_id=col.object_id WHERE t.name='Usuarios' AND col.name='ClaveVersion' AND dc.definition IN ('((0))','(0)')) THEN 1 ELSE 0 END AS bit)
UNION ALL SELECT 'TABLE',t.name,CAST(1 AS bit) FROM sys.tables t WHERE t.name='TokensCorreo'
UNION ALL SELECT 'INDEX',i.name,CAST(1 AS bit) FROM sys.indexes i JOIN sys.tables t ON t.object_id=i.object_id WHERE t.name IN ('Usuarios','TokensCorreo') AND (i.name LIKE '%Correo%' OR i.name LIKE '%Token%');
SELECT 'GRANT' AS Tipo, dp.name+' -> '+p.name AS Nombre, CAST(1 AS bit) AS Existe FROM sys.database_permissions perm JOIN sys.database_principals dp ON dp.principal_id=perm.grantee_principal_id JOIN sys.objects p ON p.object_id=perm.major_id WHERE perm.permission_name='EXECUTE' AND p.name IN ('app_CorreoEstado','app_CrearTokenCorreo','app_SolicitarRecuperacion','app_ConfirmarCorreo','app_RestablecerClave');
"@
 $r=$cmd.ExecuteReader(); $rows=@(); while($r.Read()){ $rows += [pscustomobject]@{Tipo=$r.GetString(0);Nombre=$r.GetString(1);Existe=$r.GetBoolean(2)} }; if($r.NextResult()){ while($r.Read()){ $rows += [pscustomobject]@{Tipo=$r.GetString(0);Nombre=$r.GetString(1);Existe=$r.GetBoolean(2)} } }; $r.Close()
 $rows | ConvertTo-Json -Depth 3
} finally { if($c){$c.Dispose()} }
