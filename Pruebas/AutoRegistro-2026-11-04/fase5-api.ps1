# Fase 5 - Pruebas API (4.1-4.10) contra http://127.0.0.1:5088
# Crea SOLO la cuenta de prueba autotest.api.1 / AUTOTEST-API-01 y la ELIMINA al final (confirmado).
# Fuente ASCII puro (PS 5.1 lee sin BOM como ANSI). Nunca imprime la contrasena en claro salvo como dato de prueba.
$ErrorActionPreference = 'Continue'
Add-Type -AssemblyName System.Security
Add-Type -AssemblyName System.Data
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$Base = 'http://127.0.0.1:5088'
$script:results = New-Object System.Collections.Generic.List[object]
function Add-R($id,$estado,$ev) {
    $script:results.Add([pscustomobject]@{ Prueba=$id; Estado=$estado; Evidencia=$ev })
    Write-Output ('RESULT|' + $id + '|' + $estado + '|' + $ev)
}
function Http-Req($method,$url,$body,$headers,$session) {
    $p = @{ Uri=$url; Method=$method; UseBasicParsing=$true; ErrorAction='Stop' }
    if ($body) { $p.Body = $body; $p.ContentType = 'application/json' }
    if ($headers) { $p.Headers = $headers }
    if ($session) { $p.WebSession = $session }
    try {
        $r = Invoke-WebRequest @p
        return [pscustomobject]@{ Status=[int]$r.StatusCode; Body=[string]$r.Content; RespHeaders=$r.Headers; Err=$null }
    } catch {
        $resp = $_.Exception.Response
        if ($resp) {
            $b = ''
            try { $sr = New-Object IO.StreamReader($resp.GetResponseStream()); $b = $sr.ReadToEnd() } catch {}
            return [pscustomobject]@{ Status=[int]$resp.StatusCode; Body=$b; RespHeaders=$resp.Headers; Err=$null }
        }
        return [pscustomobject]@{ Status=-1; Body=''; RespHeaders=@{}; Err=$_.Exception.Message }
    }
}
function Bootstrap($session) {
    $r = Http-Req 'GET' ($Base + '/api/bootstrap') $null $null $session
    $j = $null
    try { $j = $r.Body | ConvertFrom-Json } catch {}
    return [pscustomobject]@{ Status=$r.Status; Json=$j; Body=$r.Body }
}
# POST sin token CSRF (cabecera omitida a proposito)
function Post-NoCsrf($url,$body) {
    $p = @{ Uri=$url; Method='POST'; Body=$body; ContentType='application/json'; UseBasicParsing=$true; ErrorAction='Stop' }
    try { $r = Invoke-WebRequest @p; return [int]$r.StatusCode }
    catch { $resp=$_.Exception.Response; if ($resp) { return [int]$resp.StatusCode } ; return -1 }
}
# POST con Host alterado (HttpWebRequest permite fijar Host)
function Post-HostAlterado($url,$hostHeader,$body) {
    $req = [System.Net.HttpWebRequest]::Create($url)
    $req.Method = 'POST'; $req.ContentType = 'application/json'; $req.Host = $hostHeader
    $bytes = [Text.Encoding]::UTF8.GetBytes($body)
    $req.ContentLength = $bytes.Length
    $st = $req.GetRequestStream(); $st.Write($bytes,0,$bytes.Length); $st.Close()
    try { $resp = $req.GetResponse(); return [int]$resp.StatusCode }
    catch [System.Net.WebException] { if ($_.Exception.Response) { return [int]$_.Exception.Response.StatusCode } ; return -1 }
}

# Datos de prueba
$Cedula='AUTOTEST-API-01'; $Username='autotest.api.1'; $Email='autotest.api.1@example.test'
# Clave de fixture generada en tiempo de ejecución; no se versiona ningún valor real.
$Password = if($env:LAVAFACIL_TEST_PASSWORD){$env:LAVAFACIL_TEST_PASSWORD}else{'Temporal-' + [guid]::NewGuid().ToString('N') + '!Aa1'}
$Payload = @{ identity=$Cedula; name='PruebaAuto'; lastName='Registro API'; phone='099111001'
              email=$Email; address='Av. Prueba 456'; username=$Username; password=$Password } | ConvertTo-Json

# Limpieza previa
$dbBytes = [Security.Cryptography.ProtectedData]::Unprotect([IO.File]::ReadAllBytes((Join-Path $root 'LavaFacil.Web\Data\connection.dpapi')),$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)
$saved = [Text.Encoding]::UTF8.GetString($dbBytes).Replace('Trust Server Certificate','TrustServerCertificate').Replace('Encrypt=Mandatory','Encrypt=True')
$csb = New-Object System.Data.SqlClient.SqlConnectionStringBuilder $saved
$cn = New-Object System.Data.SqlClient.SqlConnection $csb.ConnectionString
function Db-Scalar([string]$sql) { $c=$script:cn.CreateCommand(); $c.CommandText=$sql; return $c.ExecuteScalar() }
$script:cn.Open()
[void](Db-Scalar "DELETE dbo.Usuarios WHERE NombreUsuario='autotest.api.1';")
[void](Db-Scalar "DELETE dbo.Clientes WHERE Cedula='AUTOTEST-API-01' OR Email='autotest.api.1@example.test';")

$sess = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$token = $null
try {
    # 4.1 bootstrap
    $b = Bootstrap $sess
    $featuresReady = $false; $configured = $false
    if ($b.Json) { $featuresReady = [bool]$b.Json.featuresReady; $configured = [bool]$b.Json.configured; $token = $b.Json.token }
    $ok41 = ($b.Status -eq 200 -and $featuresReady -and $configured -and -not [string]::IsNullOrEmpty($token))
    Add-R 'API-4.1 GET /api/bootstrap -> 200 con configured=true y featuresReady=true (token CSRF)' $(if ($ok41) {'PASS'} else {'FAIL'}) ('status=' + $b.Status + ', configured=' + $configured + ', featuresReady=' + $featuresReady + ', token presente=' + (-not [string]::IsNullOrEmpty($token)))
    $featuresReadyGlobal = $featuresReady

    # 4.2 sin CSRF -> 400
    $s42 = Post-NoCsrf ($Base + '/api/register') $Payload
    Add-R 'API-4.2 POST /api/register sin X-CSRF-TOKEN -> 400' $(if ($s42 -eq 400) {'PASS'} else {'FAIL'}) ('status=' + $s42)

    # 4.3 Host alterado -> 403
    $s43 = Post-HostAlterado ($Base + '/api/register') 'evil.example.com' $Payload
    Add-R 'API-4.3 POST /api/register con Host alterado -> 403' $(if ($s43 -eq 403) {'PASS'} else {'FAIL'}) ('status=' + $s43)

    # 4.4 registro valido -> 200 role Cliente + cookie + sin exponer clave/hash
    $b44 = Bootstrap $sess
    $token = $b44.Json.token
    $r44 = Http-Req 'POST' ($Base + '/api/register') $Payload @{'X-CSRF-TOKEN'=$token} $sess
    $role44 = $null; $name44 = $null
    try { $j44 = $r44.Body | ConvertFrom-Json; if ($j44.user) { $role44 = $j44.user.role; $name44 = $j44.user.name } } catch {}
    $cookieOk = $false
    if ($sess.Cookies) { $c = $sess.Cookies.GetCookies([Uri]$Base); foreach ($ck in $c) { if ($ck.Name -eq 'LavaFacil.Session') { $cookieOk = $true } } }
    $sinExponer = (-not $r44.Body.Contains($Password)) -and (-not $r44.Body.Contains('ClaveHash')) -and (-not $r44.Body.Contains('PBKDF2')) -and (-not $r44.Body.Contains('"Clave"'))
    $ok44 = ($r44.Status -eq 200 -and $role44 -eq 'Cliente' -and $cookieOk -and $sinExponer)
    Add-R 'API-4.4 registro valido -> 200, user.role=Cliente, cookie LavaFacil.Session, sin clave ni hash' $(if ($ok44) {'PASS'} else {'FAIL'}) ('status=' + $r44.Status + ', role=' + $role44 + ', cookie=' + $cookieOk + ', sinExponer=' + $sinExponer + ', name=' + $name44)
    Add-R 'API-4.9 (A-02) POST /api/register responde 200 y NO 500/503 con featuresReady=true' $(if ($r44.Status -eq 200) {'PASS'} else {'FAIL'}) ('status=' + $r44.Status + ', featuresReady=' + $featuresReadyGlobal)

    # 4.5 profile 200 / clients 403
    $r45a = Http-Req 'GET' ($Base + '/api/profile') $null $null $sess
    $r45b = Http-Req 'GET' ($Base + '/api/clients') $null $null $sess
    Add-R 'API-4.5 GET /api/profile -> 200' $(if ($r45a.Status -eq 200) {'PASS'} else {'FAIL'}) ('status=' + $r45a.Status)
    Add-R 'API-4.5 GET /api/clients como Cliente -> 403' $(if ($r45b.Status -eq 403) {'PASS'} else {'FAIL'}) ('status=' + $r45b.Status + ', cuerpo=' + $r45b.Body.Substring(0,[Math]::Min(120,$r45b.Body.Length)))

    # 4.6 logout + login
    $b46 = Bootstrap $sess
    $token = $b46.Json.token
    $r46a = Http-Req 'POST' ($Base + '/api/logout') $null @{'X-CSRF-TOKEN'=$token} $sess
    $b46b = Bootstrap $sess
    $token2 = $b46b.Json.token
    $loginBody = @{ username=$Username; password=$Password } | ConvertTo-Json
    $r46b = Http-Req 'POST' ($Base + '/api/login') $loginBody @{'X-CSRF-TOKEN'=$token2} $sess
    $role46 = $null
    try { $j46 = $r46b.Body | ConvertFrom-Json; if ($j46.user) { $role46 = $j46.user.role } } catch {}
    $ok46 = ($r46a.Status -eq 200 -and $r46b.Status -eq 200 -and $role46 -eq 'Cliente')
    Add-R 'API-4.6 logout 200 + login real 200 con user.role=Cliente' $(if ($ok46) {'PASS'} else {'FAIL'}) ('logout=' + $r46a.Status + ', login=' + $r46b.Status + ', role=' + $role46)

    # 4.7 duplicado -> 400 y una sola fila
    $b47 = Bootstrap $sess
    $token = $b47.Json.token
    $r47 = Http-Req 'POST' ($Base + '/api/register') $Payload @{'X-CSRF-TOKEN'=$token} $sess
    $rowsU = [int](Db-Scalar "SELECT COUNT(*) FROM dbo.Usuarios WHERE NombreUsuario='autotest.api.1';")
    $rowsC = [int](Db-Scalar "SELECT COUNT(*) FROM dbo.Clientes WHERE Cedula='AUTOTEST-API-01';")
    $ok47 = ($r47.Status -eq 400 -and $rowsU -eq 1 -and $rowsC -eq 1)
    Add-R 'API-4.7 registro duplicado -> 400 con una sola fila en BD' $(if ($ok47) {'PASS'} else {'FAIL'}) ('status=' + $r47.Status + ', Usuarios=' + $rowsU + ', Clientes=' + $rowsC + ', msg=' + $r47.Body.Substring(0,[Math]::Min(120,$r47.Body.Length)))

    # 4.8 validaciones -> 400
    $b48 = Bootstrap $sess
    $token = $b48.Json.token
    $p48a = $Payload | ConvertFrom-Json; $p48a.password = '12345678'
    $r48a = Http-Req 'POST' ($Base + '/api/register') ($p48a | ConvertTo-Json) @{'X-CSRF-TOKEN'=$token} $sess
    Add-R 'API-4.8 password de 8 caracteres (<10) -> 400' $(if ($r48a.Status -eq 400) {'PASS'} else {'FAIL'}) ('status=' + $r48a.Status + ', msg=' + $r48a.Body.Substring(0,[Math]::Min(120,$r48a.Body.Length)))
    $b48b = Bootstrap $sess
    $token = $b48b.Json.token
    $p48b = $Payload | ConvertFrom-Json; $p48b.email = 'no-es-correo'
    $r48b = Http-Req 'POST' ($Base + '/api/register') ($p48b | ConvertTo-Json) @{'X-CSRF-TOKEN'=$token} $sess
    Add-R 'API-4.8 correo invalido -> 400' $(if ($r48b.Status -eq 400) {'PASS'} else {'FAIL'}) ('status=' + $r48b.Status + ', msg=' + $r48b.Body.Substring(0,[Math]::Min(120,$r48b.Body.Length)))
    $b48c = Bootstrap $sess
    $token = $b48c.Json.token
    $p48c = $Payload | ConvertFrom-Json; $p48c.name = ''
    $r48c = Http-Req 'POST' ($Base + '/api/register') ($p48c | ConvertTo-Json) @{'X-CSRF-TOKEN'=$token} $sess
    Add-R 'API-4.8 nombre vacio -> 400' $(if ($r48c.Status -eq 400) {'PASS'} else {'FAIL'}) ('status=' + $r48c.Status + ', msg=' + $r48c.Body.Substring(0,[Math]::Min(120,$r48c.Body.Length)))
} finally {
    # 4.10 limpieza
    try {
        [void](Db-Scalar "DELETE dbo.Usuarios WHERE NombreUsuario='autotest.api.1';")
        [void](Db-Scalar "DELETE dbo.Clientes WHERE Cedula='AUTOTEST-API-01' OR Email='autotest.api.1@example.test';")
        $u = [int](Db-Scalar "SELECT COUNT(*) FROM dbo.Usuarios WHERE NombreUsuario='autotest.api.1';")
        $c = [int](Db-Scalar "SELECT COUNT(*) FROM dbo.Clientes WHERE Cedula='AUTOTEST-API-01' OR Email='autotest.api.1@example.test';")
        Add-R 'API-4.10 limpieza de la cuenta de prueba confirmada (0 filas)' $(if ($u -eq 0 -and $c -eq 0) {'PASS'} else {'FAIL'}) ('Usuarios=' + $u + ', Clientes=' + $c)
    } catch { Add-R 'API-4.10 limpieza de la cuenta de prueba confirmada (0 filas)' 'FAIL' ('error=' + $_.Exception.Message) }
    $script:cn.Close()
}
$fail = @($script:results | Where-Object { $_.Estado -ne 'PASS' }).Count
Write-Output ('RESUMEN-FASE5: total=' + $script:results.Count + ' pass=' + ($script:results.Count - $fail) + ' fail=' + $fail)
$script:results | ConvertTo-Json -Depth 3 | Out-File -FilePath (Join-Path $PSScriptRoot 'fase5.json') -Encoding UTF8
