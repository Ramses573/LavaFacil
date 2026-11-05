# Equipo de investigación y propuestas de automatización con IA

Preset declarativo para OpenCode V2. Define **1 orquestador** (agente primario) y **7 especialistas** (subagentes), cada uno con su skill metodológica.

## Archivos

| Archivo | Propósito |
| --- | --- |
| `opencode.jsonc` (raíz del proyecto) | Preset: agentes, roles, modelo por herencia y permisos. |
| `.opencode/skills/<id>/SKILL.md` | Método y formato de salida de cada capa. |
| `.opencode/README.md` | Esta guía. |

## Agentes

| ID | Modo | Rol | Skill |
| --- | --- | --- | --- |
| `orquestador` | primary | Divide, coordina y valida con el usuario. No investiga ni redacta. | — |
| `investigador-empresa` | subagent | Qué hace el negocio, presencia online y comunicación. | `investigador-empresa` |
| `analista-sector` | subagent | Mercado, tendencias y dolores de la industria. | `analista-sector` |
| `analista-competencia` | subagent | Competidores directos/locales y brechas. | `analista-competencia` |
| `detector-oportunidades` | subagent | Tareas repetitivas y cuellos de botella automatizables. | `detector-oportunidades` |
| `verificador-datos` | subagent | Contrasta hechos y cifras; aprueba antes de redactar. | `verificador-datos` |
| `redactor-propuestas` | subagent | Documento comercial por fases. | `redactor-propuestas` |
| `revisor-final` | subagent | Revisión desde la perspectiva del cliente. | `revisor-final` |

## Flujo

```
Solicitud
   │
   ▼
orquestador ──► investigador-empresa ─┐
   │        ──► analista-sector ───────┼─► detector-oportunidades
   │        ──► analista-competencia ──┘            │
   │                                                ▼
   │                                       verificador-datos
   │                                                │ (APROBADO)
   │                                                ▼
   │                                     validación del usuario
   │                                                │
   │                                                ▼
   │                                     redactor-propuestas
   │                                                │
   │                                                ▼
   └────────────────────────────────────────► revisor-final
```

## Uso

1. Abre una sesión en este proyecto: el agente por defecto es `orquestador`.
2. Escribe algo como:
   ```
   Investiga la empresa <nombre> (<ciudad/país>) y prepara una propuesta
   de automatización con IA para enviar al cliente.
   ```
3. El orquestador pedirá los datos que falten, lanzará a los especialistas y
   te pedirá validación antes de redactar.
4. El informe se escribe en `informes/<empresa>/propuesta.md`.

Para usar otro agente manualmente: `/agent` en la TUI o menciona el subagente
en el prompt. Para recargar cambios de configuración: `/reload`.

## Reglas de calidad

- Cada dato y métrica incluye fuente y fecha.
- Cero invención o alucinación de cifras.
- El verificador debe aprobar los hallazgos antes de redactar.
- El revisor final señala explícitamente toda promesa no sustentada.

## Validación

```sh
opencode debug agents    # lista los agentes montados
opencode debug config    # muestra las fuentes de configuración
opencode reload          # recarga sin reiniciar
```

## Desactivar el preset

Elimina `opencode.jsonc` o cambia `default_agent` a `build`. Los archivos de
`.opencode/skills/` no afectan al resto del proyecto si no se cargan.
