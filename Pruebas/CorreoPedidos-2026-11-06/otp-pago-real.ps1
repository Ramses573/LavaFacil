$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$evidence = $PSScriptRoot
$outbox = Join-Path $env:TEMP 'opencode\lavafacil-mail-outbox'
$stamp = [DateTime]::UtcNow.ToString('yyyyMMddHHmmssfff')
$user = "qa.pago.$stamp"
$password = 'Temporal-QA-' + ([guid]::NewGuid().ToString('N'))
# Clave de reset de fixture generada en tiempo de ejecución; no se versiona ningún valor real.
$newPass = if($env:LAVAFACIL_TEST_PASSWORD){$env:LAVAFACIL_TEST_PASSWORD}else{'Temporal-' + [guid]::NewGuid().ToString('N') + '!Aa1'}
$email = "$user@example.test"
$ref = "QA-REF-$stamp"
$checks = [System.Collections.Generic.List[object]]::new()
$ids = @{}
$graphqlProcess = $null

function Check($name, $ok, $detail) { $checks.Add([pscustomobject]@{ prueba=$name; estado=if($ok){'PASS'}else{'HUECO'}; detalle=$detail }) }
function Sql($q) { $r = & sqlcmd -S MADRENZO -d LavaFacil -E -C -I -b -h -1 -W -Q $q 2>&1; if($LASTEXITCODE -ne 0){ throw (($r -join "`n")) }; return $r }
function Gql($query, $token=$null) {
  $h=@{}; if($token){$h.Authorization="Bearer $token"}
  $body=@{query=$query}|ConvertTo-Json -Compress
  try { return (Invoke-WebRequest -UseBasicParsing -Uri 'http://127.0.0.1:5125/graphql' -Method Post -ContentType 'application/json' -Headers $h -Body $body).Content|ConvertFrom-Json }
  catch { $detail=$_.Exception.Message; if($_.ErrorDetails.Message){$detail += ' body=' + $_.ErrorDetails.Message}; return [pscustomobject]@{ errors=@([pscustomobject]@{message=$detail}) } }
}
function IdFrom($rows, $column, $value) { foreach($line in $rows){$p=$line -split '\|';if($p.Count -ge 2 -and $p[1].Trim() -eq $value){return [int]$p[0].Trim()}};return $null }

try {
  # OTP: el formato actual pone Codigo en el cuerpo MIME, no en headers.
  $web = New-Object Microsoft.PowerShell.Commands.WebRequestSession
  $b = Invoke-WebRequest -UseBasicParsing -WebSession $web http://127.0.0.1:5088/api/bootstrap
  $csrf = ($b.Content|ConvertFrom-Json).token
  $reg = @{identity="Q$stamp";name='QA';lastName='OTP';phone='5551234567';email=$email;address='Temporal';username=$user;password=$password}|ConvertTo-Json -Compress
  Invoke-WebRequest -UseBasicParsing -WebSession $web -Method Post -Uri http://127.0.0.1:5088/api/register -Headers @{'X-CSRF-TOKEN'=$csrf} -ContentType 'application/json' -Body $reg | Out-Null
  $before=@(Get-ChildItem $outbox -Filter *.eml -ErrorAction SilentlyContinue|% FullName)
  $b = Invoke-WebRequest -UseBasicParsing -WebSession $web http://127.0.0.1:5088/api/bootstrap; $csrf=($b.Content|ConvertFrom-Json).token
  $rec=@{identificador=$email}|ConvertTo-Json -Compress
  Invoke-WebRequest -UseBasicParsing -WebSession $web -Method Post -Uri http://127.0.0.1:5088/api/email/recuperacion/solicitar -Headers @{'X-CSRF-TOKEN'=$csrf} -ContentType 'application/json' -Body $rec | Out-Null
  Start-Sleep -Milliseconds 300
  $f=@(Get-ChildItem $outbox -Filter *.eml|?{ $before -notcontains $_.FullName -and (Get-Content -Raw $_.FullName) -match [regex]::Escape($email)})|Sort-Object LastWriteTime|Select-Object -Last 1
  $txt=if($f){Get-Content -Raw $f.FullName}else{''}; $code=[regex]::Match($txt,'(?im)^Codigo:\s*(\d{6})\s*$').Groups[1].Value
  Check 'OTP recuperacion extraÃ­do de Codigo en cuerpo' ($code.Length -eq 6) "eml=$($f.Name); codigoLongitud=$($code.Length); headerOtp=$($txt -match '(?im)^X-LavaFacil-Codigo\s*:')"
  $b = Invoke-WebRequest -UseBasicParsing -WebSession $web http://127.0.0.1:5088/api/bootstrap; $csrf=($b.Content|ConvertFrom-Json).token
  $reset=@{identificador=$email;codigo=$code;nuevaClave=$newPass}|ConvertTo-Json -Compress
  $rr=Invoke-WebRequest -UseBasicParsing -WebSession $web -Method Post -Uri http://127.0.0.1:5088/api/email/recuperacion/restablecer -Headers @{'X-CSRF-TOKEN'=$csrf} -ContentType 'application/json' -Body $reset
  Check 'recuperacion/reset continÃºa PASS' ($rr.StatusCode -eq 200 -and $code.Length -eq 6) "status=$($rr.StatusCode)"
  # No se reutiliza la sesión web para GraphQL; el resto del flujo usa sólo la cuenta staff temporal.

  # Cuenta de personal temporal creada sÃ³lo con la ruta segura existente; no se usan credenciales reales.
  $setup = "DECLARE @e INT; INSERT dbo.Empleados(Cedula,Nombre,Apellidos,Telefono,Email,Cargo,FechaIngreso) VALUES('QA$stamp','QA','Pago','5551234567','$email','Administrador',CONVERT(date,GETDATE())); SET @e=SCOPE_IDENTITY(); EXEC dbo.InsertarUsuario @NombreUsuario='$user',@Clave='$password',@TipoUsuario='Administrador',@IdCliente=NULL,@IdEmpleado=@e; SELECT @e AS IdEmpleado,(SELECT IdUsuario FROM dbo.Usuarios WHERE NombreUsuario='$user') AS IdUsuario;"
  $row=@(& sqlcmd -S MADRENZO -d LavaFacil -E -C -I -b -h -1 -W -s '|' -Q $setup 2>&1)|?{$_ -match '\|'}|Select-Object -Last 1; if(-not $row){throw 'No se obtuvo la fila de la cuenta temporal'}; $parts=$row -split '\|'; $ids.empleado=[int]$parts[0].Trim();$ids.usuario=[int]$parts[1].Trim()
  $envVars=@{ConnectionStrings__Empleado='Server=MADRENZO;Database=LavaFacil;Integrated Security=True;TrustServerCertificate=True';ConnectionStrings__Cliente='Server=MADRENZO;Database=LavaFacil;Integrated Security=True;TrustServerCertificate=True';ConnectionStrings__Invitado='Server=MADRENZO;Database=LavaFacil;Integrated Security=True;TrustServerCertificate=True';ASPNETCORE_URLS='http://127.0.0.1:5125'}
  $psi=[Diagnostics.ProcessStartInfo]::new('dotnet',(Join-Path $root 'Proyecto2\03-Backend-GraphQL\LavaFacil.GraphQL\bin\Release\net9.0\LavaFacil.GraphQL.dll'));$psi.WorkingDirectory=Join-Path $root 'Proyecto2\03-Backend-GraphQL\LavaFacil.GraphQL';$psi.UseShellExecute=$false;$psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true;foreach($kv in $envVars.GetEnumerator()){$psi.Environment[$kv.Key]=$kv.Value};$graphqlProcess=[Diagnostics.Process]::Start($psi);Start-Sleep -Seconds 3
  $login=Gql "mutation { login(usuario: `"$user`", clave: `"$password`") { exito token mensaje } }"; $jwt=$login.data.login.token
  Check 'login GraphQL con JWT temporal' ($login.data.login.exito -and $jwt) "exito=$($login.data.login.exito)"
  if(-not $jwt){ throw "No se obtuvo JWT temporal: $($login|ConvertTo-Json -Compress)" }
  $ced="QAC$stamp";$svc="QA Servicio $stamp"
  $x=Gql "mutation { insertarCliente(cedula: `"$ced`", nombre: `"QA`", apellidos: `"Pago`", telefono: `"5551234567`", email: `"$email`", direccion: `"Temporal`") { exito mensaje } }" $jwt
  $clients=Gql '{ clientes { idCliente cedula } }' $jwt;$ids.cliente=($clients.data.clientes|? cedula -eq $ced).idCliente
  $x=Gql "mutation { insertarServicio(nombreServicio: `"$svc`", descripcion: `"Temporal`", tipoCobro: `"Servicio`", precioBase: 100, cantidadIncluida: 1, precioAdicional: 0) { exito mensaje } }" $jwt
  $services=Gql '{ servicios { idServicio nombreServicio } }' $jwt;$ids.servicio=($services.data.servicios|? nombreServicio -eq $svc).idServicio
  $x=Gql "mutation { insertarPedido(idCliente: $($ids.cliente), fechaEntregaEstimada: `"2026-11-10T12:00:00Z`", estado: `"Pendiente`", total: 123.45, observaciones: `"$ref`") { exito mensaje } }" $jwt
  $orders=Gql '{ pedidos { idPedido observaciones } }' $jwt;$ids.pedido=($orders.data.pedidos|? observaciones -eq $ref).idPedido
  $x=Gql "mutation { insertarDetallePedido(idPedido: $($ids.pedido), idServicio: $($ids.servicio), cantidad: 1, precioBase: 123.45, montoAdicional: 0, subtotal: 123.45) { exito mensaje } }" $jwt
  $x=Gql "mutation { insertarPago(idPedido: $($ids.pedido), monto: 123.45, metodoPago: `"Tarjeta`", estadoPago: `"Pendiente`", referencia: `"$ref`") { exito mensaje } }" $jwt
  $payments=Gql '{ pagos { idPago referencia idPedido } }' $jwt;$ids.pago=($payments.data.pagos|? referencia -eq $ref).idPago
  $pay="mutation { actualizarPago(idPago: $($ids.pago), idPedido: $($ids.pedido), monto: 123.45, metodoPago: `"Tarjeta`", estadoPago: `"Pagado`", referencia: `"$ref`") { exito mensaje } }"
  $first=Gql $pay $jwt;Start-Sleep -Seconds 12
  $q="SET NOCOUNT ON; SELECT p.IdPedido,p.Estado,ce.Tipo,ce.Estado AS EstadoCorreo,ce.DatosJson FROM dbo.Pagos p LEFT JOIN dbo.CorreoEnvios ce ON ce.IdPago=p.IdPago WHERE p.IdPago=$($ids.pago) FOR JSON PATH;";$obs=(Sql $q)-join ''
  $second=Gql $pay $jwt;$count=[regex]::Matches($obs,'ComprobantePago|PagoConfirmado').Count
  $okFirst=$first.data.actualizarPago.exito;$okState=$obs -match 'Pagado';$okOne=($count -eq 1)
  Check 'ActualizarPago real transiciona a Pagado' ($okFirst -and $okState) "respuesta=$($first.data.actualizarPago.exito); sql=$obs"
  Check 'CorreoEnvios/EML de pago Ãºnico y datos completos' $okOne "tiposEncontrados=$count; se esperaba exactamente 1; sql=$obs"
  $emls=@(Get-ChildItem $outbox -Filter *.eml -ErrorAction SilentlyContinue|?{(Get-Content -Raw $_.FullName) -match [regex]::Escape($ref) -and (Get-Content -Raw $_.FullName) -match 'Monto'})
  $etxt=if($emls){Get-Content -Raw $emls[0].FullName}else{''};Check 'EML pago monto/metodo/referencia' ($etxt -match '123' -and $etxt -match 'Tarjeta' -and $etxt -match [regex]::Escape($ref)) "emlCount=$($emls.Count)"
  Check 'repetir Pagado no duplica' ($second.data.actualizarPago.exito -and $count -eq 1) "segundaRespuesta=$($second.data.actualizarPago.exito); conteoCorreo=$count"
  $other=Gql "mutation { insertarPedido(idCliente: $($ids.cliente), fechaEntregaEstimada: `"2026-11-10T12:00:00Z`", estado: `"Pendiente`", total: 20, observaciones: `"$ref-OTRO`") { exito mensaje } }" $jwt;$orders=Gql '{ pedidos { idPedido observaciones } }' $jwt;$ids.otroPedido=($orders.data.pedidos|? observaciones -eq "$ref-OTRO").idPedido
  $wrong=Gql "mutation { actualizarPago(idPago: $($ids.pago), idPedido: $($ids.otroPedido), monto: 123.45, metodoPago: `"Tarjeta`", estadoPago: `"Pagado`", referencia: `"$ref`") { exito mensaje } }" $jwt
  Check 'pago perteneciente a otro pedido rechaza' (-not $wrong.data.actualizarPago.exito) "exito=$($wrong.data.actualizarPago.exito); mensaje=$($wrong.data.actualizarPago.mensaje)"
}
catch { Check 'ejecucion real de pago' $false $_.Exception.Message }
finally {
  if($graphqlProcess){try{$graphqlProcess.Kill();$graphqlProcess.WaitForExit(3000)}catch{}}
  # Limpieza acotada por las claves Ãºnicas de esta ejecuciÃ³n; no toca cuentas reales.
  try { Sql "DELETE FROM dbo.CorreoEnvios WHERE IdPago IN (SELECT IdPago FROM dbo.Pagos WHERE Referencia='$ref') OR IdPedido IN (SELECT IdPedido FROM dbo.Pedidos WHERE Observaciones LIKE '$ref%'); DELETE FROM dbo.Pagos WHERE Referencia='$ref' OR IdPedido IN (SELECT IdPedido FROM dbo.Pedidos WHERE Observaciones LIKE '$ref%'); DELETE FROM dbo.DetallePedido WHERE IdPedido IN (SELECT IdPedido FROM dbo.Pedidos WHERE Observaciones LIKE '$ref%'); DELETE FROM dbo.Pedidos WHERE Observaciones LIKE '$ref%'; DELETE FROM dbo.TokensCorreo WHERE IdUsuario IN (SELECT IdUsuario FROM dbo.Usuarios WHERE NombreUsuario='$user'); DELETE FROM dbo.Usuarios WHERE NombreUsuario='$user'; DELETE FROM dbo.Empleados WHERE Email='$email';" | Out-Null } catch { Check 'limpieza BD temporal' $false $_.Exception.Message }
  $left=(@(Sql "SELECT (SELECT COUNT(*) FROM dbo.Usuarios WHERE NombreUsuario='$user') U,(SELECT COUNT(*) FROM dbo.Empleados WHERE Email='$email') E,(SELECT COUNT(*) FROM dbo.Pedidos WHERE Observaciones LIKE '$ref%') P,(SELECT COUNT(*) FROM dbo.DetallePedido d JOIN dbo.Pedidos p ON p.IdPedido=d.IdPedido WHERE p.Observaciones LIKE '$ref%') D,(SELECT COUNT(*) FROM dbo.Pagos WHERE Referencia='$ref') G,(SELECT COUNT(*) FROM dbo.CorreoEnvios WHERE ClaveUnica LIKE 'pago:%') C;" ) -join ' ')
  Check 'limpieza temporal U/E/P/D/Pago/CorreoEnvios' ($left -match '\b0\b') "resultado=$left"
  $checks|ConvertTo-Json -Depth 5|Set-Content (Join-Path $evidence 'otp-pago-real.json')
}

