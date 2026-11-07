$ErrorActionPreference = 'Stop'
$root = (Get-Location).Path
$evidence = Join-Path $root 'Pruebas\CorreoPedidos-2026-11-06'
$stamp = [DateTime]::UtcNow.ToString('yyyyMMddHHmmssfff')
$user = "qa.focalizado.$stamp"
$pw = 'Temporal-QA-' + [guid]::NewGuid().ToString('N')
$mail = "$user@example.test"
$ref = "QA-FOCAL-$stamp"
$ids = @{}
$checks = @()
$jwt = $null
$proc = $null
function Check($name, $ok, $detail) { $script:checks += [pscustomobject]@{ prueba=$name; estado=if($ok){'PASS'}else{'FAIL'}; detalle=$detail } }
function Sql($q) {
  $r = & sqlcmd -S MADRENZO -d LavaFacil -E -C -I -b -h -1 -W -Q $q 2>&1
  if ($LASTEXITCODE -ne 0) { throw (($r -join "`n")) }
  return @($r)
}
function ScalarInt($q) {
  $lines = Sql $q | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ -match '^\d+$' }
  if (-not $lines) { return 0 }
  return [int]($lines | Select-Object -Last 1)
}
function Graph($query, $token=$null) {
  $headers = @{}
  if ($token) { $headers.Authorization = "Bearer $token" }
  $body = @{ query = $query } | ConvertTo-Json -Compress
  try {
    $r = Invoke-WebRequest -UseBasicParsing -Uri 'http://127.0.0.1:5125/graphql' -Method Post -ContentType 'application/json' -Headers $headers -Body $body
    $content = if ($r.Content -is [byte[]]) { [Text.Encoding]::UTF8.GetString($r.Content) } else { [string]$r.Content }
    return [pscustomobject]@{ Status=[int]$r.StatusCode; Body=$content; Json=($content|ConvertFrom-Json) }
  } catch {
    if ($_.Exception.Response) {
      $resp=$_.Exception.Response; $sr=[IO.StreamReader]::new($resp.GetResponseStream()); $content=$sr.ReadToEnd()
      $json=$null; try{$json=$content|ConvertFrom-Json}catch{}
      return [pscustomobject]@{ Status=[int]$resp.StatusCode; Body=$content; Json=$json }
    }
    throw
  }
}
function Gql($query, $token=$null) {
  $headers = @{}
  if ($token) { $headers.Authorization = "Bearer $token" }
  $body = @{ query = $query } | ConvertTo-Json -Compress
  try {
    $r = Invoke-WebRequest -UseBasicParsing -Uri 'http://127.0.0.1:5125/graphql' -Method Post -ContentType 'application/json' -Headers $headers -Body $body
    $content = if ($r.Content -is [byte[]]) { [Text.Encoding]::UTF8.GetString($r.Content) } else { [string]$r.Content }
    $json = ConvertFrom-Json -InputObject $content
  } catch {
    if ($_.Exception.Response) {
      $resp=$_.Exception.Response; $sr=[IO.StreamReader]::new($resp.GetResponseStream()); $content=$sr.ReadToEnd()
      throw "GraphQL HTTP $([int]$resp.StatusCode): $content"
    }
    throw
  }
  if ($json.errors) { throw (($json.errors | ForEach-Object {$_.message}) -join ' | ') }
  return $json
}
try {
  $setup = "DECLARE @e INT; INSERT dbo.Empleados(Cedula,Nombre,Apellidos,Telefono,Email,Cargo,FechaIngreso) VALUES('QAF$stamp','QA','Focalizado','5551234567','$mail','Administrador',CONVERT(date,GETDATE())); SET @e=SCOPE_IDENTITY(); EXEC dbo.InsertarUsuario @NombreUsuario='$user',@Clave='$pw',@TipoUsuario='Administrador',@IdCliente=NULL,@IdEmpleado=@e; SELECT @e,(SELECT IdUsuario FROM dbo.Usuarios WHERE NombreUsuario='$user');"
  $row = @(& sqlcmd -S MADRENZO -d LavaFacil -E -C -I -b -h -1 -W -s '|' -Q $setup 2>&1) | Where-Object { $_ -match '\|' } | Select-Object -Last 1
  if (-not $row) { throw 'No se obtuvo cuenta temporal.' }
  $parts=$row -split '\|'; $ids.empleado=[int]$parts[0]; $ids.usuario=[int]$parts[1]
  $env:ConnectionStrings__Empleado='Server=MADRENZO;Database=LavaFacil;Integrated Security=True;TrustServerCertificate=True'
  $env:ConnectionStrings__Cliente=$env:ConnectionStrings__Empleado; $env:ConnectionStrings__Invitado=$env:ConnectionStrings__Empleado; $env:ASPNETCORE_URLS='http://127.0.0.1:5125'
  $dll=Join-Path $root 'Proyecto2\03-Backend-GraphQL\LavaFacil.GraphQL\bin\Release\net9.0\LavaFacil.GraphQL.dll'
  $proc=Start-Process dotnet -ArgumentList ('"'+$dll+'"') -WorkingDirectory $root -PassThru -RedirectStandardOutput (Join-Path $evidence 'focalizado-app.log') -RedirectStandardError (Join-Path $evidence 'focalizado-app.err')
  for($i=0;$i -lt 20;$i++){ Start-Sleep -Milliseconds 500; try{$probe=Graph '{ estado }';if($probe.Status -eq 200){break}}catch{} }
  $loginQuery = @"
mutation { login(usuario: "$user", clave: "$pw") { exito mensaje token } }
"@
  $login=Gql $loginQuery
  [IO.File]::WriteAllText((Join-Path $evidence 'focalizado-login-response.json'), ($login | ConvertTo-Json -Depth 8))
  $jwt=$login.data.login.token
  $loginDetail = [pscustomobject]@{ exito=$login.data.login.exito; mensaje=$login.data.login.mensaje; usuario=$user } | ConvertTo-Json -Compress
  Check 'login GraphQL JWT temporal' ([bool]$login.data.login.exito -and [bool]$jwt) $loginDetail
  if (-not $jwt) { throw "No se obtuvo JWT: $($login.data.login.mensaje)" }
  $ced="QAF-C-$stamp"; $svc="QA Focalizado $stamp"
  $clientMutation=('mutation { insertarCliente(cedula: "' + $ced + '" nombre: "QA" apellidos: "Focalizado" telefono: "5551234567" email: "' + $mail + '" direccion: "Temporal") { exito mensaje } }')
  Set-Content (Join-Path $evidence 'focalizado-client-query.txt') ($clientMutation -replace [regex]::Escape($mail),'[redacted]')
  $r=Gql $clientMutation $jwt
  if (-not $r.data.insertarCliente.exito) { throw "insertarCliente: $($r.data.insertarCliente.mensaje)" }
  $clientList=Gql '{ clientes { idCliente cedula } }' $jwt
  Set-Content (Join-Path $evidence 'focalizado-client-list.json') ($clientList | ConvertTo-Json -Depth 8)
  $clientPrefix=$ced.Substring(0,18)
  $ids.cliente=@($clientList.data.clientes | Where-Object { $_.cedula -like "$clientPrefix*" } | Sort-Object idCliente -Descending | Select-Object -First 1 -ExpandProperty idCliente)[0]
  $r=Gql ('mutation { insertarServicio(nombreServicio: "' + $svc + '", descripcion: "Temporal focalizado", tipoCobro: "Kilogramo", precioBase: 123.45, cantidadIncluida: 1, precioAdicional: 0) { exito mensaje } }') $jwt
  if (-not $r.data.insertarServicio.exito) { throw "insertarServicio: $($r.data.insertarServicio.mensaje)" }
  $serviceList=Gql '{ servicios { idServicio nombreServicio } }' $jwt
  $ids.servicio=@($serviceList.data.servicios | Where-Object { $_.nombreServicio -eq $svc } | Select-Object -First 1 -ExpandProperty idServicio)[0]
  $orderMutation=('mutation { insertarPedido(idCliente: ' + $ids.cliente + ' fechaEntregaEstimada: "2026-11-10T12:00:00Z" estado: "Pendiente" total: 123.45 observaciones: "' + $ref + '") { exito mensaje } }')
  Set-Content (Join-Path $evidence 'focalizado-order-query.txt') $orderMutation
  $r=Gql $orderMutation $jwt
  if (-not $r.data.insertarPedido.exito) { throw "insertarPedido: $($r.data.insertarPedido.mensaje)" }
  $orderList=Gql '{ pedidos { idPedido observaciones } }' $jwt
  $ids.pedido=@($orderList.data.pedidos | Where-Object { $_.observaciones -eq $ref } | Select-Object -First 1 -ExpandProperty idPedido)[0]
  $r=Gql ('mutation { insertarDetallePedido(idPedido: ' + $ids.pedido + ', idServicio: ' + $ids.servicio + ', cantidad: 1, precioBase: 123.45, montoAdicional: 0, subtotal: 123.45) { exito mensaje } }') $jwt
  $r=Gql ('mutation { insertarPago(idPedido: ' + $ids.pedido + ', monto: 123.45, metodoPago: "Efectivo", estadoPago: "Pendiente", referencia: "' + $ref + '") { exito mensaje } }') $jwt
  if (-not $r.data.insertarPago.exito) { throw "insertarPago: $($r.data.insertarPago.mensaje)" }
  $paymentList=Gql '{ pagos { idPago referencia } }' $jwt
  $ids.pago=@($paymentList.data.pagos | Where-Object { $_.referencia -eq $ref } | Select-Object -First 1 -ExpandProperty idPago)[0]
  Check 'pedido y pago temporales tienen IDs reales' ([bool]$ids.pedido -and [bool]$ids.pago) ("idPedido=$($ids.pedido); idPago=$($ids.pago)")
  $mutation=('mutation { actualizarPago(idPago: ' + $ids.pago + ', idPedido: ' + $ids.pedido + ', monto: 123.45, metodoPago: "Efectivo", estadoPago: "Pagado", referencia: "' + $ref + '") { exito mensaje } }')
  $update=Graph $mutation $jwt
  [IO.File]::WriteAllText((Join-Path $evidence 'actualizar-pago-focalizado-response.json'), $update.Body)
  Check 'ActualizarPago HTTP response captured' $true ("HTTP $($update.Status); body completo en actualizar-pago-focalizado-response.json")
  $body=$update.Body
  $success=($update.Status -eq 200 -and $update.Json.data.actualizarPago.exito)
  Check 'ActualizarPago con IDs reales' $success ("HTTP $($update.Status); $body")
  if ($success) {
    $q=(Sql "SET NOCOUNT ON; SELECT p.IdPago,p.IdPedido,p.Monto,p.MetodoPago,p.EstadoPago,p.Referencia,ce.IdEnvio,ce.Tipo,ce.ClaveUnica,ce.Estado,ce.DatosJson FROM dbo.Pagos p LEFT JOIN dbo.CorreoEnvios ce ON ce.IdPago=p.IdPago WHERE p.IdPago=$($ids.pago) FOR JSON PATH;") -join ''
    Check 'Pago quedó Pagado y EML/CorreoEnvios asociado' ($q -match 'Pagado' -and $q -match 'ComprobantePago') $q
    $repeat=Graph $mutation $jwt
    $q2=(Sql "SET NOCOUNT ON; SELECT COUNT(*) AS N FROM dbo.CorreoEnvios WHERE IdPago=$($ids.pago) AND Tipo='ComprobantePago';") -join ''
    Check 'repetición no duplica CorreoEnvios' ($repeat.Status -eq 200 -and $q2 -match '1') ("repeat=$($repeat.Body); count=$q2")
    $r2=Gql "mutation { insertarPedido(idCliente: $($ids.cliente), fechaEntregaEstimada: `"2026-11-10T12:00:00Z`", estado: `"Pendiente`", total: 20, observaciones: `"$ref-CRUZADO`") { exito mensaje } }" $jwt
    $other=(Gql '{ pedidos { idPedido observaciones } }' $jwt).data.pedidos | Where-Object observaciones -eq "$ref-CRUZADO" | Select-Object -ExpandProperty idPedido
    $cross=Graph "mutation { actualizarPago(idPago: $($ids.pago), idPedido: $other, monto: 123.45, metodoPago: `"Tarjeta`", estadoPago: `"Pagado`", referencia: `"$ref`") { exito mensaje } }" $jwt
    Check 'ID cruzado rechazado' ($cross.Status -eq 200 -and -not $cross.Json.data.actualizarPago.exito) $cross.Body
    $ids.otroPedido=$other
  }
} catch { Check 'flujo focalizado' $false $_.Exception.Message }
finally {
  try { if($proc){Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue} } catch {}
  try { Sql "DELETE FROM dbo.CorreoEnvios WHERE IdPago IN (SELECT IdPago FROM dbo.Pagos WHERE Referencia='$ref') OR IdPedido IN (SELECT IdPedido FROM dbo.Pedidos WHERE Observaciones LIKE '$ref%'); DELETE FROM dbo.Pagos WHERE Referencia='$ref' OR IdPedido IN (SELECT IdPedido FROM dbo.Pedidos WHERE Observaciones LIKE '$ref%'); DELETE FROM dbo.DetallePedido WHERE IdPedido IN (SELECT IdPedido FROM dbo.Pedidos WHERE Observaciones LIKE '$ref%'); DELETE FROM dbo.Pedidos WHERE Observaciones LIKE '$ref%'; DELETE FROM dbo.Servicios WHERE NombreServicio='$svc'; DELETE FROM dbo.Clientes WHERE Cedula='$ced'; DELETE FROM dbo.TokensCorreo WHERE IdUsuario IN (SELECT IdUsuario FROM dbo.Usuarios WHERE NombreUsuario='$user'); DELETE FROM dbo.Usuarios WHERE NombreUsuario='$user'; DELETE FROM dbo.Empleados WHERE Email='$mail';" | Out-Null; Check 'limpieza MADRENZO' $true 'pedido, pago, detalle, correo, servicio, cliente, usuario y empleado temporales eliminados' } catch { Check 'limpieza MADRENZO' $false $_.Exception.Message }
  $checks | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 (Join-Path $evidence 'actualizar-pago-focalizado.json')
}
