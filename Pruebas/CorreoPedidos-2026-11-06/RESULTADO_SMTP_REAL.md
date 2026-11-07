# Resultado SMTP real — 2026-11-06

## Resultado: PASS controlado

### SMTP_DIRECTO

- PASS: `System.Net.Mail.SmtpClient` ejecutado directamente desde PowerShell.
- `correo.dpapi` se leyó en memoria con DPAPI `CurrentUser`; no se imprimieron JSON, clave, usuario completo, remitente ni cuerpo sensible.
- Host no secreto: `smtp.gmail.com`; puerto `587`; SSL `True`; tiempo `1659 ms`.
- Envío dirigido al remitente configurado. Excepción SMTP: no aplica.
- No se usó endpoint HTTP para demostrar SMTP directo.

### API_WORKER

- PASS: aplicación `Production` en `127.0.0.1:5091`, `outboxActivo=false`.
- PASS: flujo web correcto: bootstrap → CSRF/cookie → cuenta temporal → login → cliente temporal → servicio → pedido.
- PASS: pedido HTTP aceptado y worker procesó la cola; `CorreoEnvios=Enviado`.
- No se omitieron tokens CSRF; no se guardaron contraseña, cuerpo completo, códigos ni destinatarios en evidencias.

## Limpieza

- PASS final: usuarios, empleado, cliente, pedido, detalle, pagos, `CorreoEnvios` y tokens temporales: `0` residuales.
- PASS: aplicación detenida; puerto `5091` cerrado; no quedaron XML en `LavaFacil.Web/keys`.
- No se modificaron código/SQL ni `correo.dpapi`/`connection.dpapi`; no hubo commit/push.

## Comandos ejecutados y resultados

- `dotnet build .\LavaFacil.Web\LavaFacil.Web.csproj --no-restore` → PASS, `0 errores`.
- PowerShell DPAPI en memoria + `SmtpClient.Send` → PASS, `1659 ms`.
- Arranque Production + flujo CSRF/cookie/pedido + espera del worker → PASS, `CorreoEnvios=Enviado`.
- Limpieza/verificación SQL y detención del proceso → PASS, residuales `0`.

## Huecos de cobertura

- `bandeja=NO_VERIFICADA`: esta prueba confirma aceptación SMTP y procesamiento local, no lectura de la bandeja.
- No se probó recepción final, rebote, spam ni reintentos SMTP agotados.
