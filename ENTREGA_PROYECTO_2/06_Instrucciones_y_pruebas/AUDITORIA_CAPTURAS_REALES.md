# Auditoría de capturas del 4 de noviembre de 2026

Las imágenes reconstruidas no son evidencias de ejecución y se retiran del manual.

Las nuevas capturas directas se encuentran en `05-Capturas/Reales_20261104`. Se guardaron los bytes de las pantallas devueltas por la captura de ventanas, sin dibujar controles, resultados ni mensajes encima.

## Pruebas realizadas

- CSV originales de Inventario, Usuarios, Recolecciones y DetallePedido abiertos en Bloc de notas.
- Consultas reales de las cuatro tablas en SSMS, con IDs 2001 a 2003.
- Consulta conjunta de las cinco tablas de Ramsés, con tres registros por tabla.
- BULK INSERT real del CSV de Inventario hacia una tabla temporal, con mensajes de ejecución y tres filas consultadas.
- Repetición real del asistente hacia `EvidenciaSSMS20261104.Inventario`, con tres filas transferidas.
- Repeticiones reales con BCP para Usuarios, Recolecciones y DetallePedido en tablas auxiliares vacías: tres filas copiadas en cada una, código de salida 0. Los .txt de salida son stdout original de bcp.exe.
- Verificación mediante sqlcmd.exe: las tres tablas auxiliares mantienen IDs 2001–2003 y referencias NULL correctas. La salida original se conserva como .txt y se captura abierta en Bloc de notas.
- Errores reales de ConnectionString y conversión decimal, conservados como evidencia del diagnóstico.

La repetición del asistente utiliza una tabla auxiliar para no alterar los datos de dbo. Las columnas decimales auxiliares se recibieron como texto y se verificaron con TRY_CONVERT. El proveedor generó IDs auxiliares 1 a 3 y mostró una diferencia de codificación en el nombre acentuado; por tanto esa pantalla demuestra transferencia, pero no se presenta como una recarga idéntica de dbo.Inventario. La consulta de dbo conserva los IDs 2001 a 2003 y los datos del proyecto.

No se afirma que una consulta SELECT demuestre por sí sola cómo se realizó una importación histórica. Las consultas individuales documentan el estado actual de los datos.
