# Entrega del Proyecto 2 LavaFácil

Integrantes: José Ramsés Aguilar y Rachel Rosales.

Esta carpeta contiene los cuatro entregables pedidos en Tarea programada 2.

1. **01_Base_de_datos**: script final de estructura, datos, procedimientos y seguridad.
2. **02_Manual**: manual de evidencias en Word y PDF, con 53 imágenes. Leer las incidencias de las repeticiones auxiliares tal como están documentadas.
3. **03_Codigo_APIs**: código fuente del backend ASP.NET Core GraphQL para las diez tablas; utiliza procedimientos almacenados y conexiones por rol.
4. **04_Archivos_originales_de_carga**: diez CSV originales, separados por responsable.

Se agregan **05_Evidencias_reales**, con capturas directas y salidas originales, y **06_Instrucciones_y_pruebas**, con instrucciones, consultas, colección Postman y scripts de las pruebas adicionales.

## Ejecutar las API

Instalar .NET SDK 9. Entrar a `03_Codigo_APIs\LavaFacil.GraphQL`, copiar `appsettings.Development.example.json` a `appsettings.Development.json` y completar en privado las tres conexiones contra la instancia que tenga LavaFacil. Ejecutar `dotnet restore` y `dotnet run`. Abrir la URL mostrada en la consola agregando `/graphql`. Las consultas y la colección Postman se encuentran en `06_Instrucciones_y_pruebas`.

La configuración privada, las claves de protección, bin y obj no se incluyen. El código fuente sí está completo.

## Alcance de las evidencias

El manual distingue las verificaciones de dbo de las repeticiones nuevas en tablas auxiliares. La repetición del asistente de Inventario transfirió tres filas, pero produjo IDs auxiliares y una diferencia de codificación que se indican en el documento. Las tres repeticiones BCP verificaron IDs 2001–2003 y NULL correctos. BULK INSERT es una prueba adicional real en tabla temporal; el enunciado exige utilizar el asistente y BCP al menos una vez cada uno.

## Lugar de entrega indicado por la profesora

Directorio **entregable Proyecto 2**, dentro del canal del grupo en Microsoft Teams. El documento fija el miércoles 4 de noviembre de 2026, a más tardar a las 9 a.m. La demostración de los servicios se realiza en clase.

El ZIP contiene esta misma carpeta. Revisar el manifiesto SHA256 para comprobar los archivos.
