import json
from pathlib import Path

OUT = Path(__file__).with_name("LavaFacil_GraphQL.postman_collection.json")


def request(name, query, *, auth=True, description="", tests=None, variables=""):
    headers = [{"key": "Content-Type", "value": "application/json"}]
    if auth:
        headers.append({"key": "Authorization", "value": "Bearer {{token}}"})
    events = []
    scripts = [
        "pm.test('HTTP 200', () => pm.response.to.have.status(200));",
        "const respuesta = pm.response.json();",
        "pm.test('Sin errores GraphQL', () => pm.expect(respuesta.errors).to.eql(undefined));",
    ]
    if tests:
        scripts.extend(tests)
    events.append({"listen": "test", "script": {"type": "text/javascript", "exec": scripts}})
    return {
        "name": name,
        "event": events,
        "request": {
            "method": "POST",
            "header": headers,
            "body": {"mode": "graphql", "graphql": {"query": query, "variables": variables}},
            "url": {"raw": "{{baseUrl}}", "host": ["{{baseUrl}}"]},
            "description": description,
        },
    }


def operation_tests(field):
    return [
        f"pm.test('Operación {field} exitosa', () => pm.expect(respuesta.data.{field}.exito).to.eql(true));",
        f"console.log(respuesta.data.{field}.mensaje);",
    ]


def capture_tests(list_field, id_field, variable, predicate):
    return [
        f"const fila = respuesta.data.{list_field}.filter(x => {predicate}).sort((a,b) => b.{id_field} - a.{id_field})[0];",
        f"pm.test('Registro insertado localizado', () => pm.expect(fila).to.not.eql(undefined));",
        f"if (fila) pm.collectionVariables.set('{variable}', fila.{id_field});",
        f"if (fila) console.log('{variable} = ' + fila.{id_field});",
    ]


def folder(name, list_query, insert_query, capture_query, capture_args, update_query, delete_query, sp_names):
    list_field, id_field, variable, predicate = capture_args
    return {
        "name": name,
        "description": "Consulta y mutaciones CRUD respaldadas por procedimientos almacenados de SQL Server.",
        "item": [
            request("1. Consultar", list_query, description=f"Consulta mediante {sp_names[0]}."),
            request("2. Insertar", insert_query, description=f"Inserción mediante {sp_names[1]}.", tests=operation_tests(sp_names[4][0])),
            request(
                "3. Consultar y guardar ID insertado",
                capture_query,
                description="Comprueba el INSERT y guarda el ID para las operaciones siguientes.",
                tests=capture_tests(list_field, id_field, variable, predicate),
            ),
            request("4. Actualizar", update_query, description=f"Actualización mediante {sp_names[2]}.", tests=operation_tests(sp_names[4][1])),
            request("5. Eliminar", delete_query, description=f"Eliminación mediante {sp_names[3]}.", tests=operation_tests(sp_names[4][2])),
        ],
    }


login_admin = request(
    "1.1 Login Administrador y guardar token",
    """mutation LoginAdministrador {
  login(usuario: \"admin_p2_01\", clave: \"DemoTemporal2026!3\") {
    exito mensaje idUsuario nombreUsuario rol token
  }
}""",
    auth=False,
    description="Valida el usuario mediante usp_ValidarLogin y guarda el token para toda la colección.",
    tests=[
        "pm.test('Login exitoso', () => pm.expect(respuesta.data.login.exito).to.eql(true));",
        "pm.test('Rol Administrador', () => pm.expect(respuesta.data.login.rol).to.eql('Administrador'));",
        "if (respuesta.data.login.token) pm.collectionVariables.set('token', respuesta.data.login.token);",
    ],
)

auth_folder = {
    "name": "01 - Autenticación y roles",
    "item": [
        login_admin,
        request(
            "1.2 Login Cliente",
            "mutation { login(usuario: \"cliente_p2_01\", clave: \"DemoTemporal2026!1\") { exito mensaje rol token } }",
            auth=False,
            tests=["pm.test('Rol Cliente', () => pm.expect(respuesta.data.login.rol).to.eql('Cliente'));"],
        ),
        request(
            "1.3 Login Empleado",
            "mutation { login(usuario: \"empleado_p2_01\", clave: \"DemoTemporal2026!2\") { exito mensaje rol token } }",
            auth=False,
            tests=["pm.test('Rol Empleado', () => pm.expect(respuesta.data.login.rol).to.eql('Empleado'));"],
        ),
        request(
            "1.4 Login con credenciales privadas",
            "mutation LoginPrivado($usuario: String!, $clave: String!) { login(usuario: $usuario, clave: $clave) { exito mensaje idUsuario nombreUsuario rol token } }",
            auth=False,
            variables='{"usuario":"{{usuarioPrivado}}","clave":"{{clavePrivada}}"}',
            description="Permite usar una cuenta privada sin guardar la contraseña directamente en la operación.",
            tests=["if (respuesta.data.login.token) pm.collectionVariables.set('token', respuesta.data.login.token);"],
        ),
    ],
}

public_folder = {
    "name": "02 - Consultas públicas",
    "item": [
        request("2.1 Estado de la API", "query { estado }", auth=False),
        request("2.2 Servicios", "query { servicios { idServicio nombreServicio descripcion tipoCobro precioBase cantidadIncluida precioAdicional activo } }", auth=False),
        request("2.3 Promociones", "query { promociones { idPromocion idServicio nombrePromocion descripcion porcentajeDescuento fechaInicio fechaFin activa } }", auth=False),
    ],
}

all_tables = request(
    "3.1 Consultar las diez tablas",
    """query ConsultarDiezTablas {
  clientes { idCliente cedula nombre apellidos telefono email direccion fechaRegistro activo }
  empleados { idEmpleado cedula nombre apellidos telefono email cargo fechaIngreso activo }
  usuarios { idUsuario nombreUsuario tipoUsuario idCliente idEmpleado activo fechaCreacion }
  servicios { idServicio nombreServicio descripcion tipoCobro precioBase cantidadIncluida precioAdicional activo }
  pedidos { idPedido idCliente fechaPedido fechaEntregaEstimada estado total observaciones }
  detallesPedido { idDetalle idPedido idServicio cantidad precioBase montoAdicional subtotal }
  pagos { idPago idPedido fechaPago monto metodoPago estadoPago referencia }
  recolecciones { idRecoleccion idPedido direccion fechaProgramada estado observaciones }
  promociones { idPromocion idServicio nombrePromocion descripcion porcentajeDescuento fechaInicio fechaFin activa }
  inventario { idInventario nombreProducto descripcion cantidad unidadMedida cantidadMinima fechaActualizacion activo }
}""",
    description="Comprueba en una petición el acceso de lectura a las diez tablas.",
)

crud = []

crud.append(folder(
    "04.1 - Clientes",
    "query { clientes { idCliente cedula nombre apellidos telefono email direccion activo } }",
    "mutation { insertarCliente(cedula: \"DEMO-POSTMAN-C001\", nombre: \"Cliente\", apellidos: \"Demostracion Postman\", telefono: \"70000001\", email: \"cliente.postman@demo.local\", direccion: \"Turrialba\") { exito mensaje } }",
    "query { clientes { idCliente cedula nombre apellidos telefono email direccion activo } }",
    ("clientes", "idCliente", "idClienteDemo", "x.cedula === 'DEMO-POSTMAN-C001'"),
    "mutation { actualizarCliente(idCliente: {{idClienteDemo}}, cedula: \"DEMO-POSTMAN-C001\", nombre: \"Cliente Actualizado\", apellidos: \"Demostracion Postman\", telefono: \"70000002\", email: \"cliente.postman@demo.local\", direccion: \"Cartago\") { exito mensaje } }",
    "mutation { eliminarCliente(idCliente: {{idClienteDemo}}) { exito mensaje } }",
    ("ConsultarClientes", "InsertarCliente", "ActualizarCliente", "EliminarCliente", ("insertarCliente", "actualizarCliente", "eliminarCliente")),
))

crud.append(folder(
    "04.2 - Empleados",
    "query { empleados { idEmpleado cedula nombre apellidos telefono email cargo fechaIngreso activo } }",
    "mutation { insertarEmpleado(cedula: \"DEMO-POSTMAN-E001\", nombre: \"Empleado\", apellidos: \"Demostracion Postman\", telefono: \"71000001\", email: \"empleado.postman@demo.local\", cargo: \"Operador\", fechaIngreso: \"2026-11-17T08:00:00\") { exito mensaje } }",
    "query { empleados { idEmpleado cedula nombre apellidos telefono email cargo fechaIngreso activo } }",
    ("empleados", "idEmpleado", "idEmpleadoDemo", "x.cedula === 'DEMO-POSTMAN-E001'"),
    "mutation { actualizarEmpleado(idEmpleado: {{idEmpleadoDemo}}, cedula: \"DEMO-POSTMAN-E001\", nombre: \"Empleado Actualizado\", apellidos: \"Demostracion Postman\", telefono: \"71000002\", email: \"empleado.postman@demo.local\", cargo: \"Supervisor\", fechaIngreso: \"2026-11-17T08:00:00\") { exito mensaje } }",
    "mutation { eliminarEmpleado(idEmpleado: {{idEmpleadoDemo}}) { exito mensaje } }",
    ("ConsultarEmpleados", "InsertarEmpleado", "ActualizarEmpleado", "EliminarEmpleado", ("insertarEmpleado", "actualizarEmpleado", "eliminarEmpleado")),
))

crud.append(folder(
    "04.3 - Usuarios",
    "query { usuarios { idUsuario nombreUsuario tipoUsuario idCliente idEmpleado activo fechaCreacion } }",
    "mutation { insertarUsuario(nombreUsuario: \"usuario_postman_demo\", clave: \"DemoTemporal2026!9\", tipoUsuario: \"Empleado\", idCliente: null, idEmpleado: {{idEmpleadoBase}}) { exito mensaje } }",
    "query { usuarios { idUsuario nombreUsuario tipoUsuario idCliente idEmpleado activo fechaCreacion } }",
    ("usuarios", "idUsuario", "idUsuarioDemo", "x.nombreUsuario === 'usuario_postman_demo'"),
    "mutation { actualizarUsuario(idUsuario: {{idUsuarioDemo}}, nombreUsuario: \"usuario_postman_demo\", clave: \"DemoTemporal2026!8\", tipoUsuario: \"Empleado\", idCliente: null, idEmpleado: {{idEmpleadoBase}}) { exito mensaje } }",
    "mutation { eliminarUsuario(idUsuario: {{idUsuarioDemo}}) { exito mensaje } }",
    ("ConsultarUsuarios", "InsertarUsuario", "ActualizarUsuario", "EliminarUsuario", ("insertarUsuario", "actualizarUsuario", "eliminarUsuario")),
))

crud.append(folder(
    "04.4 - Servicios",
    "query { servicios { idServicio nombreServicio descripcion tipoCobro precioBase cantidadIncluida precioAdicional activo } }",
    "mutation { insertarServicio(nombreServicio: \"Servicio Postman Demo\", descripcion: \"Registro temporal\", tipoCobro: \"Unidad\", precioBase: 3500, cantidadIncluida: 1, precioAdicional: 0) { exito mensaje } }",
    "query { servicios { idServicio nombreServicio descripcion tipoCobro precioBase cantidadIncluida precioAdicional activo } }",
    ("servicios", "idServicio", "idServicioDemo", "x.nombreServicio === 'Servicio Postman Demo'"),
    "mutation { actualizarServicio(idServicio: {{idServicioDemo}}, nombreServicio: \"Servicio Postman Actualizado\", descripcion: \"Registro temporal actualizado\", tipoCobro: \"Unidad\", precioBase: 4200, cantidadIncluida: 1, precioAdicional: 0) { exito mensaje } }",
    "mutation { eliminarServicio(idServicio: {{idServicioDemo}}) { exito mensaje } }",
    ("ConsultarServicios", "InsertarServicio", "ActualizarServicio", "EliminarServicio", ("insertarServicio", "actualizarServicio", "eliminarServicio")),
))

crud.append(folder(
    "04.5 - Pedidos",
    "query { pedidos { idPedido idCliente fechaPedido fechaEntregaEstimada estado total observaciones } }",
    "mutation { insertarPedido(idCliente: {{idClienteBase}}, fechaEntregaEstimada: \"2026-12-01T15:00:00\", estado: \"Recibido\", total: 3500, observaciones: \"Pedido temporal Postman\") { exito mensaje } }",
    "query { pedidos { idPedido idCliente fechaPedido fechaEntregaEstimada estado total observaciones } }",
    ("pedidos", "idPedido", "idPedidoDemo", "x.observaciones === 'Pedido temporal Postman'"),
    "mutation { actualizarPedido(idPedido: {{idPedidoDemo}}, idCliente: {{idClienteBase}}, fechaEntregaEstimada: \"2026-12-02T15:00:00\", estado: \"En proceso\", total: 4200, observaciones: \"Pedido temporal Postman actualizado\") { exito mensaje } }",
    "mutation { eliminarPedido(idPedido: {{idPedidoDemo}}) { exito mensaje } }",
    ("ConsultarPedidos", "InsertarPedido", "ActualizarPedido", "EliminarPedido", ("insertarPedido", "actualizarPedido", "eliminarPedido")),
))

crud.append(folder(
    "04.6 - DetallePedido",
    "query { detallesPedido { idDetalle idPedido idServicio cantidad precioBase montoAdicional subtotal } }",
    "mutation { insertarDetallePedido(idPedido: {{idPedidoBase}}, idServicio: {{idServicioBase}}, cantidad: 1, precioBase: 1500, montoAdicional: 0, subtotal: 1500) { exito mensaje } }",
    "query { detallesPedido { idDetalle idPedido idServicio cantidad precioBase montoAdicional subtotal } }",
    ("detallesPedido", "idDetalle", "idDetalleDemo", "x.idPedido === Number(pm.collectionVariables.get('idPedidoBase')) && x.idServicio === Number(pm.collectionVariables.get('idServicioBase')) && x.subtotal === 1500"),
    "mutation { actualizarDetallePedido(idDetalle: {{idDetalleDemo}}, idPedido: {{idPedidoBase}}, idServicio: {{idServicioBase}}, cantidad: 2, precioBase: 1500, montoAdicional: 0, subtotal: 3000) { exito mensaje } }",
    "mutation { eliminarDetallePedido(idDetalle: {{idDetalleDemo}}) { exito mensaje } }",
    ("ConsultarDetallePedido", "InsertarDetallePedido", "ActualizarDetallePedido", "EliminarDetallePedido", ("insertarDetallePedido", "actualizarDetallePedido", "eliminarDetallePedido")),
))

crud.append(folder(
    "04.7 - Pagos",
    "query { pagos { idPago idPedido fechaPago monto metodoPago estadoPago referencia } }",
    "mutation { insertarPago(idPedido: {{idPedidoBase}}, monto: 1500, metodoPago: \"Efectivo\", estadoPago: \"Completado\", referencia: \"POSTMAN-PAGO-DEMO\") { exito mensaje } }",
    "query { pagos { idPago idPedido fechaPago monto metodoPago estadoPago referencia } }",
    ("pagos", "idPago", "idPagoDemo", "x.referencia === 'POSTMAN-PAGO-DEMO'"),
    "mutation { actualizarPago(idPago: {{idPagoDemo}}, idPedido: {{idPedidoBase}}, monto: 1750, metodoPago: \"Tarjeta\", estadoPago: \"Completado\", referencia: \"POSTMAN-PAGO-DEMO\") { exito mensaje } }",
    "mutation { eliminarPago(idPago: {{idPagoDemo}}) { exito mensaje } }",
    ("ConsultarPagos", "InsertarPago", "app_ActualizarPagoSeguro", "EliminarPago", ("insertarPago", "actualizarPago", "eliminarPago")),
))

crud.append(folder(
    "04.8 - Recolecciones",
    "query { recolecciones { idRecoleccion idPedido direccion fechaProgramada estado observaciones } }",
    "mutation { insertarRecoleccion(idPedido: {{idPedidoBase}}, direccion: \"Turrialba centro\", fechaProgramada: \"2026-12-03T09:00:00\", estado: \"Programada\", observaciones: \"POSTMAN-RECOLECCION-DEMO\") { exito mensaje } }",
    "query { recolecciones { idRecoleccion idPedido direccion fechaProgramada estado observaciones } }",
    ("recolecciones", "idRecoleccion", "idRecoleccionDemo", "x.observaciones === 'POSTMAN-RECOLECCION-DEMO'"),
    "mutation { actualizarRecoleccion(idRecoleccion: {{idRecoleccionDemo}}, idPedido: {{idPedidoBase}}, direccion: \"Cartago centro\", fechaProgramada: \"2026-12-04T10:00:00\", estado: \"Confirmada\", observaciones: \"POSTMAN-RECOLECCION-DEMO\") { exito mensaje } }",
    "mutation { eliminarRecoleccion(idRecoleccion: {{idRecoleccionDemo}}) { exito mensaje } }",
    ("ConsultarRecolecciones", "InsertarRecoleccion", "ActualizarRecoleccion", "EliminarRecoleccion", ("insertarRecoleccion", "actualizarRecoleccion", "eliminarRecoleccion")),
))

crud.append(folder(
    "04.9 - Promociones",
    "query { promociones { idPromocion idServicio nombrePromocion descripcion porcentajeDescuento fechaInicio fechaFin activa } }",
    "mutation { insertarPromocion(idServicio: {{idServicioBase}}, nombrePromocion: \"Promocion Postman Demo\", descripcion: \"Registro temporal\", porcentajeDescuento: 10, fechaInicio: \"2026-11-17T00:00:00\", fechaFin: \"2026-12-31T23:59:59\") { exito mensaje } }",
    "query { promociones { idPromocion idServicio nombrePromocion descripcion porcentajeDescuento fechaInicio fechaFin activa } }",
    ("promociones", "idPromocion", "idPromocionDemo", "x.nombrePromocion === 'Promocion Postman Demo'"),
    "mutation { actualizarPromocion(idPromocion: {{idPromocionDemo}}, idServicio: {{idServicioBase}}, nombrePromocion: \"Promocion Postman Actualizada\", descripcion: \"Registro temporal actualizado\", porcentajeDescuento: 15, fechaInicio: \"2026-11-17T00:00:00\", fechaFin: \"2026-12-31T23:59:59\") { exito mensaje } }",
    "mutation { eliminarPromocion(idPromocion: {{idPromocionDemo}}) { exito mensaje } }",
    ("ConsultarPromociones", "InsertarPromocion", "ActualizarPromocion", "EliminarPromocion", ("insertarPromocion", "actualizarPromocion", "eliminarPromocion")),
))

crud.append(folder(
    "04.10 - Inventario",
    "query { inventario { idInventario nombreProducto descripcion cantidad unidadMedida cantidadMinima fechaActualizacion activo } }",
    "mutation { insertarInventario(nombreProducto: \"Producto Postman Demo\", descripcion: \"Registro temporal\", cantidad: 20, unidadMedida: \"Unidad\", cantidadMinima: 5) { exito mensaje } }",
    "query { inventario { idInventario nombreProducto descripcion cantidad unidadMedida cantidadMinima fechaActualizacion activo } }",
    ("inventario", "idInventario", "idInventarioDemo", "x.nombreProducto === 'Producto Postman Demo'"),
    "mutation { actualizarInventario(idInventario: {{idInventarioDemo}}, nombreProducto: \"Producto Postman Actualizado\", descripcion: \"Registro temporal actualizado\", cantidad: 25, unidadMedida: \"Unidad\", cantidadMinima: 6) { exito mensaje } }",
    "mutation { eliminarInventario(idInventario: {{idInventarioDemo}}) { exito mensaje } }",
    ("ConsultarInventario", "InsertarInventario", "ActualizarInventario", "EliminarInventario", ("insertarInventario", "actualizarInventario", "eliminarInventario")),
))

variables = [
    ("baseUrl", "http://localhost:5125/graphql"), ("token", ""),
    ("usuarioPrivado", ""), ("clavePrivada", ""),
    ("idClienteBase", "2001"), ("idEmpleadoBase", "2001"), ("idServicioBase", "2001"), ("idPedidoBase", "2001"),
]
for var in ["idClienteDemo", "idEmpleadoDemo", "idUsuarioDemo", "idServicioDemo", "idPedidoDemo", "idDetalleDemo", "idPagoDemo", "idRecoleccionDemo", "idPromocionDemo", "idInventarioDemo"]:
    variables.append((var, "0"))

collection = {
    "info": {
        "_postman_id": "b3e4f79a-1122-48cd-92a1-lavafacilgql-completa",
        "name": "LavaFacil GraphQL - Proyecto 2 - Colección completa",
        "description": "Pruebas de autenticación, roles, consultas y CRUD para las diez tablas. Las mutaciones invocan procedimientos almacenados desde el backend GraphQL.",
        "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json",
    },
    "variable": [{"key": k, "value": v, "type": "string"} for k, v in variables],
    "item": [auth_folder, public_folder, {"name": "03 - Verificación conjunta", "item": [all_tables]}, {"name": "04 - CRUD por tabla", "item": crud}],
}

OUT.write_text(json.dumps(collection, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(OUT)
