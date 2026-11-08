# Verificación del comprobante PDF adjunto — 2026-11-07

## Alcance y enfoque

Se creó un harness de consola que **compila por enlace los archivos fuente reales** del proyecto web, sin copiarlos ni modificarlos:

- `LavaFacil.Web/AdjuntoCorreo.cs`
- `LavaFacil.Web/ComprobantePdf.cs`
- `LavaFacil.Web/CorreoSmtp.cs`
- `LavaFacil.Web/CorreoPedidos.cs`

El harness vive en `Pruebas/AdjuntoPdf-2026-11-07/ComprobantePdf.Pruebas/`.
Incluye las dependencias `PDFsharp 6.2.4`, `PdfPig 0.1.9`, `Microsoft.Data.SqlClient 6.1.1` y `System.Security.Cryptography.ProtectedData 9.0.4` **solo en el proyecto de pruebas**, más un `Database` stub que no se conecta a SQL. No se modificó código de producción ni SQL.

- SO: Windows
- SDK: `dotnet 9.0.320`
- No se usó SMTP real ni base de datos.
- No se hizo commit ni push.

## Comandos ejecutados y resultado real

```text
dotnet build .\Pruebas\AdjuntoPdf-2026-11-07\ComprobantePdf.Pruebas\ComprobantePdf.Pruebas.csproj -c Release
→ Compilación correcta. 2 advertencias CA1416 (archivo enlazado CorreoSmtp.cs por ProtectedData en consola), 0 errores.

dotnet run --project .\Pruebas\AdjuntoPdf-2026-11-07\ComprobantePdf.Pruebas\ComprobantePdf.Pruebas.csproj -c Release -- "C:\...\Pruebas\AdjuntoPdf-2026-11-07"
→ TOTAL: 16 PASS / 0 FAIL (código de salida 0)

dotnet build .\LavaFacil.Web\LavaFacil.Web.csproj -c Release
→ Compilación correcta. 0 advertencias, 0 errores.
```

La salida completa está en `ejecucion-consola.txt`, `build-harness-release.txt` y `build-web-release.txt`.
El resultado estructurado está en `resultados.json`.

> El build web es una verificación independiente del harness. **No cuenta como caso del harness.**

## Resultado por caso

| # | Caso | Resultado | Evidencia / detalle |
|---|------|-----------|---------------------|
| 1 | `PedidoCreado` real: `%PDF-`, PdfPig abre, ≥1 página, <1.5 MB, marca, `Pedido #18`, servicio y total es-CR | **PASS** | PDF válido: 55 703 bytes, 1 página. Contiene `LavaFácil`, `Pedido #18`, `Lavado por kilo`, `Planchado` y `Total ₡4 500,00`, una sola vez. Ver `caso1-texto-extraido.txt`. |
| 2 | Acentos: `José Ñandú Muñoz`, `Lavandería`, sin `?` | PASS | `caso2-texto-extraido.txt`. PdfPig devuelve los caracteres correctos. |
| 3a | 30 ítems: los 30 nombres y el total (una sola vez) caben en la A4; PDF abre y <1.5 MB | PASS | 1 página (30 filas de 16 pt caben en A4). Los 30 nombres y `3 000,00` exactamente 1 vez. No se exige mínimo de páginas. `caso3a-texto-extraido.txt`. |
| 3b | 60 ítems → corte en 50 y `... y 10 servicios más` | PASS | 50 nombres presentes y aviso exacto. `caso3b-texto-extraido.txt`. |
| 3c | Paginación real: 45 ítems → ≥2 páginas | PASS | 2 páginas, 45 nombres presentes. `caso3c-texto-extraido.txt`. |
| 4 | `ComprobantePago` con snapshot real (`TotalPedido`): título `Comprobante de pago #77 · Pedido #18`, método, referencia, monto, leyenda y sin tabla | PASS | Título exacto presente, `Total del pedido` y `₡4 500,00`. Sin `Subtotal` ni `Servicio`. `caso4-texto-extraido.txt`. |
| 4b | Fallback: sin `TotalPedido`, con `Total` | PASS | Se dibuja `Total del pedido` con `4 500,00`; el fallback real funciona. `caso4b-texto-extraido.txt`. |
| 4c | Filas de pago vacías se omiten | PASS | Sin `EstadoPago`/`MetodoPago`/`Referencia` no se dibujan las etiquetas `Estado`, `Método` ni `Referencia`; la fila de total sí aparece. `caso4c-texto-extraido.txt`. |
| 5 | `PedidoEstado` → `TryCrear` false sin error | PASS | `adjunto=null`, `error=null`. |
| 6 | Snapshot inválido (array) y `maximoBytes: 10` → false con error, sin excepción | PASS | Ambos devuelven false y error no vacío. |
| 7 | Outbox con adjunto: boundaries aleatorios descubiertos del `.eml`, `multipart/mixed` raíz, `multipart/alternative` anidado, parte PDF base64 decodificable | PASS | Se descubre `lavafacil-<guid:N>` para `mixed` y para `alternative` (distintos y con patrón aleatorio), sin nombres fijos. El base64 decodificado pesa lo mismo que el original, empieza con `%PDF-`, abre con PdfPig y contiene `LavaFácil` y `Pedido #18`. `caso7-eml-normalizado.txt`. |
| 8 | Regresión OTP: sin `multipart/mixed` ni `application/pdf`, con `multipart/alternative` y código | PASS | `EnviarCodigoAsync` mantiene el sobre simple; se extrae `Codigo: 123456`. `caso8-eml-normalizado.txt`. |
| 9 | Adjunto inválido (nombre con `\r\n`, contenido vacío y contenido sin firma PDF) | PASS | Se descartan los tres, `Enviado=true`, `Advertencia` no nula, el EML no contiene `application/pdf` ni `multipart/mixed`. `caso9-advertencia.txt`, `caso9-eml-normalizado.txt`. |
| 10 | Seguridad del outbox: si `LAVAFACIL_CORREO_SALIDA` cae dentro de `ContentRootPath` o `WebRootPath`, `OutboxActivo=false` | PASS | (a) dentro de `ContentRootPath` → deshabilitado; (b) dentro de `WebRootPath` → deshabilitado; (c) control fuera de ambos → habilitado. |
| 11 | `AdjuntoCorreo.TryValidar` exige contenido que empiece por `%PDF-` | PASS | `%PDF-1.7…` válido; `<html>…</html>` y `%PDF` (4 bytes) rechazados con error. |
| extra | `CorreoPedidos`: adjunta en `PedidoCreado`/`ComprobantePago`, no en `PedidoEstado` | PASS | Comprobado por reflexión sobre `CrearMensaje`, sin base de datos. |

## Cambios respecto a la corrida anterior y por qué

La corrida anterior terminó en **12 PASS / 0 FAIL**, pero estaba validando el contrato viejo. Al ejecutar el harness antiguo contra el código actual se obtuvieron **9 PASS / 3 FAIL**: los casos 7, 8 y 9 fallaban con `OutboxActivo=false` / `no configurado`. Esta corrida refleja el comportamiento nuevo:

1. **Política de outbox ampliada.** El outbox se deshabilita cuando `LAVAFACIL_CORREO_SALIDA` apunta dentro de `ContentRootPath` **o** `WebRootPath` (`CorreoSmtp.EstaDentroDelSitio`). El harness anterior creaba el outbox dentro del content root falso, por eso los casos 7, 8 y 9 ya no ejercitaban el outbox. Ahora el entorno falso usa `ContentRootPath` y `WebRootPath` temporales, y el outbox en **otro** directorio temporal fuera de ambos. Se añadió el caso 10 para fijar la regla de seguridad (y un control positivo fuera del sitio).
2. **Boundaries MIME aleatorios.** El escritor genera `lavafacil-<guid:N>` independientes para `mixed` y `alternative`; ya no existen `lavafacil-mixed` ni `lavafacil-boundary`. El caso 7 ahora descubre ambos boundaries con una regex sobre `Content-Type: multipart/...; boundary="..."` y verifica que sean distintos y aleatorios. La extracción del base64 usa el boundary descubierto, no un nombre fijo.
3. **Título del comprobante de pago.** Ahora es `Comprobante de pago #<idPago> · Pedido #<idPedido>`. El caso 4 verifica ambas partes.
4. **Filas de pago vacías omitidas.** Se añadió el caso 4c: si faltan `EstadoPago`, `MetodoPago` o `Referencia`, no se dibujan sus etiquetas.
5. **Firma PDF obligatoria en `AdjuntoCorreo.TryValidar`.** Se añadió el caso 11 y se incluyó un adjunto sin `%PDF-` en el caso 9.
6. **Fixture de pago corregido a `TotalPedido`.** El snapshot real de pago trae `TotalPedido`; el fixture anterior usaba `Total`, lo que probaba una ruta que no es la de producción. El caso 4 usa `TotalPedido` y el caso 4b conserva la verificación del fallback `Total`.

No se debilitó ninguna aserción para hacer pasar las pruebas: las aserciones que dependían del contrato eliminado (boundaries fijos y outbox dentro del content root) se sustituyeron por las que validan el comportamiento real.

## Hallazgos reales

Estado final: **16/16 PASS** en el harness. No hay fallos abiertos en la ejecución actual.

### 1. Total del pedido en `PedidoCreado` (caso 1) — resuelto

El generador no dibujaba el total en la primera versión. Tras el arreglo, el texto extraído contiene `Total ₡4 500,00` una sola vez. Evidencia en `caso1-texto-extraido.txt` (`paginas=1`, `bytes=55703`, `total exacto con simbolo ₡`).

### 2. Expectativa incorrecta del caso 3a (30 ítems) — corregida en el test

El criterio original pedía **≥2 páginas para 30 ítems**. La maqueta usa filas de 16 pt y 30 filas caben en una sola A4; **no era un bug del generador**. El caso 3a verifica nombres, total único y validez del PDF, sin exigir mínimo de páginas. La paginación real se comprueba en el caso 3c (45 ítems → 2 páginas).

### 3. Formato monetario es-CR observado

`ToString("C2", es-CR)` produce separador de miles con espacio duro (`U+00A0`): `₡4 500,00`, no `₡4.500,00`. PdfPig además separa palabras con `U+00A0`. Las aserciones normalizan espacios duros antes de comparar; por eso se acepta `4 500,00`. No es un defecto, pero conviene documentar el formato real.

## Huecos de cobertura

- No se ejecutó el bucle real de `CorreoPedidos` contra SQL (por diseño, sin base de datos). La integración se validó solo por reflexión sobre `CrearMensaje`.
- No se usó SMTP real; el outbox se validó en `Test` con `LAVAFACIL_CORREO_SALIDA`.
- La comparación de rutas del outbox usa `Path.GetFullPath`; no se probaron symlinks, junctions ni rutas UNC.
- Los boundaries se validan por patrón `lavafacil-<guid:N>` en una sola ejecución; no se comprueba unicidad entre ejecuciones distintas (el generador usa `Guid.NewGuid`, pero la prueba no lo stressa).
- No se cubrió el alias `PagoConfirmado` (se probó `ComprobantePago`; el código los trata igual).
- No se cubrieron `idPedido <= 0` ni `idPago <= 0`.
- El límite de 1.5 MB se probó con `maximoBytes: 10`; no se generó un PDF real cercano al límite.
- La extracción de texto normaliza `U+00A0`; no se valida el espaciado exacto del PDF visual.
- El parser MIME del harness es una regex ajustada al escritor propio, no un parser MIME general.
- PDFsharp usa fuentes Windows/Arial; el harness asume Windows. En Linux habría que configurar fuentes.
- No se probó concurrencia ni el comportamiento de un cliente de correo real con el `.eml`.

## Limpieza

- Los directorios temporales `lavafacil-adjuntopdf-*` y el scratch de la corrida previa se eliminaron; el harness limpia sus propios temporales en `finally`.
- Se eliminó el `.eml` binario de evidencia `caso7.eml`. La nota anterior decía que ya se había eliminado, pero el archivo seguía presente; ahora sí se borró. Se conservan las versiones normalizadas en texto (`caso7-eml-normalizado.txt`, `caso8-eml-normalizado.txt`, `caso9-eml-normalizado.txt`).
- Se eliminaron `bin/` y `obj/` del harness.
- `LavaFacil.Web/Data/*.dpapi` no se modificó. Hashes SHA-256 y `LastWriteTime` anteriores al 2026-11-07 en `integridad-data.txt`.
- No se modificó código de producción ni SQL.

## Evidencia

- `resultados.json` — PASS/FAIL estructurado por caso (16 casos).
- `ejecucion-consola.txt` — salida real de la ejecución.
- `build-harness-release.txt` — build del harness.
- `build-web-release.txt` — build web Release (0/0), independiente del harness.
- `caso1-texto-extraido.txt`, `caso2-texto-extraido.txt`, `caso3a-texto-extraido.txt`, `caso3b-texto-extraido.txt`, `caso3c-texto-extraido.txt`, `caso4-texto-extraido.txt`, `caso4b-texto-extraido.txt`, `caso4c-texto-extraido.txt` — texto extraído con PdfPig.
- `caso7-eml-normalizado.txt`, `caso8-eml-normalizado.txt`, `caso9-eml-normalizado.txt` — sobres MIME normalizados.
- `caso9-advertencia.txt` — advertencia de adjuntos inválidos.
- `integridad-data.txt` — hashes y fechas de `Data/*.dpapi`.
- `ComprobantePdf.Pruebas/` — proyecto reutilizable del harness.
