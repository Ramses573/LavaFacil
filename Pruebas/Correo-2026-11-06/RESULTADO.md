# Validación final post-fix datetime2 8→6 — 2026-11-06

## Veredicto: PASS (79/79 comprobaciones; 0 fallos)

Usuario de producción confirmado: `MADRENZO`. No se editó código fuente ni SQL; no hubo commit/push.
El activador terminó correctamente después de validar `datetime2` con precisión 6.

## Evidencia ejecutada

- Detención inicial/final de `LavaFacil.Web` y `dotnet`.
- `dotnet build .\LavaFacil.Web\LavaFacil.Web.csproj --nologo` → exit 0, 0 advertencias, 0 errores.
- `node --check` para `app.js` y `correo.js` → ambos exit 0.
- `powershell -ExecutionPolicy Bypass -File SQL\Activar-Mejoras.ps1` → exit 0; `Servidor principal confirmado: MADRENZO` + `Actualización confirmada`.
- Las 4 copias SQL contienen `CreadoEn`, `ExpiraEn` y `UsadoEn` como `datetime2`, precisión 6; no quedan validaciones 8.
- SQL: 5 SP de correo, 3 columnas, default `ClaveVersion=((0))`, tabla, 3 índices y 5 grants → 18/18 PASS.
- SQL legacy: `usp_ValidarLogin` existe e incluye `ClaveVersion` → PASS.
- Development/outbox (`fase-api-final.json`) → 14/14 PASS: registro, estado, EML, verificación, token inválido, recuperación sin enumeración, reset y login con nueva clave. El OTP se extrajo únicamente de `Codigo: 123456`; se afirmó ausencia de `X-LavaFacil-Codigo` y de OTP en `Subject` para verificación y recuperación.
- Cookie anterior después de reset → `401` en 1 s (límite 35 s) → PASS.
- Regresiones (`validacion-complementaria-final.json`) → 12/12 PASS: incluye las dos aserciones del formato outbox, CSRF 400, Host 403, Cliente en `/api/clients` 403, mirroring/health 404, raíz 200 y recurso no publicado 404.
- Production sin outbox → `correoConfigurado=false`; bootstrap PASS y EML `4 → 4`. La petición conservada en `production-final.json` devolvió 400 por CSRF no válido, por lo que no demuestra el 503 de envío.
- Rate limit de registro → secuencia nueva `200,200,200,200,200,429`, `Retry-After: 3600` → PASS.
- Rate limit de login → secuencia nueva `401,401,401,401,401,429`, `Retry-After: 600` → PASS.
- Compatibilidad de login legacy (cuenta temporal con `ClaveHash=NULL`) → `200`, usuario autenticado en `MADRENZO/LavaFacil` → PASS. Login PBKDF2 cubierto por Development → PASS.
- Login legacy/PBKDF2 → cuenta temporal legacy autenticó `200`; flujo Development autenticó PBKDF2.
- Limpieza final → `usuarios=0`, `clientes=0`, tokens huérfanos=0, `.eml=0`, procesos LavaFacil=0, procesos dotnet=0, puertos 5088/5089 libres.

## Comandos/evidencias principales

- `fase-api-rerun.json`, `validacion-complementaria-rerun.json`, `rate-limit-rerun.json`, `legacy-login-rerun.json`
- `sql-verificacion-rerun.json`, `sql-legacy-rerun.json`, `limpieza-final-rerun.json`, `limpieza-bd-rerun.txt`
- `production-final.json`, `build-final-2026-11-06.txt`, `activador-final-2026-11-06.txt`

## Huecos de cobertura

- No se probó entrega SMTP real, navegador headless ni concurrencia.
- La invalidación de cookie se probó con reset; no existe endpoint independiente de cambio de clave.
- No se probó failover/mirroring real ni el umbral de rate limit desde una IP limpia concurrente.
- La evidencia Production disponible no alcanza la rama 503 con CSRF válido; debe repetirse para cerrar ese hueco.
