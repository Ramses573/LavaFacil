# Pruebas GraphQL

## Estado y consultas públicas

```graphql
query {
  estado
  servicios { idServicio nombreServicio tipoCobro precioBase activo }
  promociones { idPromocion nombrePromocion porcentajeDescuento fechaInicio fechaFin activa }
}
```

## Login

```graphql
mutation {
  login(usuario: "USUARIO_APLICATIVO", clave: "CLAVE_APLICATIVO") {
    exito mensaje token idUsuario nombreUsuario rol
  }
}
```

Agregar el token al encabezado `Authorization: Bearer TOKEN` antes de continuar.

## Consultar las diez tablas

```graphql
query {
  clientes { idCliente cedula nombre apellidos activo }
  empleados { idEmpleado cedula nombre cargo activo }
  usuarios { idUsuario nombreUsuario tipoUsuario activo }
  servicios { idServicio nombreServicio precioBase activo }
  pedidos { idPedido idCliente estado total }
  detallesPedido { idDetalle idPedido idServicio cantidad subtotal }
  pagos { idPago idPedido monto metodoPago estadoPago }
  recolecciones { idRecoleccion idPedido direccion estado }
  promociones { idPromocion idServicio nombrePromocion porcentajeDescuento activa }
  inventario { idInventario nombreProducto cantidad unidadMedida cantidadMinima }
}
```

## Ejemplo de ciclo CRUD

```graphql
mutation {
  insertarServicio(nombreServicio:"Prueba GraphQL", descripcion:"Eliminar al terminar", tipoCobro:"Unidad", precioBase:1000, cantidadIncluida:1, precioAdicional:0) { exito mensaje }
}
```

Consultar servicios para identificar el `idServicio` creado. Luego:

```graphql
mutation {
  actualizarServicio(idServicio:ID_OBTENIDO, nombreServicio:"Prueba GraphQL actualizada", descripcion:"Prueba CRUD", tipoCobro:"Unidad", precioBase:1200, cantidadIncluida:1, precioAdicional:0) { exito mensaje }
}
```

```graphql
mutation {
  eliminarServicio(idServicio:ID_OBTENIDO) { exito mensaje }
}
```

El mismo patrón está disponible para Clientes, Empleados, Usuarios, Pedidos, DetallePedido, Pagos, Recolecciones, Promociones e Inventario. Nitro muestra los argumentos exactos en la pestaña Schema/Docs.
