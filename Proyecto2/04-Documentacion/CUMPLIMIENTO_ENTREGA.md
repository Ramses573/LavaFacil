# Revisión final de cumplimiento del Proyecto 2

Fecha de revisión: 4 de noviembre de 2026.

La auditoría vigente es `AUDITORIA_CAPTURAS_REALES.md`. Las imágenes reconstruidas se retiraron y se sustituyeron por capturas directas. Las nuevas cargas se ejecutaron en tablas auxiliares para conservar dbo; no se presentan como evidencia histórica de importación a dbo.

## Resultado general

El repositorio contiene los componentes técnicos solicitados: archivos de carga, uso documentado de BCP y del Asistente de SSMS, procedimientos almacenados, seguridad por roles, tres cadenas de conexión configurables, API GraphQL, consultas y CRUD de las diez tablas, script final y manual de evidencias en Word y PDF.

## Matriz de cumplimiento

| Requisito | Evidencia en el repositorio | Estado |
|---|---|---|
| Utilizar BCP al menos una vez | Cinco CSV de Rachel, comandos BCP y capturas de ejecución | Cumple |
| Utilizar el Asistente de SSMS al menos una vez | Captura real de la carga de Empleados con tres filas transferidas | Cumple |
| Cargar las diez tablas | Diez CSV y verificación de los identificadores 2001 a 2003 | Cumple |
| Respetar las llaves foráneas | Orden coordinado de carga documentado | Cumple |
| Documentar archivo, ejecución y resultado | Manual final con evidencias BCP, SSMS y consultas finales | Cumple con evidencia consolidada |
| GraphQL para las diez tablas | `Query.cs`, `Mutation.cs` y modelos de las diez entidades | Cumple |
| Agregar, modificar, eliminar y consultar | Treinta mutaciones y diez consultas generales | Cumple |
| Usar procedimientos almacenados | `DbGateway` ejecuta los procedimientos `Consultar`, `Insertar`, `Actualizar` y `Eliminar` | Cumple |
| Login devuelve el rol | Mutación `login` devuelve `nombreUsuario`, `rol` y token | Cumple |
| Seguridad mediante conexiones diferentes | Cadenas `Invitado`, `Cliente` y `Empleado` | Cumple |
| Entregar archivos originales | Diez CSV incluidos en `02-Datos-Carga` | Cumple |
| Entregar código de la API | Proyecto ASP.NET Core y archivos de prueba incluidos | Cumple |
| Script final con estructuras y datos | `00_LavaFacil_Proyecto2_ENTREGA_FINAL.sql` | Cumple |
| Documento de evidencias | Manual final en DOCX y PDF | Cumple |

## Controles técnicos realizados

- Los diez CSV contienen tres filas y no presentan incompatibilidades de formato.
- El script de estructura contiene las diez tablas y cuarenta procedimientos almacenados.
- Las mutaciones GraphQL cubren insertar, actualizar y eliminar en las diez tablas.
- Las consultas GraphQL generales cubren las diez tablas y existen consultas parametrizadas para las cinco tablas asignadas a Rachel.
- Las credenciales privadas se mantienen en `appsettings.Development.json`, archivo ignorado por Git.
- El repositorio solo publica `appsettings.Development.example.json` con valores de reemplazo.
- Las capturas de GraphQL muestran login administrativo, consultas protegidas e inserción, actualización y eliminación.

## Observación para la demostración

Se conserva la evidencia original del asistente de Empleados. Se agregaron capturas directas de los cuatro CSV y consultas individuales de dbo. Se repitió Inventario con el asistente y las otras tres tablas con BCP en tablas auxiliares. Las salidas BCP muestran tres filas copiadas y SQLCMD confirma IDs 2001–2003 y NULL correctos. La repetición auxiliar del asistente generó IDs 1–3 y presentó una diferencia de codificación; el manual lo indica expresamente. BULK INSERT se documenta como prueba adicional real hacia una tabla temporal. No debe afirmarse que una carga auxiliar demuestra una importación histórica a dbo.

## Orden de entrega recomendado

1. Manual final en PDF y Word.
2. Script `00_LavaFacil_Proyecto2_ENTREGA_FINAL.sql` junto con los módulos de `01-Script`.
3. Carpeta `02-Datos-Carga` con los diez CSV.
4. Carpeta `03-Backend-GraphQL` con el código completo.
5. Carpeta `05-Capturas` con las evidencias originales.
