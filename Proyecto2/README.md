# LavaFácil — Proyecto 2 de Bases de Datos Avanzadas

Solución preparada para carga masiva y acceso mediante GraphQL. El backend se desarrolló con ASP.NET Core 9, Hot Chocolate y Microsoft.Data.SqlClient. Las consultas y mutaciones no escriben SQL directo: invocan los procedimientos almacenados de `LavaFacil`.

## Contenido

- `01-Script`: script único de entrega, estructura, datos, procedimientos, triggers, seguridad por roles y verificación.
- `02-Datos-Carga`: diez archivos CSV con tres registros ficticios por tabla.
- `03-Backend-GraphQL`: API GraphQL con consulta y CRUD de las diez tablas.
- `04-Documentacion`: instrucciones de instalación, carga, pruebas y plantilla de evidencias.
- `05-Capturas`: carpetas donde se guardan las evidencias reales.

## Orden obligatorio de preparación

1. Para reconstruir toda la entrega en una base nueva, ejecutar `00_LavaFacil_Proyecto2_ENTREGA_FINAL.sql` directamente desde SSMS.
2. Para demostrar la carga masiva en clase, utilizar los CSV y seguir el orden indicado en `04-Documentacion/GUIA_CARGA_MASIVA.md`; no sustituir esa demostración por el script final.
3. Crear en SQL Server los tres logins privados `lava_gql_invitado`, `lava_gql_cliente` y `lava_gql_empleado`. Sus contraseñas no forman parte del repositorio.
4. Ejecutar nuevamente `03_Seguridad_GraphQL.sql` después de crear los logins para asociarlos con los roles.
5. Copiar `appsettings.Development.example.json` como `appsettings.Development.json` y completar las tres cadenas sin subir ese archivo a Git.
6. En la carpeta del proyecto GraphQL ejecutar `dotnet restore` y `dotnet run`.
7. Abrir la dirección mostrada por la consola y agregar `/graphql` para usar Nitro.

## Servidor principal para el avance

Para el Proyecto 2 se utilizará una única instancia, sin mirroring, replicación ni `Failover Partner`:

- Equipo principal: laptop de Ramses.
- Servidor para conexiones remotas: `100.70.40.33,1433`.
- Instancia local: `DESKTOP-EEOH9C5\SQLEXPRESS`.
- Base de datos: `LavaFacil`.
- Acceso remoto: exclusivamente mediante Tailscale.

El archivo `01-Script/05_Finalizar_Laptop_Principal.ps1` fija la regla de Firewall para permitir el puerto 1433 únicamente desde la IP Tailscale autorizada de Rachel y reinicia SQL Server Express. Debe ejecutarse como administrador en la laptop principal. El script no contiene contraseñas.

Las credenciales y `appsettings.Development.json` son configuraciones privadas de cada equipo y no deben publicarse en Git.

## División acordada

- Rachel — BCP: Clientes, Servicios, Promociones, Pedidos y Pagos.
- Ramses — Asistente de importación de SSMS: Empleados, Inventario, Usuarios, Recolecciones y DetallePedido.

Los archivos de prueba usan identificadores desde 2001. Antes de cargarlos, confirmar que esos identificadores no existan. Las cuentas ficticias del CSV están desactivadas y sus claves son únicamente datos de laboratorio.

## Orden coordinado de carga

1. Ramses: Empleados e Inventario.
2. Rachel: Clientes, Servicios y Promociones mediante BCP.
3. Ramses: Usuarios, después de Clientes.
4. Rachel: Pedidos, después de Clientes.
5. Ramses: Recolecciones, después de Pedidos.
6. Ramses: DetallePedido, después de Pedidos y Servicios.
7. Rachel: Pagos, después de Pedidos.

Cada carga debe conservar las evidencias exigidas por la rúbrica: archivo de origen, configuración del método, mapeo, resultado de tres filas y consulta de verificación de los identificadores 2001–2003.

## Estado técnico

- Las diez tablas tienen sus tres registros de prueba 2001–2003 en el servidor principal.
- La evidencia de Ramses incluye una carga real mediante el Asistente de importación de SSMS, los cinco archivos de origen y la consulta final de sus cinco tablas.
- Los estados de `Recolecciones` se ajustaron al `CHECK`: `Programada`, `Recolectada` y `Cancelada`.
- Los tres logins privados de GraphQL se crean únicamente en SQL Server; sus contraseñas permanecen fuera del repositorio.
- Los roles `gql_invitado`, `gql_cliente` y `gql_empleado` fueron verificados mediante procedimientos almacenados autorizados.
- El backend fue compilado y probado con consultas y operaciones CRUD reales.
- El manual final unificado está disponible en Word y PDF con las evidencias de BCP, SSMS y GraphQL.
- Los archivos vigentes de entrega son `04-Documentacion/Manual_Proyecto2_LavaFacil_COMPLETO.docx` y `04-Documentacion/Manual_Proyecto2_LavaFacil_COMPLETO.pdf`.
- El script `00_LavaFacil_Proyecto2_ENTREGA_FINAL.sql` es autónomo e integra estructura, procedimientos, datos, seguridad y verificaciones. No requiere modo SQLCMD ni rutas externas.

La revisión final de entregables y las observaciones de demostración se encuentran en `04-Documentacion/CUMPLIMIENTO_ENTREGA.md`.
