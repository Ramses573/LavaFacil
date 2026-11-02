# BCP de Rachel — preparado, no ejecutado

Abrir PowerShell en esta carpeta. Sustituir SERVIDOR_PRINCIPAL y USUARIO_SQL
por la instancia confirmada y una cuenta autorizada para importar. La cuenta
GraphQL de invitado/empleado solo tiene EXECUTE: no asumir que sirve para BCP.
Se omite -P para que BCP solicite la contraseña; no guardarla en archivos/capturas.

Primero ejecutar `python validar_csv.py --alcance rachel` y revisar las consultas
de `VERIFICACION_RACHEL.sql`. Confirmar manualmente esquema desplegado, IDs y
claves únicas libres, rol PRINCIPAL y coordinación con Ramsés. No ejecutar los
cinco comandos seguidos ni repetir una carga sin revisar qué filas se insertaron.

Los cinco archivos actuales son UTF-8 y tienen cuatro líneas CRLF cada uno.
`-r 0x0d0a` coincide explícitamente con esos bytes. Si cambian los finales de
línea, revisar este parámetro antes de cargar. BCP no interpreta comillas CSV:
estos datos no contienen punto y coma ni saltos de línea dentro de un campo.

## Paso 1 — Clientes

```powershell
bcp dbo.Clientes in "01_Clientes.csv" -S "SERVIDOR_PRINCIPAL" -U "USUARIO_SQL" -d LavaFacil -c -C 65001 -t ";" -r 0x0d0a -F 2 -E -h "CHECK_CONSTRAINTS,FIRE_TRIGGERS" -e "../../05-Capturas/BCP/Clientes/errores-bcp.txt"
```

Esperar el paso 2 de Ramsés (Empleados).

## Paso 3 — Servicios

```powershell
bcp dbo.Servicios in "03_Servicios.csv" -S "SERVIDOR_PRINCIPAL" -U "USUARIO_SQL" -d LavaFacil -c -C 65001 -t ";" -r 0x0d0a -F 2 -E -h "CHECK_CONSTRAINTS,FIRE_TRIGGERS" -e "../../05-Capturas/BCP/Servicios/errores-bcp.txt"
```

## Paso 4 — Promociones

```powershell
bcp dbo.Promociones in "04_Promociones.csv" -S "SERVIDOR_PRINCIPAL" -U "USUARIO_SQL" -d LavaFacil -c -C 65001 -t ";" -r 0x0d0a -F 2 -E -h "CHECK_CONSTRAINTS,FIRE_TRIGGERS" -e "../../05-Capturas/BCP/Promociones/errores-bcp.txt"
```

Esperar pasos 5 y 6 de Ramsés (Inventario y Usuarios).

## Paso 7 — Pedidos

```powershell
bcp dbo.Pedidos in "07_Pedidos.csv" -S "SERVIDOR_PRINCIPAL" -U "USUARIO_SQL" -d LavaFacil -c -C 65001 -t ";" -r 0x0d0a -F 2 -E -h "CHECK_CONSTRAINTS,FIRE_TRIGGERS" -e "../../05-Capturas/BCP/Pedidos/errores-bcp.txt"
```

Esperar pasos 8 y 9 de Ramsés (Recolecciones y DetallePedido). Debe resolver los
estados incompatibles de Recolecciones: En camino → Programada y Completada →
Recolectada son propuestas; él debe confirmar el significado antes de corregir.
Para DetallePedido, confirmar que el asistente ejecute el trigger que recalcula
Pedidos.Total y comprobar 3600, 6500 y 6000 para los pedidos 2001–2003.

## Paso 10 — Pagos

```powershell
bcp dbo.Pagos in "10_Pagos.csv" -S "SERVIDOR_PRINCIPAL" -U "USUARIO_SQL" -d LavaFacil -c -C 65001 -t ";" -r 0x0d0a -F 2 -E -h "CHECK_CONSTRAINTS,FIRE_TRIGGERS" -e "../../05-Capturas/BCP/Pagos/errores-bcp.txt"
```

## Restricciones, triggers y evidencia

- `-F 2`: omitir encabezado; `-E`: conservar identity 2001–2003.
- `CHECK_CONSTRAINTS`: comprobar CHECK y FK durante la importación. PK y UNIQUE
  se comprueban de todos modos. No deshabilitar restricciones ni triggers.
- `FIRE_TRIGGERS`: ejecutar triggers de inserción. En estas cinco tablas el
  script define uno en Pagos: rechaza pagos confirmados superiores al total.
  El segundo trigger pertenece a DetallePedido y lo debe atender Ramsés.
- Confirmar los permisos necesarios de la cuenta de carga con quien administra
  SQL; no conceder permisos ni ejecutar cambios de seguridad desde este paquete.
- Verificar código de salida, tres filas copiadas, archivo de errores y SELECT
  posterior. Tres filas en consola no bastan para demostrar valores correctos.
- Guardar por tabla: `01-fuente.png`, `02-comando-resultado.png`,
  `03-select.png`; añadir evidencia de error solo si ocurre realmente. Ocultar
  contraseñas y tokens. No hay capturas creadas por esta preparación.

Referencias: [opciones y permisos BCP](https://learn.microsoft.com/sql/tools/bcp-utility?view=sql-server-ver17),
[terminadores](https://learn.microsoft.com/sql/relational-databases/import-export/specify-field-and-row-terminators-sql-server).
