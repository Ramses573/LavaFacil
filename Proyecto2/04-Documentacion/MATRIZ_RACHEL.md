# Estado de Rachel — 27 de octubre de 2026

Preparación local completa para la siguiente sesión coordinada. No hubo push,
merge, BCP, conexión SQL, cambios de datos/permisos ni mirroring en esta fase.
El esquema comprobado es el script SQL del repositorio, no una lectura del servidor.

## Matriz

| Tabla | CSV validado | BCP | SELECT 2001–2003 | Procedimientos | Queries GraphQL | Mutations | Roles | Pruebas ejecutadas | Evidencias pendientes |
|---|---|---|---|---|---|---|---|---|---|
| Clientes | Sí, 3 filas | Paso 1 preparado | Preparado | ConsultarClientes (tipos 1/2), InsertarCliente, ActualizarCliente, EliminarCliente | clientes / clientePorId | insertarCliente / actualizarCliente / eliminarCliente | Lectura y CRUD: Empleado/Administrador | CSV, contrato SQL/resolver, esquema, rechazo sin token | Fuente, BCP con 3 filas, SELECT, consultas y CRUD reales |
| Servicios | Sí, 3 filas | Paso 3 preparado | Preparado | ConsultarServicios (tipos 1/2), InsertarServicio, ActualizarServicio, EliminarServicio | servicios / servicioPorId | insertarServicio / actualizarServicio / eliminarServicio | Lectura pública; CRUD: Empleado/Administrador | CSV, contrato SQL/resolver, esquema, rechazo de eliminación sin token | Fuente, BCP con 3 filas, SELECT, consultas y CRUD reales |
| Promociones | Sí, 3 filas | Paso 4 preparado | Preparado | ConsultarPromociones (tipos 1/2), InsertarPromocion, ActualizarPromocion, EliminarPromocion | promociones / promocionPorId | insertarPromocion / actualizarPromocion / eliminarPromocion | Lectura pública; CRUD: Empleado/Administrador | CSV, contrato SQL/resolver, esquema, rechazo de eliminación sin token | Fuente, BCP con 3 filas, SELECT, consultas y CRUD reales |
| Pedidos | Sí, 3 filas | Paso 7 preparado | Preparado | ConsultarPedidos (tipos 1/2), InsertarPedido, ActualizarPedido, EliminarPedido | pedidos / pedidoPorId | insertarPedido / actualizarPedido / eliminarPedido | Lectura y CRUD: Empleado/Administrador | CSV/importes, contrato SQL/resolver, esquema, rechazo sin token | Fuente, BCP con 3 filas, SELECT, consultas y CRUD reales |
| Pagos | Sí, 3 filas; 2 métodos corregidos | Paso 10 preparado | Preparado | ConsultarPagos (tipos 1/2), InsertarPago, ActualizarPago, EliminarPago | pagos / pagoPorId | insertarPago / actualizarPago / eliminarPago | Lectura y CRUD: Empleado/Administrador | CSV/importes, contrato SQL/resolver, esquema, rechazo sin token | Fuente, BCP con 3 filas, SELECT, trigger y CRUD reales |

“Procedimientos” significa presentes y firmas cotejadas en el script, no ejecutados
ni confirmados como desplegados. “BCP/SELECT preparado” no significa carga realizada.

## Datos y relaciones revisados

- Clientes: 9 columnas; Servicios: 8; Promociones: 8; Pedidos: 7; Pagos: 7.
  Orden compatible con BCP por posición. IDs únicos 2001, 2002, 2003 en cada CSV.
- Promociones.IdServicio → Servicios.IdServicio; Pedidos.IdCliente → Clientes.IdCliente;
  Pagos.IdPedido → Pedidos.IdPedido. Todas las referencias existen en los CSV.
- Se comprobaron tipos/longitudes lógicas, nulabilidad, escala decimal, fechas,
  listas CHECK, restricciones numéricas/fechas de las tablas de Rachel y claves
  únicas locales. Esto no sustituye los tipos/collation ni las claves existentes
  en el servidor; comprobar los acentos tras importar a columnas varchar.
- Totales de Pedidos y suma de DetallePedido: 3600, 6500, 6000. Pagos confirmados:
  3600, 6500, 0; el tercer pago de 3000 sigue Pendiente y no se cambió.
- Pagos 2002: SINPE → SINPE Movil. Pagos 2003: Tarjeta → Efectivo, elegido para
  el dato ficticio porque Tarjeta no existe en CK_Pagos_Metodo. Ningún otro campo
  de los cinco CSV se cambió. No se amplió el CHECK.
- Recolecciones permanece intacta: En camino → Programada y Completada →
  Recolectada son propuestas que Ramsés debe confirmar. El validador global
  devuelve dos errores por esos estados; el alcance Rachel devuelve cero.

## Código y seguridad

Los diez resolvers de consulta de Rachel (cinco generales/cinco por ID) invocan
Consultar* con TipoConsulta 1 o 2. Las quince mutaciones invocan Insertar*,
Actualizar* o Eliminar*; login invoca usp_ValidarLogin. DbGateway construye
SqlCommand de tipo StoredProcedure y parámetros, sin SQL directo en resolvers.
Estado e introspección no consultan la base.

Se agregó RachelQueries como extensión, sin reemplazar Query ni Mutation.
Program solo agrega su registro. En Models se corrigieron dos nulables de tablas
de Rachel para que un NULL SQL no se convierta silenciosamente en cero:
Servicio.PrecioAdicional y Promocion.IdServicio. Los modelos de Ramsés no cambiaron.

DbGateway ahora selecciona Invitado para login/lectura anónima, Cliente para
catálogo con token Cliente, y Empleado para personal autenticado/CRUD. Las tres
cadenas siguen separadas. Cliente no puede consultar datos internos ni ejecutar
CRUD; no se agregó autoservicio ni se ampliaron GRANT. Los permisos del script
03 coinciden con este uso; queda probar permisos efectivos y SID en ambas instancias.

appsettings.json conserva conexiones vacías y el ejemplo usa placeholders,
Initial Catalog y Failover Partner. No se creó configuración privada. Las pruebas
solo usan configuración en memoria con conexiones vacías y claves efímeras:
fallan antes de crear SqlConnection. No usan secretos ni abren servidor HTTP.

Pendientes existentes: token sin caducidad/revocación explícita, errores SQL
devueltos como ex.Message y login por Clave en vez del flujo ClaveHash de la web.
Verificar cuenta de laboratorio válida y compatibilidad de login; los usuarios
CSV de Ramsés están inactivos. No se alteró autenticación compartida para resolver
estos puntos sin coordinación. Las mutaciones reportan ejecución, no cantidad de
filas afectadas: validar siempre el resultado mediante consulta (un ID inexistente
puede devolver éxito del procedimiento sin haber cambiado filas).

## Pruebas y reproducción

Desde C:\Github\LavaFacil:

```powershell
python Proyecto2/02-Datos-Carga/Rachel-BCP/validar_csv.py --alcance rachel
python Proyecto2/02-Datos-Carga/Rachel-BCP/validar_csv.py
python Proyecto2/02-Datos-Carga/Rachel-BCP/test_validacion.py
dotnet run --project Proyecto2/PruebasLocales -c Release
dotnet build Proyecto2/03-Backend-GraphQL/LavaFacil.GraphQL -c Release
```

- Validador Rachel: cero incompatibilidades. Global: dos de Recolecciones,
  código de salida 1 esperado hasta que Ramsés resuelva sus datos.
- Siete pruebas Python correctas: datos esperados, método inválido, FK inexistente,
  escala decimal, clave única duplicada, sobrepago y contratos de los procedimientos.
- 49 comprobaciones .NET correctas: esquema real en memoria, campos de consulta/mutación, estado,
  tokens Cliente/Empleado/Administrador, token inválido, rechazo sin token,
  bloqueo CRUD de Cliente y elección de cadenas sin llegar a SQL.
- Compilación Release correcta, cero advertencias y cero errores.
- Las consultas de datos, login SQL, CRUD real, restricciones/triggers de SQL,
  BCP, permisos efectivos y failover siguen sin ejecutarse.

## Sesión manual y próximos dos días

1. Día 1: revisar esta preparación y acordar con Ramsés las correcciones de sus
   datos; obtener cuenta de carga y cuenta de aplicación de laboratorio. Con
   autorización, comparar esquema desplegado, principal, IDs y claves únicas
   usando VERIFICACION_RACHEL.sql. No reconstruir la base compartida.
2. Día 2: una vez autorizada la carga, ejecutar un comando cada vez en el orden
   intercalado de COMANDOS_BCP_RACHEL.md. Esperar DetallePedido y comprobar
   totales antes de Pagos. Guardar capturas reales por tabla.
3. Con autorización para pruebas que escriben, demostrar insertar–consultar–
   actualizar–eliminar en cada tabla con registros nuevos y aislados. No usar
   los IDs 2001–2003 para borrar: son datos relacionados y evidencia de la carga.
   Usar valores únicos, identificar el ID creado consultando y respetar las FK.
   Probar primero Cliente/Servicio, luego Promocion/Pedido/Pago; limpiar en orden
   inverso. Evitar pagos de prueba Pagado por encima del total y eliminar
   dependencias antes de sus padres. No hay rollback global entre requests GraphQL.
4. Completar el documento de evidencias con portada, índice por tabla, fuente,
   herramienta y resultado; pedir a Ramsés el script final SSMS de estructura y
   datos. La revisión de mirroring/failover se coordina por separado y requiere
   autorización; no se ejecuta desde estas pruebas.

## Archivos de esta fase (rutas relativas a Proyecto2)

Modificados:

- 02-Datos-Carga/Rachel-BCP/10_Pagos.csv
- 02-Datos-Carga/Rachel-BCP/validar_csv.py (agregado en la fase anterior)
- 03-Backend-GraphQL/LavaFacil.GraphQL/Infrastructure/DbGateway.cs (agregado antes)
- 03-Backend-GraphQL/LavaFacil.GraphQL/Program.cs (solo registro de extensión)
- 03-Backend-GraphQL/LavaFacil.GraphQL/GraphQL/Models.cs (dos propiedades de Rachel)
- 04-Documentacion/REVISION_RACHEL.md (actualización de estado)

Nuevos:

- 02-Datos-Carga/Rachel-BCP/.gitignore
- 02-Datos-Carga/Rachel-BCP/test_validacion.py
- 02-Datos-Carga/Rachel-BCP/COMANDOS_BCP_RACHEL.md
- 02-Datos-Carga/Rachel-BCP/VERIFICACION_RACHEL.sql
- 03-Backend-GraphQL/LavaFacil.GraphQL/GraphQL/RachelQueries.cs
- 04-Documentacion/RACHEL_CONSULTAS.graphql
- 04-Documentacion/MATRIZ_RACHEL.md
- 05-Capturas/BCP/Clientes/README.md
- 05-Capturas/BCP/Servicios/README.md
- 05-Capturas/BCP/Promociones/README.md
- 05-Capturas/BCP/Pedidos/README.md
- 05-Capturas/BCP/Pagos/README.md
- PruebasLocales/PruebasLocales.csproj
- PruebasLocales/Program.cs

También se generaron bin/obj y __pycache__ locales, excluidos de Git. La guía
original, scripts SQL de Ramsés, Query.cs, Mutation.cs, Security y Recolecciones
no se modificaron. Tarea programada 2.pdf preexistía sin seguimiento y se leyó,
no se editó. No se creó commit ni se cambió de rama.
