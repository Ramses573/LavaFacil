# Fase 6 - Pruebas UI/estaticas (5.1-5.3) contra el servidor en 127.0.0.1:5088
# Solo lectura del contenido servido. Fuente ASCII puro.
$ErrorActionPreference = 'Continue'
$Base = 'http://127.0.0.1:5088'
$script:results = New-Object System.Collections.Generic.List[object]
function Add-R($id,$estado,$ev) {
    $script:results.Add([pscustomobject]@{ Prueba=$id; Estado=$estado; Evidencia=$ev })
    Write-Output ('RESULT|' + $id + '|' + $estado + '|' + $ev)
}
function Get-Served([string]$path) {
    try {
        $r = Invoke-WebRequest -Uri ($Base + $path) -UseBasicParsing -ErrorAction Stop
        return [pscustomobject]@{ Status=[int]$r.StatusCode; Body=[string]$r.Content }
    } catch {
        $resp = $_.Exception.Response
        if ($resp) { return [pscustomobject]@{ Status=[int]$resp.StatusCode; Body='' } }
        return [pscustomobject]@{ Status=-1; Body='' }
    }
}

$html = Get-Served '/'
$js   = Get-Served '/app.js'
Write-Output ('HTML status=' + $html.Status + ' bytes=' + $html.Body.Length + '  |  app.js status=' + $js.Status + ' bytes=' + $js.Body.Length)

# 5.1a CTA presente, despues del boton de login y antes de .auth-foot
$cta = $html.Body.IndexOf('id="register-cta"')
$btn = $html.Body.IndexOf('Iniciar sesi', [Math]::Max(0,$cta - 900))
$foot = $html.Body.IndexOf('class="auth-foot"')
$ordenOk = ($html.Status -eq 200 -and $cta -gt 0 -and $btn -gt 0 -and $foot -gt 0 -and $btn -lt $cta -and $cta -lt $foot)
Add-R 'UI-5.1 CTA #register-cta servido despues del boton de login y antes de .auth-foot' $(if ($ordenOk) {'PASS'} else {'FAIL'}) ('btn=' + $btn + ', cta=' + $cta + ', authFoot=' + $foot)

# 5.1b template de registro completo
$tmpl = $html.Body.IndexOf('<template id="signup-template">')
$tmplEnd = $html.Body.IndexOf('</template>', $tmpl)
$tmplOk = ($tmpl -gt 0 -and $tmplEnd -gt $tmpl)
$seg = ''
if ($tmplOk) { $seg = $html.Body.Substring($tmpl, $tmplEnd - $tmpl + 11) }
$campos = @('name="identity"','name="username"','name="password"','name="confirmPassword"','Crear mi cuenta','form-error','minlength="10"')
$faltan = @($campos | Where-Object { -not $seg.Contains($_) })
Add-R 'UI-5.1 #signup-template completo (abierto/cerrado y con todos los campos)' $(if ($tmplOk -and $faltan.Count -eq 0) {'PASS'} else {'FAIL'}) ('abierto=' + ($tmpl -gt 0) + ', cerrado=' + ($tmplEnd -gt $tmpl) + ', campos faltantes=' + $(if ($faltan.Count) {$faltan -join ','} else {'ninguno'}))

# 5.1c app.js servido
$jsOk = ($js.Status -eq 200)
$chk1 = $js.Body.Contains('function showSignup()')
$chk2 = $js.Body.Contains("request('register'")
$chk3 = $js.Body.Contains("routeName==='registro'")
$chk4 = $js.Body.Contains('cta.hidden = !state.featuresReady')
Add-R 'UI-5.1 app.js servido contiene showSignup, request(register, rama routeName==registro' $(if ($jsOk -and $chk1 -and $chk2 -and $chk3) {'PASS'} else {'FAIL'}) ('showSignup=' + $chk1 + ', request(register=' + $chk2 + ', routeName=' + $chk3)
Add-R 'UI-5.1 app.js liga el CTA a featuresReady (cta.hidden = !state.featuresReady)' $(if ($chk4) {'PASS'} else {'FAIL'}) ('presente=' + $chk4)

# 5.1d node --check sobre el JS servido
$nodeOk = $false; $nodeEv = ''
$node = Get-Command node -ErrorAction SilentlyContinue
if ($node) {
    $tmp = Join-Path $env:TEMP ('laf-app-servido-' + ([guid]::NewGuid().ToString('N')) + '.js')
    [IO.File]::WriteAllText($tmp, $js.Body, (New-Object Text.UTF8Encoding $false))
    $out = & node --check $tmp 2>&1
    $nodeOk = ($LASTEXITCODE -eq 0)
    $nodeEv = 'node --check exit=' + $LASTEXITCODE + $(if ($out) { ' salida=' + ($out -join ' ') } else { ' sin salida (OK)' })
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
} else { $nodeEv = 'node no esta instalado' }
Add-R 'UI-5.1 node --check del app.js servido' $(if ($nodeOk) {'PASS'} else {'FAIL'}) $nodeEv

# 5.2 /monitor.js -> 404
$m = Get-Served '/monitor.js'
Add-R 'UI-5.2 GET /monitor.js -> 404' $(if ($m.Status -eq 404) {'PASS'} else {'FAIL'}) ('status=' + $m.Status)

# 5.2 GET / sin mencionar mirroring
$sinMirror = -not $html.Body.ToLower().Contains('mirror')
Add-R 'UI-5.2 GET / no menciona mirroring' $(if ($sinMirror) {'PASS'} else {'FAIL'}) ('contiene mirroring=' + (-not $sinMirror))

# 5.3 /api/health -> 404
$h = Get-Served '/api/health'
Add-R 'UI-5.3 GET /api/health -> 404' $(if ($h.Status -eq 404) {'PASS'} else {'FAIL'}) ('status=' + $h.Status)

$fail = @($script:results | Where-Object { $_.Estado -ne 'PASS' }).Count
Write-Output ('RESUMEN-FASE6: total=' + $script:results.Count + ' pass=' + ($script:results.Count - $fail) + ' fail=' + $fail)
$script:results | ConvertTo-Json -Depth 3 | Out-File -FilePath (Join-Path $PSScriptRoot 'fase6.json') -Encoding UTF8
