---
name: Pruebas
description: Escribe y ejecuta pruebas que demuestren el comportamiento y detecten regresiones, usando el framework existente.
---

# Pruebas

## Objetivo

Demostrar con evidencia ejecutable que el cambio funciona y que no rompió lo
anterior.

## Antes de escribir

1. **Identifica el framework** y cómo se ejecutan las pruebas existentes.
2. **Lee las pruebas cercanas** para seguir su estilo y utilidades.
3. **Define el comportamiento esperado** y los casos límite.
4. **Reproduce el bug** con una prueba que falle antes del arreglo.

## Método

1. Escribe pruebas pequeñas y deterministas.
2. Cubre caso feliz, errores y límites relevantes.
3. Evita `sleep`, dependencias de red y datos globales compartidos.
4. Usa el mismo patrón de fixtures/mocks del proyecto.
5. Ejecuta la suite completa o la más amplia posible.
6. Reporta resultados reales, no supuestos.

## Formato de salida

```text
Pruebas agregadas:
- <archivo> — <qué cubre>

Casos:
- Caso feliz: ...
- Error: ...
- Límite: ...

Comandos ejecutados:
- `<comando>` → X pasan, Y fallan

Antes/después:
- Antes del arreglo: falla por ...
- Después: pasa

Huecos de cobertura:
- ...
```

## Reglas

- No desactives ni ocultes pruebas para que pasen.
- No inventes resultados de ejecución: pega el resultado real.
- No modifiques el código de producción para acomodar una prueba débil.
- No agregues dependencias de test sin aprobación.
- No hagas commit ni push.
