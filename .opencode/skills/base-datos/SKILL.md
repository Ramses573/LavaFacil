---
name: Base de datos
description: Diseña e implementa esquema, migraciones, índices y consultas, con cambios reversibles, idempotentes y sin pérdida de datos.
---

# Base de datos

## Objetivo

Cambiar el esquema y las consultas de forma segura, reversible y verificable.

## Antes de escribir

1. **Lee el esquema actual**: tablas, tipos, claves, índices, constraints y
   relaciones.
2. **Revisa las migraciones existentes** y su convención (nombres, orden,
   herramientas).
3. **Identifica el volumen y el uso** de las tablas afectadas.
4. **Verifica el motor** y su versión (SQL Server, PostgreSQL, MySQL, etc.).

## Método

1. Diseña la migración **hacia adelante** y su **reversa**.
2. Hazla **idempotente** cuando el motor lo permita.
3. Agrega índices solo con una consulta que los justifique.
4. Usa constraints para proteger la integridad.
5. Evita bloqueos largos y operaciones destructivas sin respaldo.
6. Actualiza modelos, repositorios y consultas afectadas.
7. Prueba en un entorno de desarrollo con datos representativos.

## Formato de salida

```text
Cambios de esquema:
- <tabla> — <cambio>

Migración:
- Archivo: ...
- Hacia adelante: ...
- Reversa: ...
- Idempotente: sí/no — cómo

Índices:
- <índice> — consulta que justifica: ...

Impacto en código:
- <archivo> — <cambio>

Verificación:
- Comando ejecutado: ...
- Resultado: ...

Despliegue:
1. Respaldo
2. ...

Riesgos / datos a preservar:
- ...
```

## Reglas

- **Sin pérdida de datos** no autorizada explícitamente.
- No renombres ni elimines columnas en uso sin plan de transición.
- No inventes el motor ni la versión; verifícalos.
- No ejecutes migraciones en producción.
- No hagas commit ni push.

## Referencia

Consulta `references/checklist-migraciones.md`.
