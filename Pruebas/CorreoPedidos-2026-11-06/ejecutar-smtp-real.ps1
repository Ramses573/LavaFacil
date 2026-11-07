$ErrorActionPreference='Stop'
$dir=Split-Path -Parent $MyInvocation.MyCommand.Path
$base='http://127.0.0.1:5091'
$stamp=[DateTime]::UtcNow.ToString('yyyyMMddHHmmssfff')
$user="smtpqa$stamp"
$ced="SQ$($stamp.Substring($stamp.Length-12))"
# Clave de fixture generada en tiempo de ejecución; no se versiona ningún valor real.
$pwd=if($env:LAVAFACIL_TEST_PASSWORD){$env:LAVAFACIL_TEST_PASSWORD}else{'Temporal-'+[guid]::NewGuid().ToString('N')+'!Aa1'}
$marker="SMTP REAL QA $stamp"
# Destinatario de prueba configurable; por defecto un buzon ficticio, nunca una cuenta real.
$mail=if($env:LAVAFACIL_SMTP_REAL_TEST_EMAIL){$env:LAVAFACIL_SMTP_REAL_TEST_EMAIL}else{'ejemplo@dominio.local'}
if([string]::IsNullOrWhiteSpace($mail)){ throw 'No se encontró cuenta remitente candidata en BD.' }
$tempMail="smtpqa$stamp@example.com"
$web=New-Object Microsoft.PowerShell.Commands.WebRequestSession
function J($method,$path,$body=$null,$headers=@{}){
  $params=@{Uri=($base+$path);Method=$method;WebSession=$web;UseBasicParsing=$true;Headers=$headers}
  if($null-ne$body){$params.ContentType='application/json';$params.Body=($body|ConvertTo-Json -Compress)}
  try {$r=Invoke-WebRequest @params;return @{Status=[int]$r.StatusCode;Json=($r.Content|ConvertFrom-Json)}}
  catch {
    $resp=$_.Exception.Response
    $body=''
    if($resp){$reader=New-Object IO.StreamReader($resp.GetResponseStream());$body=$reader.ReadToEnd()}
    $safe=($body -replace '(?i)(password|clave|token|codigo|authorization|cookie)\s*[:=]\s*[^; ,}]+','$1=[REDACTED]')
    return @{Status=if($resp){[int]$resp.StatusCode}else{0};Json=if($safe){$safe|ConvertFrom-Json}else{@{error='respuesta HTTP sin cuerpo'}}}
  }
}
$result=[ordered]@{fecha=(Get-Date).ToString('o');entorno='Production';outboxActivo=$false;build='PASS';smtpDirecto='NOT_RUN';pedidoApi='NOT_RUN';correoEnvio='NOT_RUN';limpieza='NOT_RUN';bandeja='NO_VERIFICADA';error=$null}
try {
  $boot=J GET '/api/bootstrap'
  $csrf=$boot.Json.token
  $h=@{'X-CSRF-TOKEN'=$csrf}
  $admin=J POST '/api/first-account' @{identity=$ced;name='SMTP';lastName='QA';phone='555-0100';email=$mail;username=$user;password=$pwd} $h
  if($admin.Status -ne 200){throw "cuenta inicial HTTP $($admin.Status): $($admin.Json.error)"}
  $login=J POST '/api/login' @{username=$user;password=$pwd} $h
  if($login.Status -ne 200){throw "login HTTP $($login.Status): $($login.Json.error)"}
  $t0=[Diagnostics.Stopwatch]::StartNew();$send=J POST '/api/email/verificacion/enviar' @{} $h;$t0.Stop()
  if($send.Status -ne 200 -or -not $send.Json.enviado){throw "SMTP fallo HTTP $($send.Status) mensaje sanitizado: $($send.Json.error)"}
  $result.smtpDirecto='PASS';$result.smtpMs=$t0.ElapsedMilliseconds
  $client=J POST '/api/clients' @{identity=$ced+'C';name='SMTP';lastName='QA';phone='555-0101';email=$tempMail;address='Temporal'} $h
  if($client.Status -ne 200){throw "cliente HTTP $($client.Status): $($client.Json.error)"}
  $clientId=[int](((sqlcmd -S MADRENZO -d LavaFacil -E -C -h -1 -W -Q "SET NOCOUNT ON; SELECT TOP(1) IdCliente FROM dbo.Clientes WHERE Email='$tempMail' ORDER BY IdCliente DESC" 2>$null)-join '').Trim())
  if($clientId -le 0){throw 'No se recuperó IdCliente temporal.'}
  $services=J GET '/api/services'
  $rows=@($services.Json.Rows)
  if($rows.Count -eq 0){throw 'No hay servicio activo para pedido temporal.'}
  $sid=[int]$rows[0].IdServicio
  $order=J POST '/api/orders' @{clientId=$clientId;notes=$marker;lines=@(@{serviceId=$sid;quantity=1})} $h
  if($order.Status -ne 200){throw "pedido HTTP $($order.Status)"}
  $result.pedidoApi='PASS'
  Start-Sleep -Seconds 15
  $q="SET NOCOUNT ON; SELECT TOP(1) ce.Estado,ce.Intentos,ce.Tipo FROM dbo.CorreoEnvios ce JOIN dbo.Pedidos p ON p.IdPedido=ce.IdPedido WHERE p.Observaciones='$marker' ORDER BY ce.IdEnvio DESC;"
  $row=((sqlcmd -S MADRENZO -d LavaFacil -E -C -h -1 -W -s '|' -Q $q 2>$null)-join '').Trim()
  if($row -match 'Enviado'){ $result.correoEnvio='PASS';$result.correoEstado='Enviado';$result.correoIntentos=0 } else {throw 'CorreoEnvios no alcanzó Enviado con SMTP real.'}
} catch {
  $result.error=($_.Exception.Message -replace '(?i)(password|clave|token|codigo|authorization|cookie)\s*[:=]\s*[^; ,]+','$1=[REDACTED]')
  if($result.smtpDirecto -eq 'NOT_RUN'){$result.smtpDirecto='FAIL'} elseif($result.pedidoApi -eq 'NOT_RUN'){$result.pedidoApi='FAIL'} elseif($result.correoEnvio -eq 'NOT_RUN'){$result.correoEnvio='FAIL'}
} finally {
  $cleanup="DELETE ce FROM dbo.CorreoEnvios ce WHERE ce.IdPedido IN (SELECT IdPedido FROM dbo.Pedidos WHERE Observaciones='$marker'); DELETE dp FROM dbo.DetallePedido dp WHERE dp.IdPedido IN (SELECT IdPedido FROM dbo.Pedidos WHERE Observaciones='$marker'); DELETE pg FROM dbo.Pagos pg WHERE pg.IdPedido IN (SELECT IdPedido FROM dbo.Pedidos WHERE Observaciones='$marker'); DELETE FROM dbo.Pedidos WHERE Observaciones='$marker'; DELETE FROM dbo.TokensCorreo WHERE IdUsuario IN (SELECT IdUsuario FROM dbo.Usuarios WHERE NombreUsuario='$user'); DELETE FROM dbo.Usuarios WHERE NombreUsuario='$user'; DELETE FROM dbo.Clientes WHERE Cedula='$ced';"
  $cleanup += " DELETE FROM dbo.Empleados WHERE Email='$mail' AND Cedula='$ced';"
  try { $null=sqlcmd -S MADRENZO -d LavaFacil -E -C -b -Q $cleanup 2>&1; if($LASTEXITCODE -eq 0){$result.limpieza='PASS'}else{$result.limpieza='FAIL'} } catch {$result.limpieza='FAIL'}
  $result | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $dir 'smtp-real.json')
}
if($result.smtpDirecto -eq 'PASS' -and $result.pedidoApi -eq 'PASS' -and $result.correoEnvio -eq 'PASS' -and $result.limpieza -eq 'PASS'){exit 0}else{exit 1}

