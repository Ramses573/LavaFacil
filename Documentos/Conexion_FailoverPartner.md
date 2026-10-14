# Configuración de Failover Partner — 11 de octubre de 2026

El aplicativo local usa Microsoft.Data.SqlClient 6.1.1 sobre .NET 9.

Configuración verificada, sin mostrar la contraseña:

```text
Server=100.98.252.109,1433
Database=LavaFacil
User ID=ramses_proyecto
Failover Partner=100.117.134.120,56640
Encrypt=True
TrustServerCertificate=True
```

La contraseña y la cadena completa se conservan cifradas con DPAPI para el usuario de Windows en LavaFacil.Web/Data/connection.dpapi. Se preservó una copia cifrada anterior en la misma carpeta Data. No compartir esos archivos como parte del manual.

## Comprobaciones realizadas

- Nueva cadena de conexión abierta correctamente y leída de nuevo desde el archivo cifrado.
- Servidor efectivo MADRENZO; base LavaFacil; rol PRINCIPAL; estado SYNCHRONIZED.
- Aplicativo iniciado en http://127.0.0.1:5088 y configuración cargada.
- Solicitud de login con cuenta inexistente rechazada con HTTP 401; no se insertaron datos de prueba.
- La aplicación indica que falta crear su primera cuenta administradora. El login SQL ramses_proyecto NO es una cuenta del formulario de acceso de LavaFácil.

## Pendiente antes de la prueba

Crear una cuenta administradora del aplicativo con datos elegidos por el responsable, entrar y capturar la pantalla mostrando MADRENZO. Coordinar una conmutación manual posterior con Rachel, después de confirmar SYNCHRONIZED. Verificar entonces acceso, consultas y operaciones del aplicativo con el servidor de Rachel como principal.

No se ejecutó failover, no se apagaron servidores y no se configuró un testigo. Failover Partner permite que el controlador encuentre el servidor que esté activo; no promueve el espejo ni habilita por sí solo la conmutación automática.

Capturas sugeridas para el manual: estado sincronizado en ambos servidores, aplicativo atendido por MADRENZO antes de la prueba, cambio de roles coordinado, aplicativo atendido por LAPTOP-D0TECCJR\\LAVAFACIL2022 después y sincronización posterior. Esas capturas de conmutación aún no se han realizado.

Referencia: https://learn.microsoft.com/en-us/sql/database-engine/database-mirroring/connect-clients-to-a-database-mirroring-session-sql-server?view=sql-server-ver17
