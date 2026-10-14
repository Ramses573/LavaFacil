# Entrega de base de datos LavaFacil

## Tres requisitos completados

1. Las diez tablas tienen tres registros cada una, 30 en total. Los datos añadidos son ficticios y persistentes para la entrega; no son el registro temporal ID 7 que se eliminó después de la conmutación. Se conservó la cuenta real ramses.aguilar y su perfil. Las dos cuentas demo de Usuarios permanecen inactivas para no dar acceso al aplicativo.
2. Se conservaron las diez consultas parametrizadas creadas por Rachel. Cada una recibe @TipoConsulta: 1 devuelve la tabla completa; 2 filtra por el ID correspondiente. Se ejecutaron 30 comprobaciones: tabla completa, ID existente e ID inexistente para cada tabla. No hizo falta reemplazar ni agregar procedimientos; continúan existiendo 50 SPs.
3. SQL/LavaFacil_Final.sql incluye estructuras, restricciones, datos, 50 procedimientos y dos triggers. Se generó con el asistente Generar scripts de SSMS 22, seleccionando todas las tablas y procedimientos, Esquema y datos e Incluir desencadenadores=True. Se comprobó su reconstrucción en una base temporal de SQL Express 2022 en la laptop. Se verificaron conteos de objetos, datos (excepto las claves sanitizadas), consultas, restricciones y funcionamiento de ambos triggers. Las bases temporales creadas para validar fueron eliminadas.

## Archivo a entregar

Usar `SQL/LavaFacil_Final.sql`. Es una copia del exportado desde SSMS con dos adaptaciones declaradas: protección contra ejecutar sobre una base que ya tiene objetos y sustitución de las claves de Usuarios por valores nuevos solamente en el archivo. La contraseña de la cuenta real en MADRENZO no fue modificada.

Para reconstruir, abrirlo en SSMS en una instancia de pruebas y habilitar **Consulta > Modo SQLCMD** antes de ejecutar. Crea LavaFacil si no existe y se detiene si ya contiene tablas, SPs o triggers. No ejecutarlo sobre MADRENZO/LavaFacil ni sobre el espejo actual. Después de reconstruir, establecer una clave propia para la cuenta administradora de la copia antes de usarla; las claves del archivo no son las claves originales. Mantener inactivas las cuentas ficticias.

La exportación exacta de SSMS se conserva cifrada con DPAPI en `LavaFacil.Web/Data/ExportacionesPrivadas/LavaFacil_SSMS_20261011.dpapi`, solo recuperable por este usuario de Windows. No compartir Data ni ese archivo privado. El archivo temporal sin cifrar de SSMS se retiró después de preservar la copia cifrada.

El archivo final contiene el perfil personal solicitado para la cuenta administradora. Compartirlo solo con Rachel y con el docente/canal del proyecto, no publicarlo.

## Evidencias y archivos complementarios

- `Pruebas/Requisitos_Finales/Verificacion_Consultas.json`: resultados de las 30 pruebas.
- `Pruebas/Requisitos_Finales/Verificacion_ScriptFinal.json`: objetos, conteos, hashes de la entrega y reconstrucción.
- `Scripts_Usados/02_Procedimientos_App/04_Datos_Entrega.sql`: script aplicado para completar los registros sin borrar ni sustituir los existentes.
- `Scripts_Usados/02_Procedimientos_App/05_Ejemplos_Consultas.sql`: ejemplos de parámetros.
- `Scripts_Usados/05_Pruebas_y_Limpieza/Verification`: ejecutor y verificador de la exportación.

La tabla Usuarios y los SPs CRUD heredados usan Clave en texto plano; esto es una limitación del diseño académico actual, no una práctica para producción. No mostrar claves en capturas ni publicar resultados de ConsultarUsuarios.

El script de estructuras y datos NO instala SQL Server, crea certificados/endpoints ni configura Firewall o Mirroring. Esos elementos de servidor se documentan por separado. Los nuevos datos se aplicaron con el principal sincronizado al iniciar la carga. En la comprobación final del trabajo el espejo apareció DISCONNECTED, con MADRENZO ONLINE y PRINCIPAL; queda pendiente confirmar con Rachel que su equipo, Tailscale y SQL Server estén en ejecución y comprobar la resincronización. No se debe restaurar ni recrear el espejo por esta desconexión sin diagnosticar primero.

## Pendientes fuera de estos tres puntos

Manual técnico, archivo de video y revisión de la demostración exigida por el docente. La prueba realizada hasta ahora fue una conmutación manual; no documentarla como caída real ni failover automático con testigo.
