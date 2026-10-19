# Monitor de servidores — 18 de octubre de 2026

El panel «Estado de servidores» aparece debajo del menú para administradores. Comprueba automáticamente cada 15 segundos mientras la pestaña está visible. «Comprobar ahora» solicita una comprobación; el backend comparte resultados hasta 10 segundos para evitar consultas repetidas de varias pestañas.

Se consulta cada servidor configurado usando la conexión cifrada existente: Data Source y Failover Partner. Las comprobaciones de cada instancia usan `master` sin redirección al compañero. Una tercera consulta de solo lectura comprueba qué servidor atiende actualmente la base del aplicativo.

Muestra disponibilidad, nombre e IP/instancia configurada, rol, estado de sincronización y hora. Los roles se consultan en SQL, no se deducen del nombre MADRENZO o Rachel. Si no hay respuesta o el rol no está visible, indica el último rol confirmado con su fecha, o Desconocido. Ese historial vive en memoria y se pierde al reiniciar el aplicativo. Sin permisos suficientes, un rol NULL nunca se interpreta como principal ni espejo.

El login SQL guardado necesita poder conectarse a `master` en ambas instancias y consultar los metadatos de `LavaFacil`. Si SQL rechaza el login o no permite ver los roles, el panel lo informa; revisar con el administrador de SQL. El aplicativo no otorga permisos nuevos ni cambia credenciales. La sesión de administrador de la app habilita el panel mientras siga vigente, incluso si SQL está fuera de servicio.

Los clientes y empleados no reciben direcciones, nombres ni roles en la respuesta HTTP: solo disponibilidad y un mensaje sencillo cuando no se puede confirmar la conexión. Las consultas del monitor no guardan pedidos, no reenvían formularios y no ejecutan FAILOVER, RESTORE ni cambios de configuración.

«No responde» puede significar red, Tailscale, SQL Server o autenticación; no confirma un apagado físico. Tampoco se presenta como una caída del principal si no se conoce su rol. Se muestra un aviso al detectar que la conexión comprobada cambió de servidor.

## Uso

Cerrar la ventana del aplicativo anterior, ejecutar `Iniciar.cmd` una sola vez y recargar el navegador. Entrar como administrador y abrir Estado de servidores. Esta función no requiere aplicar el script de las mejoras de pedidos; sí requiere la conexión guardada y permisos de lectura en SQL. Si no está configurado Failover Partner, se comprueba solo la primera instancia y se avisa que falta el compañero.

No se activó la actualización pendiente de pedidos ni se modificó el Mirroring. Las pruebas reales de caída/conmutación con MADRENZO y Rachel siguen pendientes y deben coordinarse antes de apagar o cambiar roles.

## Pruebas

- Compilación .NET 9 sin advertencias ni errores; sintaxis JavaScript correcta.
- Diez escenarios simulados: ambos sincronizados; roles intercambiados; último espejo sin respuesta; último principal sin respuesta; ambos sin respuesta; compañero no configurado; roles sin visibilidad; sincronización pendiente; réplica suspendida; caída sin historial previo.
- HTTP sobre una base QA local: anónimo rechazado con 401; administrador ve el diagnóstico; cliente no recibe la topología; SQL Express sin Mirroring muestra rol desconocido correctamente.
- No se simularon fallas apagando los servidores reales. El panel distingue disponibilidad observada desde esta portátil, no diagnostica por sí mismo la causa física.
