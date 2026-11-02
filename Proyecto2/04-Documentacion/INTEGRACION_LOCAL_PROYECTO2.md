# Integración local de Proyecto 2 — 1 de noviembre de 2026

Integración de `4e5c437` (Ramsés) en `codex/integracion-proyecto2`.
`main` permanece en `2ff0797`; no se realizó push.

## Protección del trabajo

- Respaldo externo verificado: `C:\Github\LavaFacil-Respaldos\antes-integracion-Ramses_2026-11-01_19-24-49_CR`.
- Los 21 archivos coincidían con el manifiesto SHA-256 antes de integrar.
- Commit local de respaldo: `05c00bf`, con los 20 archivos de trabajo.
- El PDF del enunciado permanece sin seguimiento y también tiene respaldo externo.
- No se incluyeron credenciales, configuraciones privadas, certificados, cachés ni binarios.

## Conciliación

- Conflicto textual en `GraphQL/Models.cs`: se conservan los anulables
  `Servicio.PrecioAdicional` y `Promocion.IdServicio`, y se agrega `Inventario.Activo`.
- Gateway único en `Data/DbGateway.cs`. Se retira la clase duplicada de
  `Infrastructure/DbGateway.cs`, preservada en el commit de respaldo.
- Se conserva la interfaz de Ramsés: parámetros opcionales de consulta,
  `IReadOnlyDictionary`, parámetros con o sin `@` y valores `DBNull`.
- Se conservan los controles de Rachel: login usa Invitado; catálogo anónimo
  usa Invitado; catálogo autenticado usa Cliente o Empleado según el rol;
  consultas internas y escrituras requieren Empleado/Administrador.
- Se conserva el uso de procedimientos en `dbo`, parámetros SQL, timeout de 30
  segundos y conversión de tipos anulables con cultura invariante.
- `RachelQueries` y las pruebas utilizan diccionarios explícitos para compatibilidad
  con `IReadOnlyDictionary`; `Program.cs` conserva el registro de la extensión.
- El ejemplo de conexiones conserva el cambio de Ramsés: sin `Failover Partner`,
  con `Password=CAMBIAR` y servidor de ejemplo. No representa ni modifica la
  configuración real. La revisión de failover requiere una fase autorizada aparte.
- Los tres scripts SQL de carga se integran sin ejecutarlos ni modificarlos.

## Validación local

- `dotnet build Proyecto2/03-Backend-GraphQL/LavaFacil.GraphQL -c Release --no-restore`:
  correcto, cero errores y cero advertencias.
- `dotnet run --project Proyecto2/PruebasLocales -c Release --no-restore`:
  75 comprobaciones correctas. Configuración exclusivamente en memoria con
  conexiones vacías y claves efímeras; no se abre conexión SQL ni servidor HTTP.
- `python Proyecto2/02-Datos-Carga/Rachel-BCP/test_validacion.py`:
  siete pruebas correctas sobre copias temporales. El primer intento fue bloqueado
  por permisos del aislamiento; la repetición autorizada terminó correctamente.
- `validar_csv.py --alcance rachel`: cero incompatibilidades.
- `validar_csv.py`: dos incompatibilidades preexistentes en Recolecciones,
  IDs 2002 y 2003, por estados `En camino` y `Completada` no admitidos por el
  CHECK del script base. No se cambiaron los CSV de Ramsés.
- La primera compilación detectó inicializadores `new()` incompatibles con la
  interfaz de parámetros; fueron corregidos antes de la compilación final.

## Límites y pendientes

No se ejecutaron SQL, BCP, CRUD contra SQL Server ni cambios de mirroring.
Las pruebas verifican esquema GraphQL, permisos antes de SQL y construcción de
comandos; no demuestran integración con una base real ni cargas exitosas.
Antes de cualquier carga deben conciliarse los estados de Recolecciones con
Ramsés y revisarse los scripts contra el esquema desplegado, con autorización.
Los documentos de octubre se conservan como antecedentes; este informe describe
la conciliación local actual. No se autoriza publicación ni modificación de main.
