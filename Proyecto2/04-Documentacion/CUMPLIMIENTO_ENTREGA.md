# Revisión final de cumplimiento del Proyecto 2

Fecha de revisión: 3 de noviembre de 2026.

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

La evidencia del Asistente muestra directamente la carga exitosa de Empleados. Para Inventario, Usuarios, Recolecciones y DetallePedido el manual presenta el archivo de origen y la verificación consolidada en SSMS. Si la profesora exige una pantalla independiente del último paso del asistente para cada tabla, esas cuatro capturas deben tomarse durante la demostración; no se sustituyeron con imágenes inventadas.

## Orden de entrega recomendado

1. Manual final en PDF y Word.
2. Script `00_LavaFacil_Proyecto2_ENTREGA_FINAL.sql` junto con los módulos de `01-Script`.
3. Carpeta `02-Datos-Carga` con los diez CSV.
4. Carpeta `03-Backend-GraphQL` con el código completo.
5. Carpeta `05-Capturas` con las evidencias originales.
