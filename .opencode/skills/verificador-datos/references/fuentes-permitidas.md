# Jerarquía de fuentes y señales de alerta

## Niveles de confianza

| Nivel | Tipo de fuente | Uso recomendado |
| --- | --- | --- |
| A | Registro público, documento oficial, informe con metodología | Dato firme |
| B | Prensa reconocida, asociación sectorial, universidad | Dato firme con cita |
| C | Sitio oficial de la empresa | Declaración de la empresa, no validación externa |
| D | Directorio comercial, blog, reseña agregada | Contexto; requiere contraste |
| E | Red social, foro, contenido generado por IA | Solo como pista, nunca como dato |

## Señales de alerta

- Cifra sin unidad, año ni metodología.
- Fuente que no existe o devuelve error.
- Fuente que habla del sector pero no de la empresa o cifra citada.
- Dato copiado de un blog que a su vez no cita fuente.
- Porcentaje "redondo" sin estudio detrás.
- Estadística de otro país presentada como local.
- Afirmación en presente sobre un dato de hace más de 3 años.

## Reglas de decisión

1. Fuente nivel A o B + fecha vigente → **APROBADO**.
2. Fuente nivel C → **APROBADO** solo como "la empresa declara".
3. Fuente nivel D → **OBSERVADO**; usar con matiz o contrastar.
4. Fuente nivel E o sin fuente → **RECHAZADO**.
5. Dos fuentes fiables que se contradicen → **OBSERVADO** y explicar la
   discrepancia.

## Prohibiciones

- No completar cifras faltantes con estimaciones propias presentadas como
  datos.
- No citar una fuente que no se haya abierto y leído.
- No convertir una inferencia en hecho.
