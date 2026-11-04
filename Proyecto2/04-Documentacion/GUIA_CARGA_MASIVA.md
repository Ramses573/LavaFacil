# Guía de carga masiva

Todas las cargas se realizan contra la única instancia principal definida para el Proyecto 2 y sobre la base `LavaFacil`. Este avance no utiliza mirroring ni replicación.

## Orden coordinado

| Paso | Tabla | Responsable | Método |
|---:|---|---|---|
| 1 | Clientes | Rachel | BCP |
| 2 | Empleados | Ramses | Asistente SSMS |
| 3 | Servicios | Rachel | BCP |
| 4 | Promociones | Rachel | BCP |
| 5 | Inventario | Ramses | Asistente SSMS |
| 6 | Usuarios | Ramses | Asistente SSMS |
| 7 | Pedidos | Rachel | BCP |
| 8 | Recolecciones | Ramses | Asistente SSMS |
| 9 | DetallePedido | Ramses | Asistente SSMS |
| 10 | Pagos | Rachel | BCP |

El orden evita violaciones de llaves foráneas. Antes de empezar, ejecutar una consulta de los IDs existentes y confirmar que el rango 2001–2003 esté libre.

## Rachel — BCP

Abrir PowerShell en `02-Datos-Carga/Rachel-BCP`. Sustituir `SERVIDOR` y `USUARIO_SQL`. Si se omite `-P`, BCP solicita la contraseña sin dejarla escrita en el comando.

```powershell
bcp LavaFacil.dbo.Clientes in "01_Clientes.csv" -S "SERVIDOR" -U "USUARIO_SQL" -d LavaFacil -c -C 65001 -t";" -F 2 -E
bcp LavaFacil.dbo.Servicios in "03_Servicios.csv" -S "SERVIDOR" -U "USUARIO_SQL" -d LavaFacil -c -C 65001 -t";" -F 2 -E
bcp LavaFacil.dbo.Promociones in "04_Promociones.csv" -S "SERVIDOR" -U "USUARIO_SQL" -d LavaFacil -c -C 65001 -t";" -F 2 -E
bcp LavaFacil.dbo.Pedidos in "07_Pedidos.csv" -S "SERVIDOR" -U "USUARIO_SQL" -d LavaFacil -c -C 65001 -t";" -F 2 -E
bcp LavaFacil.dbo.Pagos in "10_Pagos.csv" -S "SERVIDOR" -U "USUARIO_SQL" -d LavaFacil -c -C 65001 -t";" -F 2 -E
```

`-F 2` omite el encabezado, `-E` conserva los valores identity, `-C 65001` usa UTF-8 y `-t";"` establece el separador. Ejecutar cada comando solamente cuando corresponda según la tabla anterior.

Capturar por cada tabla: archivo fuente, comando ejecutado, cantidad de filas copiadas y un `SELECT` que muestre los tres registros.

## Ramses — Asistente de importación de SSMS

Para cada archivo de `02-Datos-Carga/Ramses-SSMS`:

1. Clic derecho en `LavaFacil` → Tareas → Importar datos.
2. Elegir `Flat File Source` y seleccionar el CSV correspondiente.
3. Marcar que la primera fila contiene nombres de columnas, codificación UTF-8 y delimitador punto y coma.
4. Elegir como destino el SQL Server principal y la base `LavaFacil`.
5. Seleccionar la tabla existente; no crear una tabla nueva.
6. En asignaciones, confirmar nombres y tipos, y activar la conservación de identidad.
7. En `Usuarios`, verificar que las celdas vacías de `IdCliente` o `IdEmpleado` se interpreten como `NULL`.
8. Ejecutar, comprobar tres filas transferidas y guardar captura del resultado.
9. Ejecutar un `SELECT` sobre los IDs 2001–2003 y guardar otra captura.

## Comprobación final

Ejecutar `01-Script/04_Verificacion_Proyecto2.sql` y comprobar tres registros por tabla. El repositorio incluye `01-Script/00_LavaFacil_Proyecto2_ENTREGA_FINAL.sql`, que reconstruye estructura, procedimientos, datos y seguridad en una base nueva.
