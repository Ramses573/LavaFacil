# LavaFácil — Proyecto 2 de Bases de Datos Avanzadas

Solución preparada para carga masiva y acceso mediante GraphQL. El backend se desarrolló con ASP.NET Core 9, Hot Chocolate y Microsoft.Data.SqlClient. Las consultas y mutaciones no escriben SQL directo: invocan los procedimientos almacenados de `LavaFacil`.

## Contenido

- `01-Script`: estructura, datos base, procedimientos, triggers, seguridad por roles y verificación.
- `02-Datos-Carga`: diez archivos CSV con tres registros ficticios por tabla.
- `03-Backend-GraphQL`: API GraphQL con consulta y CRUD de las diez tablas.
- `04-Documentacion`: instrucciones de instalación, carga, pruebas y plantilla de evidencias.
- `05-Capturas`: carpetas donde se guardan las evidencias reales.

## Orden obligatorio de preparación

1. Ejecutar `01_LavaFacil_Estructura_Datos_SP_Triggers.sql` únicamente en una base nueva.
2. Ejecutar `02_Mejoras_Aplicativo.sql`.
3. Crear en SQL Server los tres logins privados `lava_gql_invitado`, `lava_gql_cliente` y `lava_gql_empleado`.
4. Ejecutar `03_Seguridad_GraphQL.sql`.
5. Cargar los CSV respetando el orden indicado en `04-Documentacion/GUIA_CARGA_MASIVA.md`.
6. Copiar `appsettings.Development.example.json` como `appsettings.Development.json` y completar las tres cadenas sin subir ese archivo a Git.
7. En la carpeta del proyecto GraphQL ejecutar `dotnet restore` y `dotnet run`.
8. Abrir la dirección mostrada por la consola y agregar `/graphql` para usar Nitro.

## División acordada

- Rachel — BCP: Clientes, Servicios, Promociones, Pedidos y Pagos.
- Ramses — Asistente de importación de SSMS: Empleados, Inventario, Usuarios, Recolecciones y DetallePedido.

Los archivos de prueba usan identificadores desde 2001. Antes de cargarlos, confirmar que esos identificadores no existan. Las cuentas ficticias del CSV están desactivadas y sus claves son únicamente datos de laboratorio.

## Estado técnico

El proyecto compila sin advertencias ni errores. La verificación contra la base real requiere configurar localmente las cadenas de conexión y ejecutar las cargas en el servidor principal. Después de terminar las cargas, el script final de estructura y datos debe regenerarse desde SSMS para que contenga el estado definitivo solicitado por la rúbrica.
