# Equipo de desarrollo de software

Preset declarativo para OpenCode V2. Define **1 orquestador** (agente primario) y **7 especialistas** (subagentes), cada uno con su skill metodológica.

## Archivos

| Archivo | Propósito |
| --- | --- |
| `opencode.jsonc` (raíz del proyecto) | Preset: agentes, roles y permisos. |
| `.opencode/skills/<id>/SKILL.md` | Método y formato de salida de cada capa. |
| `.opencode/README.md` | Esta guía. |

## Agentes

| ID | Modo | Rol | Skill |
| --- | --- | --- | --- |
| `orquestador` | primary | Analiza, descompone, coordina, verifica y entrega. No implementa. | — |
| `arquitecto` | subagent | Diseño técnico, archivos afectados, interfaces y riesgos. | `arquitecto` |
| `backend` | subagent | Lógica de servidor, servicios y API. | `backend` |
| `frontend` | subagent | Interfaz, estados, accesibilidad y responsive. | `frontend` |
| `base-datos` | subagent | Esquema, migraciones, índices y consultas. | `base-datos` |
| `pruebas` | subagent | Pruebas y verificación de regresiones. | `pruebas` |
| `seguridad` | subagent | Revisión de seguridad por severidad. | `seguridad` |
| `revisor-codigo` | subagent | Revisión del diff y veredicto. | `revisor-codigo` |

## Flujo

```
Solicitud
   │
   ▼
orquestador ──► arquitecto (plan técnico)
   │                 │
   │                 ▼
   │        base-datos ──► backend / frontend
   │                              │
   │                              ▼
   │                          pruebas
   │                              │
   │                              ▼
   │                    seguridad + revisor-codigo
   │                              │
   └──────────────────────────────┴──► entrega
```

## Uso

1. Abre una sesión en este proyecto: el agente por defecto es `orquestador`.
2. Describe la tarea, por ejemplo:
   ```
   Agrega validación al endpoint de clientes y sus pruebas.
   ```
3. El orquestador revisa el repo, propone un plan, delega en los especialistas y
   te pide aprobación si el cambio es grande.
4. Al final entrega: archivos cambiados, cómo probar, riesgos y pendientes.

Para cambiar de agente manualmente, usa el selector de agentes de la TUI.
Para recargar cambios de configuración: `/reload`.

## Reglas de calidad

- Nada se entrega sin build/tests ejecutados.
- El arquitecto diseña antes de implementar en tareas no triviales.
- Seguridad y revisión de código son obligatorias antes de cerrar.
- No se hace commit ni push sin autorización explícita.
- Los subagentes respetan el estilo y las convenciones del repo.

## Validación

```sh
opencode debug agents    # lista los agentes montados
opencode debug config    # muestra las fuentes de configuración
opencode reload          # recarga sin reiniciar
```

## Desactivar el preset

Elimina `opencode.jsonc` o cambia `default_agent` a `build`. Las skills de
`.opencode/skills/` no afectan al resto del proyecto si no se cargan.
