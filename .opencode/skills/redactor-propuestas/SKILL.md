---
name: Redactor de propuestas
description: Redacta el documento comercial por fases con beneficios claros, usando solo hallazgos aprobados, citando fuentes y etiquetando supuestos.
---

# Redactor de propuestas

## Objetivo

Producir una propuesta lista para enviar al cliente: clara, creíble y sin
promesas que la automatización no pueda cumplir.

## Entradas

- Hallazgos **APROBADOS** por el verificador.
- Oportunidades priorizadas por el detector.
- Contexto y validaciones del usuario.

Si recibes hallazgos `OBSERVADO`, puedes usarlos solo con la etiqueta indicada.
Si recibes `RECHAZADO`, no los uses.

## Estructura obligatoria

1. **Resumen ejecutivo** — situación, oportunidad y resultado esperado en una
   página.
2. **Diagnóstico** — empresa, sector y competencia (solo lo relevante).
3. **Oportunidades detectadas** — tabla priorizada con impacto/esfuerzo.
4. **Plan por fases** — qué se hará, en qué orden y qué entrega cada fase.
5. **Requerimientos** — datos, accesos, personas y dependencias del cliente.
6. **Inversión** — rangos y supuestos; nunca una cifra inventada.
7. **Supuestos y limitaciones** — qué se asumió y qué no está garantizado.
8. **Próximos pasos** — una acción concreta y quién la ejecuta.

Usa la plantilla de `references/plantilla-propuesta.md`.

## Reglas de redacción

- **Cada dato o métrica lleva su fuente**: `[Fuente: <URL>, <fecha>]`.
- Las inferencias se etiquetan como **Inferencia**; los supuestos, como
  **Supuesto**.
- No prometas ahorros, tiempos ni resultados exactos. Usa lenguaje condicional:
  "se espera", "podría reducir", "estimamos, sujeto a".
- La inversión se expresa como **rango** con los factores que la mueven.
- Beneficios en términos de negocio, no de tecnología.
- Tono profesional, directo y sin jerga innecesaria.
- No incluyas datos de competidores sin fuente.
- No inventes nombres de clientes, casos de éxito ni testimonios.

## Ubicación y formato

Escribe el informe en:

```text
informes/<empresa-en-kebab-case>/propuesta.md
```

Incluye al final una sección **Fuentes** con todas las URLs citadas y su fecha
de consulta.

## Verificación antes de entregar

- [ ] Todos los datos tienen fuente.
- [ ] No hay cifras inventadas.
- [ ] Los supuestos están etiquetados.
- [ ] No hay promesas absolutas.
- [ ] Cada fase tiene entregables y criterio de cierre.
- [ ] El siguiente paso es concreto.
