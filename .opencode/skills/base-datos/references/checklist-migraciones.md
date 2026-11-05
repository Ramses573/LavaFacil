# Checklist de migraciones

## Antes

- [ ] Respaldo verificado de las tablas afectadas.
- [ ] Esquema actual leído (tipos, claves, índices, constraints).
- [ ] Volumen estimado de filas.
- [ ] Ventana de mantenimiento acordada si hay bloqueos.
- [ ] Plan de reversa escrito.

## Durante

- [ ] La migración es idempotente o tiene control de versión.
- [ ] No hay `DROP`/`TRUNCATE` sin autorización.
- [ ] Los `NOT NULL` nuevos tienen valor por defecto o backfill.
- [ ] Los índices se crean después del backfill cuando aplique.
- [ ] Las claves foráneas respetan el orden de creación.
- [ ] Los tipos son compatibles con los datos existentes.

## Después

- [ ] Conteos antes/después coinciden.
- [ ] Constraints e índices existen y son válidos.
- [ ] Las consultas afectadas siguen usando índices.
- [ ] Modelos y repositorios actualizados.
- [ ] Pruebas de integración en verde.
- [ ] Plan de reversa probado en desarrollo.

## Señales de alerta

- Migración que reescribe una tabla grande en una sola transacción.
- Cambio de tipo que trunca datos.
- Índice duplicado o redundante.
- `SELECT *` en consultas nuevas.
- Falta de `WHERE` en un `UPDATE`/`DELETE`.
