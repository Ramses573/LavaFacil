# Prueba focalizada directa ActualizarPago/Correo — 2026-11-06

## Resultado ejecutado

- Fixture temporal válido creado directamente en MADRENZO, sin GraphQL: `IdUsuario=1103`, `IdPedido=20`, `IdPago=10`, pago anulado `IdPago=11`.
- `Pendiente→Pagado` con monto `100.00`: PASS; se creó una sola fila `ComprobantePago`.
- Repetición `Pagado→Pagado`: PASS; `CorreoEnvios count=1`.
- Monto `100.01`: PASS esperado, `50101: El monto del pago no puede superar el total del pedido.`
- `Pagado→Pendiente` y `Pagado→Anulado`: PASS esperado, código `50101`.
- `Anulado→Pagado` y `Anulado→Pendiente`: PASS esperado, código `50101`.
- `Pedido.Total=100.00` y `DatosJsonBytes=668`: PASS.
- Lease: token A reclamado; token incorrecto y token A vencido rechazados con `50104` sin cambiar el estado; token B distinto resolvió `Enviado`: PASS.
- Limpieza SQL: PASS; fixtures, cola y tokens temporales en cero. No se usó SMTP/outbox ni GraphQL.

## Evidencias y comando

- `focalizado-directo.sql` — fixture, llamadas directas, captura de códigos/mensajes y limpieza.
- `run-focalizado-directo.ps1` — ejecutor y aserciones; salida completa en `focalizado-directo.txt`.
- `focalizado-directo.json` — resumen estructurado de la corrida.
- `powershell -NoProfile -ExecutionPolicy Bypass -File Pruebas/CorreoPedidos-2026-11-06/run-focalizado-directo.ps1` → PASS.
- Validación posterior: `qa_directo 0 0 0 0 0`; procesos LavaFacil `0`; EML `0`; keys existentes `1` preservadas; `connection.dpapi` no tocado.

## Huecos

- No se verificó entrega SMTP real ni generación de EML, por instrucción de no depender de SMTP/outbox.
- No se ejecutó una comparación antes/después porque esta corrida valida el comportamiento ya aprobado y no modifica producción.
