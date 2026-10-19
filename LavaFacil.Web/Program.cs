using System.Data;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Antiforgery;
using Microsoft.Data.SqlClient;
using System.Runtime.Versioning;

[assembly: SupportedOSPlatform("windows")]

var builder = WebApplication.CreateBuilder(args);
builder.WebHost.UseUrls(builder.Configuration["Urls"] ?? "http://127.0.0.1:5088");
builder.Services.AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme).AddCookie(o => {
    o.Cookie.Name = "LavaFacil.Session";
    o.Cookie.HttpOnly = true;
    o.Cookie.SameSite = SameSiteMode.Strict;
    o.ExpireTimeSpan = TimeSpan.FromHours(2);
    o.Events.OnRedirectToLogin = c => { c.Response.StatusCode = 401; return Task.CompletedTask; };
    o.Events.OnRedirectToAccessDenied = c => { c.Response.StatusCode = 403; return Task.CompletedTask; };
});
builder.Services.AddAuthorization();
builder.Services.AddAntiforgery(o => { o.HeaderName = "X-CSRF-TOKEN"; o.Cookie.SameSite = SameSiteMode.Strict; });
builder.Services.AddSingleton<Database>();
builder.Services.AddSingleton<MirrorMonitor>();
var app = builder.Build();
// El token CSRF debe validarse contra la identidad recuperada de la cookie.
app.UseAuthentication();
app.Use(async (ctx, next) => {
    if (ctx.Request.Host.Host != "127.0.0.1" && ctx.Request.Host.Host != "localhost") { ctx.Response.StatusCode = 403; return; }
    ctx.Response.Headers["X-Content-Type-Options"] = "nosniff";
    ctx.Response.Headers["Referrer-Policy"] = "same-origin";
    ctx.Response.Headers["Content-Security-Policy"] = "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'self'; frame-ancestors 'none'";
    ctx.Response.Headers.CacheControl = "no-store";
    try {
        if (HttpMethods.IsPost(ctx.Request.Method)) await ctx.RequestServices.GetRequiredService<IAntiforgery>().ValidateRequestAsync(ctx);
        await next();
    } catch (AntiforgeryValidationException) { ctx.Response.StatusCode = 400; await ctx.Response.WriteAsJsonAsync(new { error = "La sesión del formulario venció. Recarga la página." }); }
    catch (SqlException ex) { ctx.Response.StatusCode = ex.Number == 50100 ? 403 : ex.Number == 50104 ? 404 : ex.Number >= 50000 ? 400 : 503; await ctx.Response.WriteAsJsonAsync(new { error = DbErrors.Message(ex) }); }
    catch (ArgumentException ex) { ctx.Response.StatusCode = 400; await ctx.Response.WriteAsJsonAsync(new { error = ex.Message }); }
    catch (InvalidOperationException ex) { ctx.Response.StatusCode = 400; await ctx.Response.WriteAsJsonAsync(new { error = ex.Message }); }
    catch (Exception) { ctx.Response.StatusCode = 500; await ctx.Response.WriteAsJsonAsync(new { error = "No se pudo completar la operación. Revisa la conexión y vuelve a intentarlo." }); }
});
app.UseDefaultFiles();
app.UseStaticFiles();
app.UseAuthorization();

app.MapGet("/api/bootstrap", async (HttpContext ctx, IAntiforgery csrf, Database db) => {
    var needsAccount = false;
    var featuresReady = false;
    if (db.Configured && ctx.User.Identity?.IsAuthenticated != true) {
        try { var initial = await db.Call("app_EstadoInicial", Array.Empty<SqlParameter>()); needsAccount = Convert.ToBoolean(initial.Rows[0]["RequiereAdministrador"]); }
        catch (SqlException) { /* Login sigue disponible para mostrar el error de conexión al intentar entrar. */ }
    }
    if (db.Configured) {
        try { featuresReady = await db.HasFeatures(); }
        catch (SqlException) { /* La pantalla de conexión informará la indisponibilidad. */ }
    }
    return Results.Json(new {
        token = csrf.GetAndStoreTokens(ctx).RequestToken,
        configured = db.Configured, needsAccount, featuresReady,
        user = ctx.User.Identity?.IsAuthenticated == true ? new { id = ctx.User.FindFirstValue(ClaimTypes.NameIdentifier), name = ctx.User.Identity.Name, role = ctx.User.FindFirstValue(ClaimTypes.Role) } : null
    });
});

app.MapPost("/api/setup", async (ConnectionInput input, Database db) => {
    if (db.Configured) return Results.BadRequest(new { error = "La conexión ya está configurada. Para cambiarla, detén la app y sigue el archivo LEEME." });
    await db.Configure(input);
    return Results.Ok(new { message = "Conexión verificada y guardada cifrada para tu usuario de Windows." });
});
app.MapPost("/api/login", async (LoginInput input, Database db, HttpContext ctx) => {
    Database.Required(input.Username, "Usuario", 50);
    Database.Required(input.Password, "Contraseña", 255);
    var result = await AppPasswords.Authenticate(db, input.Username, input.Password);
    var row = result.Rows.FirstOrDefault();
    if (row is null || !Convert.ToBoolean(row["LoginValido"])) return Results.Json(new { error = "Usuario o contraseña incorrectos, o cuenta inactiva." }, statusCode: 401);
    var claims = new[] { new Claim(ClaimTypes.NameIdentifier, Convert.ToString(row["IdUsuario"])!), new Claim(ClaimTypes.Name, Convert.ToString(row["NombreUsuario"])!), new Claim(ClaimTypes.Role, Convert.ToString(row["TipoUsuario"])!) };
    await ctx.SignInAsync(CookieAuthenticationDefaults.AuthenticationScheme, new ClaimsPrincipal(new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme)));
    return Results.Ok(new { user = new { id = row["IdUsuario"], name = row["NombreUsuario"], role = row["TipoUsuario"] }, result.Server, result.DatabaseName });
});
app.MapPost("/api/logout", async (HttpContext ctx) => { await ctx.SignOutAsync(); return Results.Ok(); }).RequireAuthorization();
app.MapPost("/api/first-account", async (FirstAccountInput input, Database db) => {
    ValidateContact(input.Name, input.LastName, input.Phone, input.Email);
    Database.Required(input.Identity, "Cédula", 20); Database.Required(input.Username, "Usuario", 50);
    Database.Required(input.Password, "Contraseña", 255);
    if (input.Password.Length < 8) throw new ArgumentException("Usa una contraseña de al menos 8 caracteres.");
    return Results.Ok(await db.Call("app_CrearAdministradorInicial", new[] {
        Database.Param("Cedula",input.Identity.Trim(),20),Database.Param("Nombre",input.Name.Trim(),50),Database.Param("Apellidos",input.LastName.Trim(),100),
        Database.Param("Telefono",input.Phone.Trim(),20),Database.Param("Email",input.Email.Trim(),150),Database.Param("NombreUsuario",input.Username.Trim(),50),Database.Param("Clave",input.Password,255)
    }));
});
var authenticated = app.MapGroup("/api").RequireAuthorization();
authenticated.MapGet("/home", async (HttpContext ctx, Database db) => await db.Call("app_Resumen", new[] { Database.Id(ctx) }));
authenticated.MapGet("/services", async (HttpContext ctx, Database db) => await db.Call("app_ConsultarServicios", new[] { Database.Id(ctx) }));
authenticated.MapGet("/clients", async (HttpContext ctx, Database db) => await db.Call("app_ConsultarClientes", new[] { Database.Id(ctx) }));
authenticated.MapGet("/profile", async (HttpContext ctx, Database db) => await db.Call("app_ConsultarPerfil", new[] { Database.Id(ctx) }));
authenticated.MapPost("/profile", async (ProfileInput input, HttpContext ctx, Database db) => {
    ValidateContact(input.Name, input.LastName, input.Phone, input.Email);
    return Results.Ok(await db.Call("app_ActualizarPerfil", new[] { Database.Id(ctx), Database.Param("Nombre", input.Name.Trim(), 50), Database.Param("Apellidos", input.LastName.Trim(), 100), Database.Param("Telefono", input.Phone.Trim(), 20), Database.Param("Email", input.Email.Trim(), 150) }));
});
authenticated.MapPost("/clients", async (ClientInput input, HttpContext ctx, Database db) => {
    Database.Required(input.Identity, "Cédula", 20);
    ValidateContact(input.Name, input.LastName, input.Phone, input.Email);
    if (input.Address?.Length > 250) throw new ArgumentException("La dirección admite hasta 250 caracteres.");
    return Results.Ok(await db.Call("app_RegistrarCliente", new[] { Database.Id(ctx), Database.Param("Cedula", input.Identity.Trim(), 20), Database.Param("Nombre", input.Name.Trim(), 50), Database.Param("Apellidos", input.LastName.Trim(), 100), Database.Param("Telefono", input.Phone.Trim(), 20), Database.Param("Email", input.Email.Trim(), 150), Database.Param("Direccion", input.Address?.Trim(), 250) }));
});
FeatureRoutes.Map(authenticated);
authenticated.MapGet("/health", async (HttpContext ctx, MirrorMonitor monitor) => {
    var result = await monitor.Check();
    // Clientes y empleados reciben solo disponibilidad; la topología es exclusiva del administrador.
    if (ctx.User.IsInRole("Administrador")) return Results.Json((object)result);
    return Results.Json((object)new { result.CheckedAt, result.ApplicationAvailable,
        message = result.ApplicationAvailable ? "Conexión disponible." : "No podemos confirmar la conexión. Conserva el formulario y vuelve a comprobar antes de guardar." });
});
app.Run();

static void ValidateContact(string name, string lastName, string phone, string email) {
    Database.Required(name, "Nombre", 50); Database.Required(lastName, "Apellidos", 100); Database.Required(phone, "Teléfono", 20); Database.Required(email, "Correo", 150);
    if (!System.Net.Mail.MailAddress.TryCreate(email, out var parsed) || parsed.Address != email) throw new ArgumentException("Ingresa un correo electrónico válido.");
}
record ConnectionInput(string Server, string Database, string Username, string Password, string? FailoverPartner);
record LoginInput(string Username, string Password);
record ProfileInput(string Name, string LastName, string Phone, string Email);
record ClientInput(string Identity, string Name, string LastName, string Phone, string Email, string? Address);
record FirstAccountInput(string Identity, string Name, string LastName, string Phone, string Email, string Username, string Password);
record QueryResult(List<Dictionary<string, object?>> Rows, string Server, string DatabaseName, DateTimeOffset CheckedAt);

sealed class Database {
    private readonly string configPath;
    private string? connectionString;
    private readonly SemaphoreSlim setupLock = new(1, 1);
    public bool Configured => !string.IsNullOrEmpty(connectionString);
    internal string? MonitoringConnection => connectionString;
    public async Task<bool> HasFeatures() {
        using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync();
        using var command = new SqlCommand("SELECT COUNT(*) FROM sys.procedures WHERE schema_id=SCHEMA_ID('dbo') AND name IN ('app_ExigirAdministrador','app_BuscarServicios','app_GuardarServicio','app_CrearPedido','app_BuscarPedidos','app_DetallePedido','app_CambiarEstadoPedido','app_Preferencias','app_GuardarPreferencias','app_Credencial','app_GuardarClave','app_CrearCuentaCliente')",connection);
        return Convert.ToInt32(await command.ExecuteScalarAsync()) == 12;
    }
    public Database(IWebHostEnvironment env) {
        configPath = Path.Combine(env.ContentRootPath, "Data", "connection.dpapi");
        if (File.Exists(configPath)) connectionString = Encoding.UTF8.GetString(ProtectedData.Unprotect(File.ReadAllBytes(configPath), null, DataProtectionScope.CurrentUser));
    }
    public async Task Configure(ConnectionInput input) {
        await setupLock.WaitAsync();
        try {
            if (Configured) throw new InvalidOperationException("La conexión ya está configurada.");
            Required(input.Server, "Servidor", 200); Required(input.Database, "Base de datos", 128); Required(input.Username, "Usuario SQL", 128); Required(input.Password, "Contraseña SQL", 255);
            var cs = new SqlConnectionStringBuilder { DataSource = input.Server.Trim(), InitialCatalog = input.Database.Trim(), UserID = input.Username.Trim(), Password = input.Password, TrustServerCertificate = true, Encrypt = true, ConnectTimeout = 8, ApplicationName = "LavaFacil", PersistSecurityInfo = false };
            if (!string.IsNullOrWhiteSpace(input.FailoverPartner)) cs.FailoverPartner = input.FailoverPartner.Trim();
            using var connection = new SqlConnection(cs.ConnectionString);
            await connection.OpenAsync();
            using var command = new SqlCommand("SELECT COUNT(*) FROM sys.procedures WHERE name IN ('usp_ValidarLogin','app_Autorizar','app_Resumen','app_ConsultarServicios','app_ConsultarClientes','app_ConsultarPerfil','app_ActualizarPerfil','app_RegistrarCliente','app_EstadoInicial','app_CrearAdministradorInicial') AND schema_id=SCHEMA_ID('dbo')", connection);
            if (Convert.ToInt32(await command.ExecuteScalarAsync()) != 10) throw new InvalidOperationException("La conexión funciona, pero faltan los procedimientos de la app. Ejecuta primero SQL/01_Procedimientos_App.sql en LavaFacil desde SSMS.");
            Directory.CreateDirectory(Path.GetDirectoryName(configPath)!);
            await File.WriteAllBytesAsync(configPath, ProtectedData.Protect(Encoding.UTF8.GetBytes(cs.ConnectionString), null, DataProtectionScope.CurrentUser));
            connectionString = cs.ConnectionString;
        } finally { setupLock.Release(); }
    }
    public async Task<QueryResult> Call(string procedure, IEnumerable<SqlParameter> parameters) {
        if (!Configured) throw new InvalidOperationException("Primero configura la conexión.");
        using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync();
        using var command = new SqlCommand("dbo." + procedure, connection) { CommandType = CommandType.StoredProcedure, CommandTimeout = 15 };
        command.Parameters.AddRange(parameters.ToArray());
        var rows = new List<Dictionary<string, object?>>();
        using (var reader = await command.ExecuteReaderAsync()) {
            while (await reader.ReadAsync()) {
                var row = new Dictionary<string, object?>();
                for (var i = 0; i < reader.FieldCount; i++) row[reader.GetName(i)] = await reader.IsDBNullAsync(i) ? null : reader.GetValue(i);
                rows.Add(row);
            }
        }
        using var status = new SqlCommand("SELECT CONVERT(nvarchar(128), @@SERVERNAME), DB_NAME()", connection);
        using var info = await status.ExecuteReaderAsync();
        await info.ReadAsync();
        return new(rows, info.GetString(0), info.GetString(1), DateTimeOffset.Now);
    }
    public static SqlParameter Param(string name, string? value, int length) => new("@" + name, SqlDbType.VarChar, length) { Value = (object?)value ?? DBNull.Value };
    public static SqlParameter Id(HttpContext ctx) => new("@IdUsuario", SqlDbType.Int) { Value = int.Parse(ctx.User.FindFirstValue(ClaimTypes.NameIdentifier)!) };
    public static void Required(string? value, string label, int maximum) { if (string.IsNullOrWhiteSpace(value) || value.Length > maximum) throw new ArgumentException($"{label} es obligatorio y admite hasta {maximum} caracteres."); }
}
static class DbErrors {
    public static string Message(SqlException ex) => ex.Number switch {
        18456 => "SQL Server rechazó el usuario SQL o su contraseña. No es la cuenta del login de LavaFácil.",
        4060 => "El usuario SQL no tiene acceso a la base de datos indicada.",
        2812 or 207 or 208 => "Falta actualizar la base. Ejecuta SQL/01_Procedimientos_App.sql y SQL/04_Mejoras_Aplicativo.sql en LavaFacil del servidor principal.",
        2601 or 2627 => "Ya existe un registro con esa cédula o correo electrónico.",
        547 => "Los datos no cumplen las reglas de la base de datos.",
        >= 50000 => ex.Message,
        _ => "No se pudo consultar SQL Server. Revisa Tailscale, el servidor y el puerto 1433. No se confirmó esta operación; verifica los registros antes de repetirla."
    };
}
