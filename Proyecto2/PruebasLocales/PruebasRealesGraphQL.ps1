param(
    [string]$GraphQlUrl = 'http://127.0.0.1:5125/graphql'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $projectRoot '03-Backend-GraphQL\LavaFacil.GraphQL\appsettings.Development.json'
if (-not (Test-Path -LiteralPath $configPath)) {
    throw 'Falta appsettings.Development.json con las conexiones privadas.'
}

$config = Get-Content -Raw -LiteralPath $configPath | ConvertFrom-Json
$connection = @{}
foreach ($part in ($config.ConnectionStrings.Empleado -split ';')) {
    if ($part -match '=') {
        $pair = $part -split '=', 2
        $connection[$pair[0].Trim()] = $pair[1].Trim()
    }
}

$suffix = Get-Date -Format 'MMddHHmmss'
$temporaryUser = "codex.admin.$suffix"
$temporaryPassword = 'Tmp!' + [guid]::NewGuid().ToString('N')
$token = $null
$userId = $null
$ids = @{}
$results = [System.Collections.Generic.List[string]]::new()

function Invoke-SqlProcedure([string]$Query) {
    & sqlcmd -S $connection['Server'] -d $connection['Initial Catalog'] `
        -U $connection['User ID'] -P $connection['Password'] -C -l 8 -b -Q $Query | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "SQL terminó con código $LASTEXITCODE." }
}

function Invoke-GraphQl([string]$Query, [switch]$Authenticated) {
    $headers = @{}
    if ($Authenticated) { $headers.Authorization = "Bearer $token" }
    $response = Invoke-RestMethod -Uri $GraphQlUrl -Method Post -ContentType 'application/json' `
        -Headers $headers -Body (@{ query = $Query } | ConvertTo-Json -Compress)
    if ($response.errors) { throw (($response.errors.message) -join ' | ') }
    return $response
}

function Confirm-Operation([string]$Query, [string]$Field) {
    $response = Invoke-GraphQl $Query -Authenticated
    $operation = $response.data.$Field
    if (-not $operation.exito) { throw "$Field falló: $($operation.mensaje)" }
    $results.Add("OK $Field")
}

try {
    Invoke-SqlProcedure @"
EXEC dbo.InsertarUsuario
    @NombreUsuario=N'$temporaryUser', @Clave=N'$temporaryPassword',
    @TipoUsuario=N'Administrador', @IdCliente=NULL, @IdEmpleado=2003;
"@

    $rows = & sqlcmd -S $connection['Server'] -d $connection['Initial Catalog'] `
        -U $connection['User ID'] -P $connection['Password'] -C -l 8 -W -s '|' -h -1 `
        -Q 'SET NOCOUNT ON; EXEC dbo.ConsultarUsuarios @TipoConsulta=1;'
    foreach ($line in $rows) {
        $columns = $line -split '\|'
        if ($columns.Count -ge 2 -and $columns[1].Trim() -eq $temporaryUser) {
            $userId = [int]$columns[0].Trim()
            break
        }
    }
    if (-not $userId) { throw 'No fue posible obtener el ID del usuario temporal.' }

    $loginQuery = @"
mutation {
  login(usuario: "$temporaryUser", clave: "$temporaryPassword") {
    exito mensaje token nombreUsuario rol
  }
}
"@
    $login = Invoke-GraphQl $loginQuery
    if (-not $login.data.login.exito) { throw 'El login administrativo temporal fue rechazado.' }
    $token = $login.data.login.token
    $results.Add('OK login Administrador')

    $all = Invoke-GraphQl @'
query {
  clientes { idCliente }
  servicios { idServicio }
  promociones { idPromocion }
  pedidos { idPedido }
  pagos { idPago }
  empleados { idEmpleado }
  usuarios { idUsuario }
  recolecciones { idRecoleccion }
  detallesPedido { idDetalle }
  inventario { idInventario }
}
'@ -Authenticated
    foreach ($name in @('clientes','servicios','promociones','pedidos','pagos','empleados','usuarios','recolecciones','detallesPedido','inventario')) {
        $results.Add("OK consulta $name ($($all.data.$name.Count) filas)")
    }

    $cedula = "GQL-$suffix"
    $email = "gql.$suffix@example.test"
    $serviceName = "Servicio GQL $suffix"
    $promotionName = "Promo GQL $suffix"
    $reference = "GQL-$suffix"

    Confirm-Operation @"
mutation {
  insertarCliente(cedula: "$cedula", nombre: "Prueba", apellidos: "GraphQL",
    telefono: "80000000", email: "$email", direccion: "Temporal") { exito mensaje }
}
"@ 'insertarCliente'
    $query = Invoke-GraphQl '{ clientes { idCliente cedula } }' -Authenticated
    $ids.cliente = ($query.data.clientes | Where-Object cedula -eq $cedula).idCliente
    if (-not $ids.cliente) { throw 'No se encontró el cliente temporal.' }
    Confirm-Operation @"
mutation {
  actualizarCliente(idCliente: $($ids.cliente), cedula: "$cedula", nombre: "Prueba Actualizada",
    apellidos: "GraphQL", telefono: "81111111", email: "$email",
    direccion: "Temporal actualizada") { exito mensaje }
}
"@ 'actualizarCliente'

    Confirm-Operation @"
mutation {
  insertarServicio(nombreServicio: "$serviceName", descripcion: "Temporal", tipoCobro: "Kilogramo",
    precioBase: 500, cantidadIncluida: 1, precioAdicional: 100) { exito mensaje }
}
"@ 'insertarServicio'
    $query = Invoke-GraphQl '{ servicios { idServicio nombreServicio } }' -Authenticated
    $ids.servicio = ($query.data.servicios | Where-Object nombreServicio -eq $serviceName).idServicio
    if (-not $ids.servicio) { throw 'No se encontró el servicio temporal.' }
    Confirm-Operation @"
mutation {
  actualizarServicio(idServicio: $($ids.servicio), nombreServicio: "$serviceName",
    descripcion: "Temporal actualizado", tipoCobro: "Kilogramo", precioBase: 550,
    cantidadIncluida: 1, precioAdicional: 110) { exito mensaje }
}
"@ 'actualizarServicio'

    Confirm-Operation @"
mutation {
  insertarPromocion(idServicio: $($ids.servicio), nombrePromocion: "$promotionName",
    descripcion: "Temporal", porcentajeDescuento: 10,
    fechaInicio: "2026-11-03T00:00:00Z", fechaFin: "2026-12-03T00:00:00Z") { exito mensaje }
}
"@ 'insertarPromocion'
    $query = Invoke-GraphQl '{ promociones { idPromocion nombrePromocion } }' -Authenticated
    $ids.promocion = ($query.data.promociones | Where-Object nombrePromocion -eq $promotionName).idPromocion
    if (-not $ids.promocion) { throw 'No se encontró la promoción temporal.' }
    Confirm-Operation @"
mutation {
  actualizarPromocion(idPromocion: $($ids.promocion), idServicio: $($ids.servicio),
    nombrePromocion: "$promotionName", descripcion: "Temporal actualizada", porcentajeDescuento: 12,
    fechaInicio: "2026-11-03T00:00:00Z", fechaFin: "2026-12-10T00:00:00Z") { exito mensaje }
}
"@ 'actualizarPromocion'

    Confirm-Operation @"
mutation {
  insertarPedido(idCliente: $($ids.cliente), fechaEntregaEstimada: "2026-11-10T12:00:00Z",
    estado: "Pendiente", total: 500, observaciones: "Temporal GraphQL $suffix") { exito mensaje }
}
"@ 'insertarPedido'
    $query = Invoke-GraphQl '{ pedidos { idPedido observaciones } }' -Authenticated
    $ids.pedido = ($query.data.pedidos | Where-Object observaciones -eq "Temporal GraphQL $suffix").idPedido
    if (-not $ids.pedido) { throw 'No se encontró el pedido temporal.' }
    Confirm-Operation @"
mutation {
  actualizarPedido(idPedido: $($ids.pedido), idCliente: $($ids.cliente),
    fechaEntregaEstimada: "2026-11-11T12:00:00Z", estado: "Recibido", total: 500,
    observaciones: "Temporal GraphQL actualizado $suffix") { exito mensaje }
}
"@ 'actualizarPedido'

    Confirm-Operation @"
mutation {
  insertarPago(idPedido: $($ids.pedido), monto: 100, metodoPago: "Efectivo",
    estadoPago: "Pendiente", referencia: "$reference") { exito mensaje }
}
"@ 'insertarPago'
    $query = Invoke-GraphQl '{ pagos { idPago referencia } }' -Authenticated
    $ids.pago = ($query.data.pagos | Where-Object referencia -eq $reference).idPago
    if (-not $ids.pago) { throw 'No se encontró el pago temporal.' }
    Confirm-Operation @"
mutation {
  actualizarPago(idPago: $($ids.pago), idPedido: $($ids.pedido), monto: 120,
    metodoPago: "Efectivo", estadoPago: "Pagado", referencia: "$reference") { exito mensaje }
}
"@ 'actualizarPago'
    $results.Add('OK CRUD real completo')
}
finally {
    if ($token) {
        $cleanup = @(
            @('pago','eliminarPago','idPago'), @('pedido','eliminarPedido','idPedido'),
            @('promocion','eliminarPromocion','idPromocion'), @('servicio','eliminarServicio','idServicio'),
            @('cliente','eliminarCliente','idCliente')
        )
        foreach ($item in $cleanup) {
            $value = $ids[$item[0]]
            if ($value) {
                try {
                    Confirm-Operation "mutation { $($item[1])($($item[2]): $value) { exito mensaje } }" $item[1]
                }
                catch { $results.Add("ERROR limpieza $($item[0]): $($_.Exception.Message)") }
            }
        }
    }
    if ($userId) {
        try {
            Invoke-SqlProcedure "EXEC dbo.EliminarUsuario @IdUsuario=$userId;"
            $results.Add('OK cuenta temporal eliminada')
        }
        catch { $results.Add("ERROR limpieza usuario: $($_.Exception.Message)") }
    }
}

$results
