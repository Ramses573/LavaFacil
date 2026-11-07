# Auto-registro de cliente — 4 de noviembre de 2026 (corrida 2, desbloqueada)

## Veredicto global: PASS (42/42 verificaciones)

El bloqueo **A-01 quedó RESUELTO** por el agente de base-datos (`SQL/Activar-Mejoras.ps1`, sin commit):
el guard ahora acepta `mirroring_role_desc` **NULL** (sin mirroring) **o** `'PRINCIPAL'`, y sigue
rechazando `'MIRROR'`/WITNESS/filas o servidor inválidos. Con eso, la suite completa se ejecutó de
principio a fin: activación de BD, pruebas SQL del SP, pruebas API y pruebas UI/estáticas.
**No se modificó ningún archivo de código** (solo se agregaron/actualizaron archivos en
`Pruebas/AutoRegistro-2026-11-04/`), no se hizo commit ni push, y **la limpieza está confirmada
en 0 filas** y con el servidor detenido.

### Corrida anterior (FAIL) — por qué cambió

En la corrida 1 el activador abortó en el guard con exit 1:

```text
No se aplic?? nada: la conexi??n no corresponde a LavaFacil en un principal conocido o faltan permisos para consultar su rol.
```

Causa: `mirroring_role_desc = NULL` (mirroring ya eliminado) frente a un guard que exigía
`'PRINCIPAL'`. **A-01 RESUELTO** → esta corrida pasa sin reintentos a ciegas.

## Salida exacta del activador (fase 2)

Comando: `powershell -NoProfile -ExecutionPolicy Bypass -File .\SQL\Activar-Mejoras.ps1`

```text
Servidor principal confirmado: MADRENZO
Actualizaci??n confirmada. Reinici?? Iniciar.cmd y recarg?? el navegador.
EXITCODE=0
```

Los `??` son el mojibake de codepage de consola de PS 5.1 (hallazgo **B-01**, sigue abierto); el
mensaje literal del código es *«Actualización confirmada. Reiniciá Iniciar.cmd y recargá el navegador.»*
Se obtuvo **«Servidor principal confirmado: MADRENZO»** + **«Actualización confirmada»**, exit 0.

## Tabla de verificaciones (código → resultado REAL)

| # | Código / verificación | Resultado | Evidencia real |
|---|---|---|---|
| 1 | Detener instancias viejas de LavaFacil.Web | **PASS** | Sin `LavaFacil.Web.exe` ni `dotnet run` al iniciar; 0 `LISTENING` en :5088 |
| 2 | `dotnet build LavaFacil.Web/LavaFacil.Web.csproj` | **PASS** | `Compilación correcta. / 0 Advertencia(s) / 0 Errores` (1.19 s) |
| 3 | `powershell ... -File .\SQL\Activar-Mejoras.ps1` | **PASS** | exit 0; «Servidor principal confirmado: MADRENZO» + «Actualización confirmada» |
| 4 | `dbo.app_AutoRegistroCliente` existe | **PASS** | `SP app_AutoRegistroCliente: EXISTE (dbo.app_AutoRegistroCliente)` |
| 5 | GRANT del SP | **PASS** | `GRANT: GRANT EXECUTE -> ramses_proyecto` |
| 6 | SQL-3.1 ejecución válida → IdUsuario/IdCliente | **PASS** | `IdUsuario=1014, IdCliente=3012` |
| 7 | SQL-3.2 `TipoUsuario=Cliente`, `Activo=1` (ambas filas) | **PASS** | `TipoUsuario=Cliente, ActivoU=True, ActivoC=True` |
| 8 | SQL-3.2 `ClaveHash` con prefijo `PBKDF2-SHA256$210000$` | **PASS** | `inicio=PBKDF2-SHA256$210000$2vBuG8fv3e1yo` |
| 9 | SQL-3.2 `Clave` con forma de GUID y distinta de la contraseña | **PASS** | `Clave=D8FAD8DD-AD0C-4AFD-9D3E-DBBB00B77968, distinta=True` |
| 10 | SQL-3.2 sin texto plano en ninguna columna | **PASS** | `columnas con fuga: ninguna` (10 columnas de las 2 filas revisadas) |
| 11 | SQL-3.2 el hash recibido quedó en `ClaveHash` (no la contraseña) | **PASS** | `ClaveHash==HashEnviado=True` |
| 12 | SQL-3.3 cédula repetida → 50103 | **PASS** | `numero de error=50103` |
| 13 | SQL-3.3 usuario repetido → 50103 | **PASS** | `numero de error=50103` |
| 14 | SQL-3.3 obligatorio vacío → 50101 | **PASS** | `numero de error=50101` |
| 15 | SQL-3.3 `@Hash` sin prefijo `PBKDF2-SHA256$` → 50101 | **PASS** | `numero de error=50101` |
| 16 | SQL-3.4 atomicidad: sin `Clientes`/`Usuarios` huérfanos | **PASS** | `ClientesNuevos=0, UsuariosNuevos=0` |
| 17 | SQL-3.4 una sola fila por registro válido | **PASS** | `Clientes=1, Usuarios=1` |
| 18 | SQL-3.5 limpieza confirmada (0 filas) | **PASS** | `Usuarios autotest=0, Clientes AUTOTEST-SQL=0` |
| 19 | API-4.1 `GET /api/bootstrap` → 200 `configured`+`featuresReady`+token | **PASS** | `status=200, configured=True, featuresReady=True, token presente=True` |
| 20 | API-4.2 `POST /api/register` sin `X-CSRF-TOKEN` → 400 | **PASS** | `status=400` |
| 21 | API-4.3 `POST /api/register` con Host alterado → 403 | **PASS** | `status=403` (log Kestrel: `Request finished ... 403`) |
| 22 | API-4.4 registro válido → 200 + `role=Cliente` + cookie + sin exponer clave/hash | **PASS** | `status=200, role=Cliente, cookie=True, sinExponer=True, name=autotest.api.1` |
| 23 | API-4.9 (A-02) `POST /api/register` → 200 y NO 500/503 | **PASS** | `status=200, featuresReady=True` |
| 24 | API-4.5 `GET /api/profile` → 200 | **PASS** | `status=200` |
| 25 | API-4.5 `GET /api/clients` como Cliente → 403 | **PASS** | `status=403`, cuerpo `{"error":"La cuenta está inactiva o no tiene permiso para esta operación."}` |
| 26 | API-4.6 logout 200 + login real 200 `role=Cliente` | **PASS** | `logout=200, login=200, role=Cliente` |
| 27 | API-4.7 duplicado → 400 con una sola fila | **PASS** | `status=400, Usuarios=1, Clientes=1`, msg `Ya existe un cliente con esa cédula...` |
| 28 | API-4.8 contraseña 8 chars (<10) → 400 | **PASS** | `status=400`, msg `Usa una contraseña de al menos 10 caracteres.` |
| 29 | API-4.8 correo inválido → 400 | **PASS** | `status=400`, msg `Ingresa un correo electrónico válido.` |
| 30 | API-4.8 nombre vacío → 400 | **PASS** | `status=400`, msg `Nombre es obligatorio y admite hasta 50 caracteres.` |
| 31 | API-4.10 limpieza de la cuenta de prueba | **PASS** | `Usuarios=0, Clientes=0` |
| 32 | UI-5.1 CTA `#register-cta` tras el botón y antes de `.auth-foot` | **PASS** | `btn=2208, cta=2301, authFoot=2385` |
| 33 | UI-5.1 `#signup-template` completo | **PASS** | `abierto=True, cerrado=True, campos faltantes=ninguno` |
| 34 | UI-5.1 `app.js` servido con `showSignup`/`request('register'`/`routeName==='registro'` | **PASS** | `showSignup=True, request(register=True, routeName=True` |
| 35 | UI-5.1 `app.js` liga CTA a `featuresReady` | **PASS** | `cta.hidden = !state.featuresReady` → `presente=True` |
| 36 | UI-5.1 `node --check` del `app.js` servido | **PASS** | `node --check exit=0 sin salida (OK)` |
| 37 | UI-5.2 `GET /monitor.js` → 404 | **PASS** | `status=404` |
| 38 | UI-5.2 `GET /` sin mencionar mirroring | **PASS** | `contiene mirroring=False` |
| 39 | UI-5.3 `GET /api/health` → 404 | **PASS** | `status=404` |
| 40 | Limpieza BD: 0 filas de prueba (SQL + API) | **PASS** | `Usuarios de prueba restantes: 0` / `Clientes de prueba restantes: 0` |
| 41 | Entorno: 0 procesos colgados, :5088 libre | **PASS** | `Procesos LavaFacil: 0`, `LISTENING en :5088 = 0`, `Procesos dotnet: 0` |
| 42 | A-02 verificado en runtime (no supuesto) | **PASS** | `featuresReady=True` + CTA enlazado en JS servido + `POST /api/register` = **200** |

Resúmenes por fase: **fase 4 (SQL) 13/13**, **fase 5 (API) 13/13**, **fase 6 (UI) 8/8**.

## A-02 verificado en estado real (no supuesto)

1. `GET /api/bootstrap` → **`featuresReady=true`** (los 15 SP que cuenta `Database.HasFeatures()`
   existen tras aplicar 04).
2. `index.html` servido contiene `#register-cta` en la posición correcta y `app.js` servido contiene
   `cta.hidden = !state.featuresReady` → con `true`, el CTA **se muestra**.
3. `POST /api/register` con payload válido → **200**, cookie `LavaFacil.Session`, `user.role=Cliente`,
   sin 500/503 y sin filtrar contraseña ni hash.

**Conclusión A-02: ya no hay riesgo observado.** El acoplamiento CTA↔`featuresReady`↔registro funciona.

## Hallazgos (por severidad)

| Id | Severidad | Estado | Detalle |
|---|---|---|---|
| **A-01** | ALTA | **RESUELTO** | Guard de `SQL/Activar-Mejoras.ps1` aceptaba solo `'PRINCIPAL'`; la BD tiene `mirroring_role_desc=NULL`. Corregido (archivo único, sin commit): `($null -eq $rol -o 'PRINCIPAL')` aceptado, `'MIRROR'`/WITNESS/0 filas/base-servidor inválidos siguen rechazados con el mismo mensaje. **Verificado en runtime:** exit 0 y «Actualización confirmada». |
| **A-02** | ALTA | **CERRADO** | Riesgo de CTA visible con registro roto. Verificado en runtime: `featuresReady=true`, CTA enlazado, `POST /api/register` → 200. Sin 500/503. |
| **B-02** | **MEDIA** (nueva) | **ABIERTA** | `POST /api/register` es **anónimo** y su 200 expone la instancia de SQL Server y la base: `{"user":{...},"server":"MADRENZO","databaseName":"LavaFacil"}` (Program.cs:110, `result.Server`/`result.DatabaseName`). Un atacante sin credenciales obtiene el nombre del servidor. `POST /api/login` hace lo mismo pero exige credenciales válidas. Requiere decisión de seguridad (no modificar código sin aprobación). |
| **B-01** | BAJA | ABIERTA | La salida del activador sigue en mojibake (`Actualizaci??n confirmada`) por codepage de consola PS 5.1 → logs de CI ilegibles. Codificar la salida a UTF-8 (requiere aprobación). |
| **B-03** | BAJA (latente) | ABIERTA | `Database.HasFeatures()` cuenta 15 SP que **no incluyen `app_AutoRegistroCliente`** (Program.cs:150). Hoy no falla porque 04 crea ambos en la misma transacción, pero si alguien aplicara un 04 parcial el CTA se mostraría con registro roto (exactamente el escenario A-02). Sugerido: agregar el SP a la lista de 15 → 16. |
| **N-01** | Informativo | — | El guard aborta **antes** de `BeginTransaction` → cero aplicación parcial (diseño correcto). Se reconfirmó: no hubo ejecución parcial ante el fallo de la corrida 1. |
| **N-02** | Informativo (solo pruebas) | — | Los `.ps1` de evidencia deben ir en **ASCII puro o UTF-8 con BOM**: PS 5.1 lee sin BOM como ANSI y un `→` (UTF-8 `E2 86 92`) produce U+2019, que PowerShell trata como delimitador de cadena y **traga líneas**. Detectado en la 1ª versión de `fase4-sql.ps1` (2 aserciones no registradas); corregido y reejecutado: 13/13. |

## Huecos de cobertura

- **Sin navegador real**: la UI se verificó sobre el HTML/JS *servido* + `node --check`; no se ejecutó
  el flujo `#registro` en un navegador (no hay headless en el entorno).
- **Duplicado por correo** (`50103` por `Email`) no probado: la consigna pedía cédula y usuario.
- **Límites de longitud** no probados: `@Direccion` > 250 (400 de API), `@Telefono` > 20, cédula > 20.
- **Concurrencia**: no se probó el `HOLDLOCK` con dos registros simultáneos reales.
- **`/api/register` con BD sin configurar** (`configured=false`) no probado.
- **B-02/B-03** requieren aprobación para corregirse; no se tocó el código.

## Comandos ejecutados

- `Get-Process` / `netstat -ano` → sin instancias viejas; al final 0 procesos y 0 `LISTENING` en :5088.
- `dotnet build LavaFacil.Web/LavaFacil.Web.csproj` → 0 errores, 0 advertencias.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\SQL\Activar-Mejoras.ps1` → **exit 0**.
- `powershell ... verificacion-sp.ps1` → SP existe + GRANT.
- `powershell ... fase4-sql.ps1` → 13/13 (limpieza SQL al final y en `finally`).
- `dotnet run --project LavaFacil.Web/LavaFacil.Web.csproj --no-build` (2 arranques) → `LISTENING_5088=True`.
- `powershell ... fase5-api.ps1` → 13/13 (limpieza de cuenta al final y en `finally`).
- `powershell ... fase6-ui.ps1` → 8/8.
- `powershell ... verif-b02.ps1` → 200 con `server`/`databaseName` expuestos (B-02).
- `powershell ... verificacion-final.ps1` → 0 filas de prueba, 0 procesos, puerto libre.
- `git status --porcelain` / `git diff --stat` → **sin cambios míos** fuera de `Pruebas/` (los `M` de
  `Program.cs`, `app.js`, `index.html`, `04_...`, `Activar-Mejoras.ps1` son preexistentes, de otros agentes).

## Estado de limpieza — CONFIRMADO

- **BD:** `Usuarios` de prueba = **0** (`autotest.sql.*`, `autotest.api.*`, `autotest.cliente`);
  `Clientes` de prueba = **0** (`AUTOTEST-SQL-*`, `AUTOTEST-API-01/02`, `AUTOTEST-20261104`).
- **Procesos:** `LavaFacil.Web.exe` = **0**, `dotnet` = **0** (ambos arranques detenidos).
- **Puerto:** `LISTENING` en 127.0.0.1:5088 = **0** (quedó un `TIME_WAIT` de cliente con PID 0, que
  expira solo y no impide bindear).
- **Commits:** ninguno. **Archivos de código modificados por mí:** ninguno.

## Archivos de evidencia

- `fase4-sql.ps1` / `fase4.json` — pruebas SQL 3.1-3.5.
- `fase5-api.ps1` / `fase5.json` — pruebas API 4.1-4.10.
- `fase6-ui.ps1` / `fase6.json` — pruebas UI/estáticas 5.1-5.3.
- `verificacion-sp.ps1` — SP + GRANT.
- `verif-b02.ps1` — verificación en runtime del hallazgo B-02.
- `verificacion-final.ps1` — limpieza final BD + entorno.
- `resultados.json` — tabla de verificaciones con estado.
- Este `RESULTADO.md`.
