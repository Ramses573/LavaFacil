# Mejoras de LavaFácil — 17 de octubre de 2026

## Estado de esta entrega

La actualización ya fue aplicada y confirmada en `MADRENZO/LavaFacil` mediante `SQL/Activar-Mejoras.ps1`. El flujo de correo, la invalidación de sesiones y la compatibilidad con el login anterior también quedaron verificados. La evidencia está en `Pruebas/Correo-2026-11-06/RESULTADO.md`.

No vuelvas a ejecutar la activación salvo que estés instalando esta versión en otra base. Si necesitás comprobar el estado, ejecutá el activador y confirmá el mensaje **Actualización confirmada**; no consideres terminada una ejecución con error.

## Activación desde tu portátil

1. Encendé MADRENZO y conectá Tailscale. SQL Server debe estar en ejecución. Encendé también el espejo si querés comprobar la sincronización.
2. Cerrá la ventana de `Iniciar.cmd` del aplicativo para que no siga ejecutándose una versión anterior.
3. Conservá un respaldo reciente de LavaFacil. No ejecutes el script de reconstrucción `LavaFacil_Final.sql` sobre la base existente.
4. Abrí PowerShell en la carpeta `LavaFacil` de tu escritorio y ejecutá:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\SQL\Activar-Mejoras.ps1
   ```

   El activador usa la conexión cifrada que ya configuraste, comprueba que se conectó a `LavaFacil` en un principal conocido y aplica `04_Mejoras_Aplicativo.sql` en una transacción. Si falla, revierte esa transacción. No cambia las contraseñas existentes, la conexión ni los roles de Mirroring.

5. Esperá el mensaje **Actualización confirmada**. Si hay un error, no consideres terminada la activación.
6. Ejecutá `Iniciar.cmd` una sola vez y abrí `http://127.0.0.1:5088/`. Recargá el navegador e iniciá sesión con tu cuenta del aplicativo.
7. Como administrador, revisá **Servicios → Agregar servicio**, **Pedidos → Nuevo pedido** y **Mi perfil**.
8. Comprobá el estado de Mirroring desde SSMS. La actualización se ejecuta solo en el principal; SQL Server replica los cambios al espejo cuando está conectado. No la ejecutes directamente en la copia en RESTORING y no realices un failover para instalarla.

El activador requiere una conexión guardada válida para el usuario actual de Windows y permisos para crear/alterar tablas y procedimientos. Si Rachel ejecuta el aplicativo en su equipo, necesita también los archivos nuevos; no debe copiar tu `Data/connection.dpapi`.

## Alternativa en SSMS

Con una cuenta administradora, conectarse al servidor que actualmente sea principal y abrir `SQL/04_Mejoras_Aplicativo.sql`. Ejecutar el archivo completo en `LavaFacil` y verificar que no haya errores. El activador anterior es preferible porque agrupa todos los lotes en una transacción y detiene la instalación al primer error.

## Funciones incorporadas

- Administrador: agregar, editar, activar y desactivar servicios desde la pantalla Servicios. No elimina servicios para conservar pedidos anteriores.
- Pedidos: un cliente puede solicitar varios servicios en un pedido; el personal puede registrarlo para un cliente activo seleccionado. Cada pedido y sus líneas se guardan juntos.
- Consultas: filtros por fecha, estado, cliente/cédula/número de pedido y servicio; detalle de cada línea y total. Hasta 500 resultados por consulta.
- Cliente: menú Inicio, Servicios, Mis pedidos y Mi perfil; solo accede a pedidos vinculados a su cuenta.
- Personal: consulta pedidos de todos los clientes y actualiza su estado. El mantenimiento de servicios y la creación de cuentas quedan reservados al Administrador.
- Administrador: en Clientes, usar **Crear cuenta de cliente** para habilitar el acceso de un cliente ya registrado. La cuenta creada siempre tiene rol Cliente; no existe autorregistro de administradores.
- Perfil: datos personales, avatar predefinido, tema de colores, biografía y dirección para clientes. No hay subida de fotografías en esta versión.
- Contraseña: cambiar la propia verificando la actual y cerrando la sesión de este navegador. Las cuentas nuevas y claves cambiadas usan PBKDF2-SHA256; las cuentas anteriores siguen funcionando. Al cambiar o restablecer una clave se incrementa `ClaveVersion`, por lo que las cookies de sesión anteriores dejan de ser válidas en la siguiente petición, también en otros navegadores.

## Correo: configuración y operación local

- Para configurar SMTP ejecutá `Tools/Configurar-Correo.ps1` desde la raíz del proyecto. El script solicita la clave de aplicación de forma segura, envía primero un correo de prueba y solo guarda la configuración cifrada en `Data/correo.dpapi` si la prueba funciona. Reiniciá la aplicación después de cambiarla.
- Para pruebas, `LAVAFACIL_CORREO_SALIDA` funciona como outbox **solo en los entornos Development o Test**: los mensajes se escriben como archivos `.eml` en la carpeta indicada, sin enviarse por SMTP. En Production esa variable no habilita el outbox; se requiere una configuración SMTP válida.
- Verificá el correo desde la operación normal de verificación o recuperación. Si no llega, revisá primero que la aplicación se haya reiniciado, que la configuración SMTP corresponda al mismo usuario de Windows que la creó y que el proveedor acepte la clave de aplicación. En Development/Test podés revisar el `.eml` generado; después eliminá los `.eml` de la carpeta configurada para no conservar códigos.
- Los límites de correo son locales y están en memoria: aplican a una sola instancia y no coordinan entre procesos o nodos; al reiniciar la aplicación se reinician sus contadores. No los uses como control distribuido.
- La aplicación está restringida a loopback (`127.0.0.1`/`localhost`). No la expongas fuera de loopback sin HTTPS y certificados confiables.

## Cálculo de tarifas

Para cada servicio: **subtotal = precio base + máximo(0, cantidad − cantidad incluida) × precio adicional**. El precio base cubre hasta la cantidad incluida. Kilogramo permite dos decimales; Unidad y Uniforme requieren cantidades enteras. Máximo 30 servicios distintos y cantidad 10000 por línea. Si el adicional vale cero, el excedente no aumenta el cobro: revisá las tarifas antes de usarlas.

El backend calcula el importe con las tarifas vigentes al guardar, sin aceptar precios enviados por el navegador. El trigger existente mantiene el total del pedido. Editar una tarifa después no cambia el precio guardado en pedidos anteriores. No se aplican promociones ni se registran pagos automáticamente en este flujo.

## Cambios en SQL

Se agrega la columna nullable `Usuarios.ClaveHash`, la tabla `PerfilesApp` y 12 procedimientos nuevos con prefijo `app_`. No se borran tablas ni filas, no se modifican los CRUD de Rachel ni los dos triggers originales. El script puede aplicarse nuevamente sin recrear datos.

`SQL/LavaFacil_Final.sql` sigue siendo la entrega histórica anterior. Para reconstruir desde cero una instalación de esta versión, ejecutar primero ese script en una base vacía, después `01_Procedimientos_App.sql` y por último `04_Mejoras_Aplicativo.sql`. Los datos de muestra del script final tienen contraseñas de reemplazo; no son credenciales utilizables.

## Verificación realizada

Compilación .NET 9 sin errores ni advertencias. 27 comprobaciones HTTP sobre SQL Express local, más recorrido de navegador: alta de servicio, pedido de dos servicios, consulta de detalle, personalización y menú del cliente. Se verificó que un cliente no consulte pedidos ajenos, cambie estados ni administre servicios/cuentas, y que los precios históricos se mantengan.

Evidencias en `Pruebas/Mejoras_20261017` y `Pruebas/Correo-2026-11-06`. Las capturas y registros de prueba corresponden a bases QA o a la validación controlada indicada en cada resultado; no constituyen una nueva prueba de Mirroring. La activación de esta versión ya está confirmada en `MADRENZO/LavaFacil`. Las pruebas reales de caída/conmutación deben coordinarse por separado antes de apagar o cambiar roles. No se publicó esta versión en GitHub.
