# LavaFácil — miniaplicativo de Ramses

Archivos del proyecto en el Escritorio. Los tres originales están en Documentos, sin modificar.

## Iniciar

1. En SSMS, conectado a MADRENZO, ejecutar SQL/01_Procedimientos_App.sql. Complementa la base existente; no elimina tablas ni reemplaza usp_ValidarLogin ni triggers.
2. Abrir Iniciar.cmd. Requiere .NET 9 SDK (ya instalado en esta laptop).
3. Abrir http://127.0.0.1:5088 en el navegador.
4. Configurar la conexión con el usuario SQL ramses_proyecto y SU contraseña. La clave maestra del mirroring no es necesariamente la contraseña de ese login.
5. Si no existe ninguna cuenta en dbo.Usuarios, completar la pantalla «Crea tu cuenta de administrador». Tú eliges los datos y contraseña; la app crea el empleado y su cuenta en una transacción. La pantalla deja de estar disponible en cuanto existe una cuenta. No se crean datos ficticios automáticamente.
6. Iniciar sesión con una cuenta activa de dbo.Usuarios. Esta cuenta de aplicación es diferente del login SQL.

La configuración se verifica antes de guardarse. La contraseña SQL queda cifrada con Windows DPAPI para el usuario de Windows actual en LavaFacil.Web/Data/connection.dpapi. No compartir ese archivo ni la carpeta Data. Para cambiar la conexión: detener la app, renombrar connection.dpapi a connection.dpapi.anterior y reiniciar para repetir la configuración.

## Funciones

- Login mediante dbo.usp_ValidarLogin; cookie HttpOnly, controles de CSRF y cierre de sesión.
- Inicio con contadores reales y estado del servidor.
- Servicios consultados mediante SP.
- Empleado/Administrador: consulta y registro de clientes mediante SP, validaciones y tratamiento de duplicados.
- Cliente: consulta de servicios y su propio perfil; sin acceso a clientes ajenos.
- Perfil: nombre, apellidos, teléfono y correo reales, modificables. No permite cambiar roles ni identificadores.
- Todas las consultas muestran @@SERVERNAME y DB_NAME de la MISMA conexión que atendió la operación.
- Si cambia el servidor entre dos operaciones exitosas, aparece una notificación real de cambio.
- La app solo escucha en localhost y rechaza otros nombres de host.

## Mirroring pendiente

La app admite Failover Partner, pero debe indicarse la dirección SQL real del espejo una vez configurado por Rachel. El campo puede quedar vacío mientras solo exista el principal. No se ha demostrado conmutación ni se simula un servidor secundario.
En ambos servidores debe existir el login SQL con el mismo SID y contraseña, permisos adecuados y la base correctamente sincronizada. Una operación de escritura fallida no se reintenta automáticamente para evitar duplicados; verificar el registro antes de repetirla. Reintentar la consulta con Actualizar después de una conmutación.

## Seguridad y límites

Para este laboratorio se usa cifrado de transporte con TrustServerCertificate=true: no valida la identidad del certificado. En producción usar un certificado verificable. La clave de dbo.Usuarios se compara según el SP existente (texto plano); migrar a hashes con sal antes de producción. El login SQL de la app debe tener solo EXECUTE de los procedimientos necesarios en producción, no db_owner.
El perfil del administrador corresponde a la cuenta realmente autenticada, no a un nombre fijo del diseño.
La carga completa de tres registros por cada tabla, exportación final, configuración del Mirror y documentación/video siguen en la parte de Rachel.
