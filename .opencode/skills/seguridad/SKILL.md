---
name: Seguridad
description: Revisa secretos, autenticación, autorización, inyección, XSS/CSRF, validación de entradas, dependencias y permisos, reportando por severidad.
---

# Seguridad

## Objetivo

Detectar riesgos de seguridad en el cambio antes de que llegue a producción y
proponer una remediación concreta.

## Revisión

1. **Secretos**: claves, tokens, contraseñas y cadenas de conexión fuera del
   código y del historial.
2. **Autenticación**: sesiones, tokens, expiración, refresh y cierre.
3. **Autorización**: cada endpoint y acción valida permisos del recurso.
4. **Inyección**: SQL/NoSQL, comandos, rutas y plantillas.
5. **XSS/CSRF**: escape de salida, cookies, tokens y métodos.
6. **Validación de entradas**: tipo, longitud, formato y límites.
7. **Dependencias**: versiones vulnerables y paquetes abandonados.
8. **Exposición de datos**: logs, errores, respuestas y archivos.
9. **Configuración**: CORS, cabeceras, HTTPS y permisos de archivos.

## Formato de salida

```text
Resumen: <crítico / alto / medio / bajo>

| # | Severidad | Hallazgo | Ubicación | Remediación |
| --- | --- | --- | --- | --- |
| 1 | Crítica | ... | archivo:línea | ... |

Detalles:
- <hallazgo>
  - Evidencia: ...
  - Impacto: ...
  - Cómo verificar el arreglo: ...

Sin hallazgos en:
- ...

Riesgos aceptados / pendientes:
- ...
```

## Reglas

- Reporta con **archivo:línea** y evidencia concreta.
- No edites archivos ni implementes el arreglo.
- No inventes vulnerabilidades; si no puedes verificar, dilo.
- Prioriza por impacto real, no por cantidad.
- No expongas secretos en el informe: redáctalos.
- No hagas commit ni push.

## Referencia

Consulta `references/checklist-seguridad.md`.
