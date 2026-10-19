# Mejoras de LavaFácil — 17 de octubre de 2026

## Estado de esta entrega

El código y la actualización de SQL están preparados y probados en una base aislada de la portátil. La actualización NO se aplicó a MADRENZO ni a Rachel: el servidor configurado no respondió y se acordó activarla después.

Hasta aplicar la actualización, la nueva versión conserva las pantallas anteriores. Las funciones nuevas se habilitan cuando la base tiene todos los procedimientos necesarios.

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
- Contraseña: cambiar la propia verificando la actual y cerrando la sesión de este navegador. Las cuentas nuevas y claves cambiadas usan PBKDF2-SHA256; las cuentas anteriores siguen funcionando. Las sesiones previamente abiertas en otros navegadores no se revocan automáticamente.

## Cálculo de tarifas

Para cada servicio: **subtotal = precio base + máximo(0, cantidad − cantidad incluida) × precio adicional**. El precio base cubre hasta la cantidad incluida. Kilogramo permite dos decimales; Unidad y Uniforme requieren cantidades enteras. Máximo 30 servicios distintos y cantidad 10000 por línea. Si el adicional vale cero, el excedente no aumenta el cobro: revisá las tarifas antes de usarlas.

El backend calcula el importe con las tarifas vigentes al guardar, sin aceptar precios enviados por el navegador. El trigger existente mantiene el total del pedido. Editar una tarifa después no cambia el precio guardado en pedidos anteriores. No se aplican promociones ni se registran pagos automáticamente en este flujo.

## Cambios en SQL

Se agrega la columna nullable `Usuarios.ClaveHash`, la tabla `PerfilesApp` y 12 procedimientos nuevos con prefijo `app_`. No se borran tablas ni filas, no se modifican los CRUD de Rachel ni los dos triggers originales. El script puede aplicarse nuevamente sin recrear datos.

`SQL/LavaFacil_Final.sql` sigue siendo la entrega histórica anterior. Para reconstruir desde cero una instalación de esta versión, ejecutar primero ese script en una base vacía, después `01_Procedimientos_App.sql` y por último `04_Mejoras_Aplicativo.sql`. Los datos de muestra del script final tienen contraseñas de reemplazo; no son credenciales utilizables.

## Verificación realizada

Compilación .NET 9 sin errores ni advertencias. 27 comprobaciones HTTP sobre SQL Express local, más recorrido de navegador: alta de servicio, pedido de dos servicios, consulta de detalle, personalización y menú del cliente. Se verificó que un cliente no consulte pedidos ajenos, cambie estados ni administre servicios/cuentas, y que los precios históricos se mantengan.

Evidencias en `Pruebas/Mejoras_20261017`. Las capturas y registros de prueba corresponden a una base QA independiente, no a los datos reales ni a una nueva prueba de Mirroring. La activación y la prueba de conmutación con esta versión quedan pendientes para cuando los servidores estén disponibles. No se publicó esta versión en GitHub.
