$ErrorActionPreference='Stop'; Add-Type -AssemblyName System.Security; Add-Type -AssemblyName System.Data
$root=Split-Path -Parent (Split-Path -Parent $PSScriptRoot);$cfg=Join-Path $root 'LavaFacil.Web\Data\connection.dpapi'
$b=[Security.Cryptography.ProtectedData]::Unprotect([IO.File]::ReadAllBytes($cfg),$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)
$s=[Text.Encoding]::UTF8.GetString($b).Replace('Trust Server Certificate','TrustServerCertificate').Replace('Encrypt=Mandatory','Encrypt=True')
$c=New-Object System.Data.SqlClient.SqlConnection((New-Object System.Data.SqlClient.SqlConnectionStringBuilder $s).ConnectionString);$c.Open();$q=$c.CreateCommand()
# Clave legacy de fixture configurable en tiempo de ejecución; no se versiona ningún valor real.
$legacyPass=if($env:LAVAFACIL_LEGACY_TEST_PASSWORD){$env:LAVAFACIL_LEGACY_TEST_PASSWORD}else{'REDACTADO'}
$q.CommandText="UPDATE dbo.Usuarios SET Clave='$legacyPass', ClaveHash=NULL WHERE NombreUsuario='autotest.legacy.20261106235607'; SELECT @@ROWCOUNT AS Actualizadas;"
$r=$q.ExecuteScalar();[pscustomobject]@{actualizadas=[int]$r}|ConvertTo-Json;$c.Dispose()

