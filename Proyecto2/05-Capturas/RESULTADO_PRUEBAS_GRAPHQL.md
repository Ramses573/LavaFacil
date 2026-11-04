# Resultado de pruebas reales GraphQL

Fecha de ejecución: 3 de noviembre de 2026.

Servidor GraphQL: `http://127.0.0.1:5125/graphql`

Base de datos: `LavaFacil` mediante la conexión privada configurada localmente.

## Resultado

- Inicio de sesión temporal con rol Administrador: correcto.
- Consultas protegidas de las diez tablas: correctas.
- Consulta pública de Servicios y Promociones: correcta, HTTP 200.
- Inserción, consulta, actualización y eliminación de Clientes: correcta.
- Inserción, consulta, actualización y eliminación de Servicios: correcta.
- Inserción, consulta, actualización y eliminación de Promociones: correcta.
- Inserción, consulta, actualización y eliminación de Pedidos: correcta.
- Inserción, consulta, actualización y eliminación de Pagos: correcta.
- Eliminación de todos los registros temporales: correcta.
- Eliminación de la cuenta administrativa temporal: correcta.

## Evidencia visual

- `GraphQL_Consulta_Publica.jpg`: consulta pública con respuesta HTTP 200.
- `GraphQL/01_Login_Administrador.png`: login correcto y rol Administrador.
- `GraphQL/02_Consultas_Protegidas_10_Tablas.png`: consulta protegida de las diez tablas.
- `GraphQL/03_CRUD_Insertar_Servicio.png`: inserción mediante procedimiento almacenado.
- `GraphQL/04_CRUD_Actualizar_Servicio.png`: actualización mediante procedimiento almacenado.
- `GraphQL/05_CRUD_Eliminar_Servicio.png`: eliminación correcta y limpieza del registro temporal.

## Reproducción segura

Ejecutar `Proyecto2/PruebasLocales/PruebasRealesGraphQL.ps1` con GraphQL iniciado en modo `Development`. El script lee las conexiones privadas desde `appsettings.Development.json`, genera una cuenta temporal con contraseña aleatoria y elimina todos los datos de prueba al finalizar. Ninguna contraseña se guarda en Git.
