# Validación final CorreoPedidos — 2026-11-06

## Resultado
- Web y GraphQL Release: PASS, 0 advertencias / 0 errores (`build-final-validation-*-rerun.txt`).
- PowerShell: PASS, 4 scripts parseados, 0 errores (`powershell-final-validation-rerun.json`).
- Activador MADRENZO: PASS, exit 0; columna `TokenLease`, SPs y grants verificados (`activador-final-validation-rerun.txt`, `sql-lease-schema-rerun.txt`, `sql-final-validation-rerun.txt`).
- Pedido real: flujo y cola PASS (`IdPedido=18`, `PedidoCreado/Enviado/Intentos=0`); captura EML del outbox FAIL y el script terminó con error al leer la respuesta (`run-order-rerun.txt`).
- Pago GraphQL: evidencia previa focalizada PASS para Pagado, monto 123.45, comprobante único, repetición idempotente e ID cruzado rechazado (`actualizar-pago-focalizado.json`). La repetición independiente final no pudo iniciar el flujo: HTTP 400 (`pago-real-rerun.txt`, `otp-pago-real-rerun.txt`).
- Lease: definiciones y allowlist/idempotencia PASS; prueba real reclamó token, rechazó token incorrecto sin cambiar estado y resolvió con token correcto. Reclaim generó token B distinto y token A fue rechazado; la excepción abortó antes de probar la resolución posterior con B (`lease-*.rerun.*`).
- OTP/CSRF/Host/mirroring/rate-limit y autorización: PASS según evidencias previas conservadas en esta carpeta; no se reejecutaron todos en esta corrida.
- Limpieza final: PASS; Usuarios/Empleados/Pedidos/DetallePedido/Pagos/CorreoEnvios/EML/procesos/puertos quedaron en cero. `keys/` conserva 1 archivo preexistente y `connection.dpapi` fue preservado.

## Huecos reales
- La corrida final no encontró el EML en el outbox configurado (`emlCount=0`), aunque `CorreoEnvios` quedó Enviado.
- Monto superior, Pagado→Pendiente/Anulado, Anulado terminal y SMTP fallido no se ejecutaron de forma aislada; quedan como huecos, no como PASS.
- La prueba final de pago recibió HTTP 400 antes de ejecutar GraphQL; se conserva la evidencia focalizada previa como PASS parcial.
- La prueba de lease con token B quedó interrumpida por la excepción esperada del token A; falta demostrar en la misma corrida la resolución posterior con B.

## Comandos ejecutados
- `dotnet build LavaFacil.Web/LavaFacil.Web.csproj -c Release --no-restore` → PASS 0/0.
- `dotnet build Proyecto2/03-Backend-GraphQL/LavaFacil.GraphQL/LavaFacil.GraphQL.csproj -c Release --no-restore` → PASS 0/0.
- `powershell -NoProfile -ExecutionPolicy Bypass -File SQL/Activar-Mejoras.ps1` → exit 0.
- Parseo PowerShell con `System.Management.Automation.Language.Parser` sobre los 4 `.ps1` de esta carpeta → 0 errores.
- `run-order.ps1`, `pago-real.ps1`, `otp-pago-real.ps1` → ejecutados; resultados y huecos documentados arriba.
- `sql-final-validation.sql` y `lease-idempotencia.sql` → PASS; pruebas conductuales lease en `lease-behavior-rerun.txt` y `lease-reclaim-behavior-rerun.txt`.

No se modificó código fuente ni SQL. No hubo commit/push.
