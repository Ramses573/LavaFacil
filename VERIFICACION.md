# Verificación — 11 de octubre de 2026

Aplicación compilada con .NET 9: cero errores y cero advertencias.
JavaScript revisado con node --check: correcto.
Conexión real desde la laptop a SQL Server por Tailscale comprobada. Servidor: MADRENZO. Base: LavaFacil.

## Pruebas realizadas

Ocho pruebas mediante procedimientos almacenados, con registros temporales y transacción revertida:

1. Login válido de administrador asociado a un empleado activo.
2. Resumen de los datos reales.
3. Consulta de servicios permitida al cliente.
4. Consulta de clientes permitida al administrador.
5. Registro de cliente persiste los datos esperados dentro de la transacción.
6. Edición del perfil actualiza únicamente el empleado de esa cuenta.
7. Consulta de clientes ajenos denegada al cliente.
8. Cuenta desactivada pierde acceso a su perfil.

Dos comprobaciones de cuenta inicial, dentro de una transacción revertida:

9. La primera cuenta se vincula al empleado administrador creado.
10. Crear otra cuenta por ese mecanismo se rechaza cuando ya existe un usuario.

Seis comprobaciones HTTP:

11–14. Inicio, servicios, clientes y perfil sin sesión: HTTP 401.
15. Envío de login sin token CSRF: HTTP 400.
16. Credenciales de aplicación inválidas con token válido: HTTP 401.

Tras las pruebas: cero usuarios, clientes y servicios reales; cero transacciones abiertas. No quedaron los registros temporales. Las identidades pueden avanzar aunque se revierta una transacción, comportamiento normal de SQL Server.

## Recorrido completo de interfaz — completado

A petición del usuario, se crearon datos temporales reales en MADRENZO/LavaFacil y se recorrió la aplicación en el navegador, sin simular consultas ni servidores.

34 comprobaciones de interfaz y 32 comprobaciones adicionales HTTP/SQL pasaron:

- Login con contraseña incorrecta y correcta; mostrar/ocultar contraseña.
- Administrador: inicio con contadores reales, comprobar conexión, consulta y actualización de servicios.
- Servicio inactivo excluido de la consulta.
- Registro: campos obligatorios, correo inválido, cancelación sin guardar, registro correcto, rechazo de duplicados, búsqueda por cédula y contador actualizado.
- Perfil de administrador: datos de la cuenta real, edición de nombre, apellidos, teléfono y correo; persistencia después de recargar y cabecera actualizada.
- Empleado: login con rol correcto, consulta y acceso al formulario de registro.
- Cliente: sin menú de gestión, bloqueo del acceso directo a clientes, consulta de servicios, edición de su propio perfil y persistencia.
- Cierre de sesión y comprobación después de recargar.
- API directa: restricciones por rol, cliente no puede registrar, validación de correo, rechazo de escrituras sin token CSRF y rechazo de acceso después de logout.
- SQL confirma todos los campos del cliente registrado y del perfil editado; el duplicado no creó otra fila.
- Sin errores ni advertencias de JavaScript en el navegador durante el recorrido.

### Fallo encontrado y corregido con autorización

La validación CSRF se ejecutaba antes de recuperar la identidad de la cookie. Los formularios autenticados respondían «La sesión del formulario venció». Se movió UseAuthentication antes del middleware que valida CSRF, manteniendo esa protección. Tras recompilar sin errores ni advertencias, registro, edición de perfil y logout funcionaron desde la interfaz; las solicitudes sin CSRF siguieron rechazándose.

Observación visual menor: al entrar, antes de terminar la primera consulta de inicio, la fecha de conexión puede aparecer momentáneamente como «Invalid Date» porque la respuesta de login no incluye CheckedAt. Al completar la consulta real de inicio se muestra la fecha correcta. No se cambió este detalle en esta corrección de autenticación.

### Limpieza comprobada

Se eliminaron exclusivamente estos nueve registros temporales, previamente identificados:

- Usuarios: IDs 7, 8 y 9 (tres cuentas de prueba).
- Empleados: IDs 4 y 5.
- Clientes: IDs 4 y 5, incluido el registrado desde la interfaz.
- Servicios: IDs 2 y 3.

Las diez tablas se compararon antes y después mediante cantidad de registros y huella SHA-256 de su contenido ordenado por PK. Todas coincidieron exactamente. No quedó ningún dato de prueba. En esta ejecución todas las tablas estaban vacías antes y quedaron vacías después. No se reiniciaron contadores IDENTITY ni se modificaron tablas, restricciones, procedimientos de negocio o triggers durante la limpieza.
La app quedó sin sesión de prueba y nuevamente en la pantalla de creación de tu primera cuenta real.

Evidencias en Pruebas/Recorrido-2026-10-11: capturas del recorrido, resultados de interfaz, API y limpieza. Las capturas muestran datos temporales que ya fueron eliminados.

## Pendiente

Crear tu cuenta real. No se ha configurado ni probado conmutación al espejo de Rachel. No se simula disponibilidad ni datos.
