using HotChocolate;
using HotChocolate.Execution;
using LavaFacil.GraphQL.Data;
using LavaFacil.GraphQL.GraphQL;
using LavaFacil.GraphQL.Security;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

// No carga appsettings, variables de entorno ni secretos. Las conexiones son vacías.
var services = new ServiceCollection();
services.AddLogging();
services.AddSingleton<IConfiguration>(new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
{
    ["ConnectionStrings:Invitado"] = "", ["ConnectionStrings:Cliente"] = "", ["ConnectionStrings:Empleado"] = ""
}).Build());
services.AddHttpContextAccessor();
services.AddDataProtection().UseEphemeralDataProtectionProvider();
services.AddSingleton<TokenService>();
services.AddScoped<RequestIdentity>();
services.AddScoped<DbGateway>();
services.AddGraphQLServer().AddQueryType<Query>().AddMutationType<Mutation>().AddTypeExtension<RachelQueries>();
await using var provider = services.BuildServiceProvider();
var executor = await provider.GetRequestExecutorAsync();
int passed = 0;
void Check(bool ok, string label)
{
    if (!ok) throw new Exception("FALLO: " + label);
    Console.WriteLine("OK: " + label);
    passed++;
}

var schema = executor.Schema.ToString();
Check(Nullable.GetUnderlyingType(typeof(Servicio).GetProperty("PrecioAdicional")!.PropertyType) == typeof(decimal), "Servicio conserva NULL de PrecioAdicional");
Check(Nullable.GetUnderlyingType(typeof(Promocion).GetProperty("IdServicio")!.PropertyType) == typeof(int), "Promocion conserva NULL de IdServicio");
foreach (var (query, byId, singular) in new[] {
    ("clientes", "clientePorId", "Cliente"), ("servicios", "servicioPorId", "Servicio"),
    ("promociones", "promocionPorId", "Promocion"), ("pedidos", "pedidoPorId", "Pedido"), ("pagos", "pagoPorId", "Pago") })
{
    Check(schema.Contains(query + "(") || schema.Contains(query + ":"), query + " general en esquema");
    Check(schema.Contains(byId + "("), byId + " en esquema");
    foreach (var action in new[] { "insertar", "actualizar", "eliminar" })
        Check(schema.Contains(action + singular + "("), action + singular + " en esquema");
}
var state = (await executor.ExecuteAsync("{ estado }")).ToJson();
Check(state.Contains("LavaFacil GraphQL disponible") && !state.Contains("errors"), "consulta estado ejecutada");
var invalidId = (await executor.ExecuteAsync("{ servicioPorId(idServicio:0) { idServicio } }")).ToJson();
Check(invalidId.Contains("identificador debe ser positivo"), "consulta por ID inválido rechazada antes de SQL");

var accessor = provider.GetRequiredService<IHttpContextAccessor>();
var tokens = provider.GetRequiredService<TokenService>();
accessor.HttpContext = new DefaultHttpContext();
foreach (var role in new[] { "Cliente", "Empleado", "Administrador" })
{
    var token = tokens.Create(new(99, "prueba-local", role));
    accessor.HttpContext.Request.Headers.Authorization = "Bearer " + token;
    using var scope = provider.CreateScope();
    var identity = scope.ServiceProvider.GetRequiredService<RequestIdentity>();
    Check(identity.Current?.Rol == role && identity.IsStaff == (role != "Cliente"), "token y rol " + role);
    if (role == "Cliente")
    {
        try { identity.RequireStaff(); throw new Exception("Cliente autorizado indebidamente"); }
        catch (GraphQLException) { Check(true, "Cliente rechazado por RequireStaff"); }
    }
}
accessor.HttpContext.Request.Headers.Authorization = "Bearer token-invalido";
Check(provider.GetRequiredService<RequestIdentity>().Current is null, "token inválido rechazado");
accessor.HttpContext.Request.Headers.Authorization = "";
foreach (var query in new[] { "{ clientes { idCliente } }", "{ pedidos { idPedido } }", "{ pagos { idPago } }",
    "{ clientePorId(idCliente:2001) { idCliente } }", "{ pedidoPorId(idPedido:2001) { idPedido } }", "{ pagoPorId(idPago:2001) { idPago } }",
    "mutation { eliminarCliente(idCliente:2001) { exito } }", "mutation { eliminarServicio(idServicio:2001) { exito } }",
    "mutation { eliminarPromocion(idPromocion:2001) { exito } }", "mutation { eliminarPedido(idPedido:2001) { exito } }",
    "mutation { eliminarPago(idPago:2001) { exito } }" })
{
    var json = (await executor.ExecuteAsync(query)).ToJson();
    Check(json.Contains("requiere una cuenta"), "operación protegida sin token: " + query);
}
// Comprobar selección de conexión sin llegar a crear una conexión SQL.
using (var scope = provider.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<DbGateway>();
    try { await db.QueryAsync<Servicio>("ConsultarServicios", new Dictionary<string, object?>(), publicRead: true); throw new Exception("Se esperaba conexión vacía"); }
    catch (InvalidOperationException ex) { Check(ex.Message.Contains("Invitado"), "público usa Invitado y falla antes de SQL"); }
    accessor.HttpContext.Request.Headers.Authorization = "Bearer " + tokens.Create(new(99, "prueba-local", "Cliente"));
    try { await db.QueryAsync<Servicio>("ConsultarServicios", new Dictionary<string, object?>(), publicRead: true); throw new Exception("Se esperaba conexión vacía"); }
    catch (InvalidOperationException ex) { Check(ex.Message.Contains("Cliente"), "público autenticado usa Cliente y falla antes de SQL"); }
    try { await db.ExecuteAsync("EliminarPago", new Dictionary<string, object?> { ["IdPago"] = 2001 }); throw new Exception("Cliente autorizado indebidamente"); }
    catch (GraphQLException) { Check(true, "gateway bloquea CRUD del Cliente antes de SQL"); }
    accessor.HttpContext.Request.Headers.Authorization = "Bearer " + tokens.Create(new(99, "prueba-local", "Empleado"));
    try { await db.ExecuteAsync("EliminarPago", new Dictionary<string, object?> { ["IdPago"] = 2001 }); throw new Exception("Se esperaba conexión vacía"); }
    catch (InvalidOperationException ex) { Check(ex.Message.Contains("Empleado"), "CRUD usa Empleado y falla antes de SQL"); }
}
// Regresión de integración: configuración vacía, sin abrir conexiones SQL.
Check(schema.Contains("type Inventario") && schema.Contains("activo: Boolean!"), "Inventario conserva Activo");
Check(typeof(Inventario).GetProperty("Activo")?.PropertyType == typeof(bool), "modelo Inventario.Activo de Ramsés");
foreach (var role in new[] { "", "Cliente", "Empleado", "Administrador", "Desconocido" })
{
    accessor.HttpContext.Request.Headers.Authorization = role == "" ? "" : "Bearer " + tokens.Create(new(99, "prueba-local", role));
    using var scope = provider.CreateScope();
    var db = scope.ServiceProvider.GetRequiredService<DbGateway>();
    var expected = role is "Empleado" or "Administrador" ? "Empleado" : role == "Cliente" ? "Cliente" : "Invitado";
    try { await db.QueryAsync<Servicio>("ConsultarServicios", publicRead: true); throw new Exception("Se esperaba conexión vacía"); }
    catch (InvalidOperationException ex) { Check(ex.Message.Contains(expected), "lectura pública con rol " + role); }
    try { await db.QueryAsync<LoginRow>("usp_ValidarLogin", login: true); throw new Exception("Se esperaba conexión vacía"); }
    catch (InvalidOperationException ex) { Check(ex.Message.Contains("Invitado"), "login siempre usa Invitado: " + role); }
    try { await db.QueryAsync<Cliente>("ConsultarClientes"); throw new Exception("Se esperaba bloqueo antes de SQL"); }
    catch (GraphQLException) when (role is not ("Empleado" or "Administrador")) { Check(true, "lectura interna bloqueada: " + role); }
    catch (InvalidOperationException ex) when (role is "Empleado" or "Administrador") { Check(ex.Message.Contains("Empleado"), "lectura interna de personal: " + role); }
    try { await db.ExecuteAsync("EliminarPago", new Dictionary<string, object?>()); throw new Exception("Se esperaba bloqueo antes de SQL"); }
    catch (GraphQLException) when (role is not ("Empleado" or "Administrador")) { Check(true, "escritura bloqueada: " + role); }
    catch (InvalidOperationException ex) when (role is "Empleado" or "Administrador") { Check(ex.Message.Contains("Empleado"), "escritura de personal: " + role); }
}
// Inspeccionar el comando sin abrir su conexión: parámetros opcionales y prefijo @.
var commandFactory = typeof(DbGateway).GetMethod("Command", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Static)!;
using (var connection = new Microsoft.Data.SqlClient.SqlConnection())
{
    using var command = (Microsoft.Data.SqlClient.SqlCommand)commandFactory.Invoke(null, new object?[] { connection, "ConsultarServicios", new Dictionary<string, object?> { ["@IdServicio"] = 2001, ["TipoConsulta"] = null } })!;
    Check(command.CommandType == System.Data.CommandType.StoredProcedure && command.CommandText == "dbo.ConsultarServicios", "comando parametrizado en dbo");
    Check(command.Parameters.Contains("@IdServicio") && command.Parameters["@TipoConsulta"].Value == DBNull.Value, "prefijo @ único y NULL SQL");
    using var empty = (Microsoft.Data.SqlClient.SqlCommand)commandFactory.Invoke(null, new object?[] { connection, "ConsultarServicios", null })!;
    Check(empty.Parameters.Count == 0, "parámetros opcionales de Ramsés");
    try { commandFactory.Invoke(null, new object?[] { connection, "ConsultarServicios;DROP", null }); throw new Exception("Nombre inseguro aceptado"); }
    catch (System.Reflection.TargetInvocationException ex) when (ex.InnerException is ArgumentException) { Check(true, "nombre de procedimiento inválido rechazado"); }
}
Console.WriteLine($"{passed} comprobaciones locales correctas. Sin conexión SQL, BCP ni servidor HTTP.");
