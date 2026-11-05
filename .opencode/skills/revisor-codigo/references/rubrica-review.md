# Rúbrica de revisión de código

## Criterios

| Criterio | Pregunta clave | Peso |
| --- | --- | --- |
| Corrección | ¿Hace lo que dice y cubre casos límite? | 30% |
| Regresiones | ¿Rompe algo existente? | 20% |
| Pruebas | ¿Hay pruebas y pasan? | 15% |
| Seguridad | ¿Introduce un riesgo? | 15% |
| Mantenibilidad | ¿Es claro y consistente con el repo? | 10% |
| Rendimiento | ¿Hay N+1, bucles o consultas costosas? | 10% |

## Veredicto

- **APROBADO**: sin hallazgos críticos/altos y pruebas en verde.
- **CAMBIOS SOLICITADOS**: cualquier hallazgo crítico o alto, o pruebas
  fallando.

## Banderas rojas

- Código muerto o comentado sin explicación.
- `catch` vacío o errores silenciados.
- `SELECT *` en consultas nuevas.
- Falta de validación en el borde.
- Tests desactivados o `skip`.
- Secretos en el código.
- Cambios no relacionados con la tarea.
- Dependencia nueva sin justificación.

## Formato de hallazgo

```
[Severidad] archivo:línea — Problema
Por qué: ...
Sugerencia: ...
```
