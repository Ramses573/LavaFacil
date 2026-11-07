# Verificacion puntual del hallazgo B-02: que devuelve /api/register a un cliente anonimo.
# Crea la cuenta AUTOTEST-API-02 / autotest.api.2 y la ELIMINA al final. Fuente ASCII puro.
$ErrorActionPreference = 'Continue'
Add-Type -AssemblyName System.Security
Add-Type -AssemblyName System.Data
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$Base = 'http://127.0.0.1:5088'
# Clave de fixture generada en tiempo de ejecución; no se versiona ningún valor real.
$Password = if($env:LAVAFACIL_TEST_PASSWORD){$env:LAVAFACIL_TEST_PASSWORD}else{'Temporal-' + [guid]::NewGuid().ToString('N') + '!Aa1'}
$db = [Security.Cryptography.ProtectedData]::Unprotect([IO.File]::ReadAllBytes((Join-Path $root 'LavaFacil.Web\Data\connection.dpapi')),$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)
$saved = [Text.Encoding]::UTF8.GetString($db).Replace('Trust Server Certificate','TrustServerCertificate').Replace('Encrypt=Mandatory','Encrypt=True')
$csb = New-Object System.Data.SqlClient.SqlConnectionStringBuilder $saved
$cn = New-Object System.Data.SqlClient.SqlConnection $csb.ConnectionString
$cn.Open()
function Db([string]$sql) { $c=$script:cn.CreateCommand(); $c.CommandText=$sql; return $c.ExecuteScalar() }
[void](Db "DELETE dbo.Usuarios WHERE NombreUsuario='autotest.api.2';")
[void](Db "DELETE dbo.Clientes WHERE Cedula='AUTOTEST-API-02' OR Email='autotest.api.2@example.test';")
$sess = New-Object Microsoft.PowerShell.Commands.WebRequestSession
try {
    $b = Invoke-WebRequest -Uri ($Base + '/api/bootstrap') -UseBasicParsing -WebSession $sess
    $token = ($b.Content | ConvertFrom-Json).token
    $payload = @{ identity='AUTOTEST-API-02'; name='PruebaAuto'; lastName='Registro API'; phone='099111002'
                  email='autotest.api.2@example.test'; address='Av. Prueba 789'; username='autotest.api.2'
                  password=$Password } | ConvertTo-Json
    try {
        $r = Invoke-WebRequest -Uri ($Base + '/api/register') -Method POST -Body $payload -ContentType 'application/json' -Headers @{ 'X-CSRF-TOKEN' = $token } -WebSession $sess -UseBasicParsing -ErrorAction Stop
        Write-Output ('STATUS=' + [int]$r.StatusCode)
        Write-Output ('BODY=' + $r.Content)
    } catch {
        $resp = $_.Exception.Response
        if ($resp) { $sr = New-Object IO.StreamReader($resp.GetResponseStream()); Write-Output ('STATUS=' + [int]$resp.StatusCode); Write-Output ('BODY=' + $sr.ReadToEnd()) }
        else { Write-Output ('ERROR=' + $_.Exception.Message) }
    }
} finally {
    [void](Db "DELETE dbo.Usuarios WHERE NombreUsuario='autotest.api.2';")
    [void](Db "DELETE dbo.Clientes WHERE Cedula='AUTOTEST-API-02' OR Email='autotest.api.2@example.test';")
    $u = [int](Db "SELECT COUNT(*) FROM dbo.Usuarios WHERE NombreUsuario='autotest.api.2';")
    $c2 = [int](Db "SELECT COUNT(*) FROM dbo.Clientes WHERE Cedula='AUTOTEST-API-02' OR Email='autotest.api.2@example.test';")
    Write-Output ('LIMPIEZA Usuarios=' + $u + ' Clientes=' + $c2)
    $cn.Close()
}
