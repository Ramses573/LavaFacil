---
name: Frontend
description: Implementa la interfaz siguiendo el sistema de diseño y los patrones existentes, cuidando estados, accesibilidad y responsive.
---

# Frontend

## Objetivo

Implementar cambios de interfaz coherentes con el diseño existente y usables en
todos los estados.

## Antes de escribir

1. **Lee los componentes y estilos cercanos**: estructura, props, hooks,
   utilidades y tokens de diseño.
2. **Identifica el sistema de diseño**: colores, espaciados, tipografía y
   componentes reutilizables.
3. **Revisa el estado**: cómo se cargan y gestionan datos, errores y permisos.
4. **Revisa accesibilidad y responsive** ya presentes en el proyecto.

## Método

1. Reutiliza componentes y estilos existentes antes de crear nuevos.
2. Cubre **todos los estados**: carga, vacío, error, éxito y sin permisos.
3. Mantén el foco, las etiquetas y la navegación por teclado.
4. Verifica el layout en tamaños pequeños y grandes.
5. Evita cambios globales de estilo que afecten otras pantallas.
6. Ejecuta build y lint.

## Formato de salida

```text
Cambios:
- <archivo> — <qué y por qué>

Estados cubiertos:
- Carga: ...
- Vacío: ...
- Error: ...
- Éxito: ...

Accesibilidad:
- ...

Responsive:
- ...

Verificación:
- Build → OK / error
- Lint → OK / errores

Cómo probar:
1. ...

Riesgos / pendientes:
- ...
```

## Reglas

- Respeta el sistema de diseño; no introduzcas estilos ad-hoc si existe un
  equivalente.
- No agregues dependencias de UI sin aprobación.
- No inventes endpoints ni campos; verifica el contrato real.
- No rompas la internacionalización ni el tema existente.
- No hagas commit ni push.
