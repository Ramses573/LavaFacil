# Validación completa de notificaciones de estados — MADRENZO — 2026-11-06 (re-ejecución)

## Veredicto: PASS (16/16 comprobaciones de endpoint; builds 0 errores; activador OK; regresión PedidoCreado PASS / ComprobantePago con fallo preexistente)

Re-ejecución solicitada sobre `MADRENZO`. No se modificó código fuente ni SQL; solo evidencias actualizadas en `Pruebas/NotificacionesEstados-2026-11-06/`. No se hizo commit/push.

## Conteos reales de la re-ejecución

| Área | Resultado real |
|---|---|
| Build Web (`dotnet build -c Release`) | exit 0; 0 advertencias; 0 errores (`build-web.txt`) |
| Build GraphQL (`dotnet build -c Release`) | exit 0; 0 advertencias; 0 errores (`build-graphql.txt`) |
| Scripts PowerShell (parser) | 7 archivos; 0 errores (`parse-scripts.json`) |
| Activador (`SQL/Activar-Mejoras.ps1`) | exit 0; `Servidor principal confirmado: MADRENZO`; `Actualización confirmada` (`activar-m mejoras.txt`) |
| Endpoint estado (re-ejecución) | 16/16 PASS; 0 FAIL (`endpoint-result.json`, `endpoint-test.txt`) |
| Idempotencia (repetir estado) | PASS: segunda transición `Recibido` → 200; cambios reales = 4 → Cola=4 y 4 EMLs (`status-query.json`, `outbox/`) |
| Transiciones inválidas/terminales | PASS: `Recibido→Pendiente` 400, `Entregado→En proceso` 400 terminal, `Cancelado→Recibido` 400 terminal; Sin encolar (Cola=0 en fixtures inválidos) |
| Cliente sin permisos / pedido inexistente | PASS: cliente 403; pedido inexistente 404 |
| Regresión PedidoCreado | PASS: 6/6 (`regresion-pedidocreado-result.json`) |
| Regresión ComprobantePago | FAIL en flujo: `Error en el servidor remoto: (400) Solicitud incorrecta.` — Repetido idéntico en la corrida previa (`pago-real.json`: `flujo pago autenticado` HUECO/FAIL con el mismo error); no es regresión nueva de los cambios de estados |
| Limpieza absoluta | PASS: EMLs=0; usuarios/empleados/pedidos/detalle/correos/tokens/pagos=0; procesos detenidos; puertos 5088/5125/5089 libres |

## Comprobaciones ejecutadas en la re-ejecución

1. Build Web/GraphQL 0/0 y scripts PowerShell: builds con `-c Release` → exit 0, 0 advertencias, 0 errores; parser PowerShell de 7 scripts → 0 errores.
2. Activador MADRENZO: exit 0; servidor principal `MADRENZO`; actualización confirmada. Definición desplegada: `app_CambiarEstadoPedido` presente en `MADRENZO/LavaFacil` (35 procedimientos `app_*` presentes).
3. Flujo real con personal: `Pendiente→Recibido→En proceso→Listo→Entregado` sobre pedido fixture → 5 transiciones OK (la repetición de `Recibido` fue idempotente); 4 cambios reales → 4 EMLs en outbox con asunto `LavaFácil · Pedido #41: <Estado>`, anterior→nuevo, total y detalle.
4. Idempotencia repetiendo estado: repetir `Recibido` → 200 sin encolar; solo 4 correos para el ciclo completo.
5. Transiciones inválidas/terminales rechazadas sin cambiar estado ni encolar: 400 con mensajes correctos; `Cola=0` en los fixtures inválidos/terminales.
6. Cliente sin permisos / pedido inexistente: 403 (cuenta cliente) y 404 (pedido inexistente).
7. No regresión PedidoCreado/ComprobantePago: PedidoCreado PASS 6/6; ComprobantePago con fallo de redacción GraphQL preexistente (400) igual al de la corrida previa.
8. Limpieza absoluta: EMLs=0; residuales QA=0; procesos app detenidos; puertos libres.

## Detalles de la corrida

- Fixture: `FIXTURE|QA-ESTADOS-FA491486-BF18-498B-9C53-6DF06AB577A5|1113|1114|3096|41|1030|...|Temporal-QA-2026`
- Extra: `EXTRA|42|43|44|45|3097`
- Pedido principal: Id 41 (final `Entregado`); fixes inválidos: 42 (Recibido→Pendiente), 43 (Entregado→En proceso terminal), 44 (Cancelado→Recibido terminal); sin email: 45 (Pendiente→Recibido).

## Comandos ejecutados

- `dotnet build LavaFacil.Web/LavaFacil.Web.csproj -c Release --nologo` → exit 0, 0/0.
- `dotnet build Proyecto2/03-Backend-GraphQL/LavaFacil.GraphQL/LavaFacil.GraphQL.csproj -c Release --nologo` → exit 0, 0/0.
- `powershell -NoProfile -ExecutionPolicy Bypass -File SQL\Activar-Mejoras.ps1` → exit 0.
- `powershell -NoProfile -ExecutionPolicy Bypass -File Pruebas\NotificacionesEstados-2026-11-06\endpoint-test.ps1` → 16/16 PASS, exit 0.
- Checks SQL/Mantenimiento: limpiezas y consultas contra `MADRENZO/LavaFacil`.
- Detenciones: procesos `dotnet`/`LavaFácil.Web` y servidor GraphQL detenidos; puertos 5088/5125/5089 libres.

## Huecos de cobertura

- No se probó envío SMTP real en esta re-ejecución (outbox Development).
- El flujo ComprobantePago no completó por error GraphQL `(400) Solicitud incorrecta` (preexistente, igual en corrida previa).
- No se probó navegador headless ni concurrencia en esta re-ejecución.
