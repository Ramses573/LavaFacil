using System.Data;
using System.Globalization;
using System.Security.Claims;
using Microsoft.Data.SqlClient;

/// <summary>
/// Rutas HTTP del modulo de correo: estado, verificacion y recuperacion de contrasena.
/// El codigo de 6 digitos nunca se devuelve ni se registra.
/// </summary>
static class CorreoRoutes
{
    const string PropositoVerificacion = "verificacion";
    const string PropositoRecuperacion = "recuperacion";
    const string CorreoNoConfigurado = "El correo saliente no está configurado en esta instalación.";
    const string MensajeEnvioFallido = "No pudimos enviar el código. Reintenta en un momento.";
    const string MensajeRecuperacion = "Si el correo o usuario está registrado, enviamos un código de 6 dígitos. Revisa también la carpeta de spam.";
    const string MensajeRestablecido = "Contraseña actualizada. Inicia sesión con tu nueva contraseña.";

    public static void Map(WebApplication app, RouteGroupBuilder authenticated)
    {
        CorreoTokens.Initialize(app.Environment.ContentRootPath);

        authenticated.MapGet("/email/estado", async (HttpContext ctx, Database db, CorreoSmtp smtp) =>
        {
            var resultado = await db.Call("app_CorreoEstado", new[] { Database.Id(ctx) });
            var fila = resultado.Rows.FirstOrDefault() ?? new Dictionary<string, object?>();
            return Results.Json(new
            {
                email = Texto(fila, "Email"),
                verificado = Booleano(fila, "Verificado"),
                verificadoEn = Valor(fila, "VerificadoEn"),
                tieneCodigoPendiente = Booleano(fila, "TienePendiente"),
                expiraEn = Valor(fila, "ExpiraEn"),
                segundosEspera = Entero(fila, "SegundosEspera"),
                intentosRestantes = Entero(fila, "IntentosRestantes"),
                correoConfigurado = smtp.Configurado || smtp.OutboxActivo
            });
        });

        authenticated.MapPost("/email/verificacion/enviar", async (HttpContext ctx, Database db, CorreoSmtp smtp) =>
        {
            if (!smtp.Configurado && !smtp.OutboxActivo)
                return Results.Json(new { error = CorreoNoConfigurado }, statusCode: StatusCodes.Status503ServiceUnavailable);

            var id = UsuarioId(ctx);
            var claveUsuario = $"ver:u:{id}";
            var claveIp = $"ver:ip:{Ip(ctx)}";

            if (!LimitesCorreo.Permite(claveUsuario, 1, TimeSpan.FromSeconds(60))
                || !LimitesCorreo.Permite(claveUsuario, 3, TimeSpan.FromHours(1))
                || !LimitesCorreo.Permite(claveIp, 10, TimeSpan.FromHours(1)))
                return Demasiado(ctx, claveUsuario, claveIp);

            string codigo;
            QueryResult creado;
            try
            {
                codigo = CorreoTokens.GenerarCodigo();
                creado = await db.Call("app_CrearTokenCorreo", new SqlParameter[]
                {
                    Database.Id(ctx),
                    Database.Param("Proposito", PropositoVerificacion, 20),
                    Hash("CodigoHash", CorreoTokens.Hash(PropositoVerificacion, codigo)),
                    new SqlParameter("MinutosValidez", SqlDbType.Int) { Value = 30 }
                });
            }
            catch
            {
                LimitesCorreo.Liberar(claveUsuario);
                throw;
            }

            var fila = creado.Rows.FirstOrDefault();
            var destino = fila is null ? null : Texto(fila, "EmailDestino");
            if (fila is null || string.IsNullOrWhiteSpace(destino))
            {
                LimitesCorreo.Liberar(claveUsuario);
                return Results.Json(new { enviado = false, message = MensajeEnvioFallido, segundosEspera = 0 });
            }

            var envio = await smtp.EnviarCodigoAsync(destino, ctx.User.Identity?.Name, codigo, PropositoVerificacion, 30, ctx.RequestAborted);
            if (!envio.Enviado)
            {
                LimitesCorreo.Liberar(claveUsuario);
                return Results.Json(new { enviado = false, message = MensajeEnvioFallido, segundosEspera = 0 });
            }

            return Results.Json(new
            {
                enviado = true,
                destinatario = destino,
                expiraEn = Valor(fila, "ExpiraEn"),
                segundosEspera = 60,
                message = "Te enviamos un código de 6 dígitos. Revisa tu correo y también la carpeta de spam."
            });
        });

        authenticated.MapPost("/email/verificacion/confirmar", async (CodigoCorreoInput input, HttpContext ctx, Database db) =>
        {
            ValidarCodigo(input.Codigo);

            var claveUsuario = $"con:u:{UsuarioId(ctx)}";
            var claveIp = $"con:ip:{Ip(ctx)}";
            if (!LimitesCorreo.Permite(claveUsuario, 10, TimeSpan.FromMinutes(10))
                || !LimitesCorreo.Permite(claveIp, 20, TimeSpan.FromMinutes(10)))
                return Demasiado(ctx, claveUsuario, claveIp);

            var resultado = await db.Call("app_ConfirmarCorreo", new SqlParameter[]
            {
                Database.Id(ctx),
                Hash("CodigoHash", CorreoTokens.Hash(PropositoVerificacion, input.Codigo))
            });

            var fila = resultado.Rows.FirstOrDefault()
                ?? throw new InvalidOperationException("El código no es válido o ya venció. Solicita uno nuevo.");

            return Results.Json(new
            {
                verificado = Booleano(fila, "Verificado"),
                email = Texto(fila, "EmailVerificado")
            });
        });

        app.MapPost("/api/email/recuperacion/solicitar", async (IdentificadorCorreoInput input, HttpContext ctx, Database db, CorreoSmtp smtp) =>
        {
            if (!smtp.Configurado && !smtp.OutboxActivo)
                return Results.Json(new { error = CorreoNoConfigurado }, statusCode: StatusCodes.Status503ServiceUnavailable);

            Database.Required(input.Identificador, "Correo o usuario", 150);
            var identificador = input.Identificador!.Trim();
            var claveIdentificador = $"rec:i:{identificador.ToLowerInvariant()}";
            var claveIp = $"rec:ip:{Ip(ctx)}";

            if (!LimitesCorreo.Permite(claveIdentificador, 1, TimeSpan.FromSeconds(60))
                || !LimitesCorreo.Permite(claveIdentificador, 3, TimeSpan.FromHours(1))
                || !LimitesCorreo.Permite(claveIp, 10, TimeSpan.FromHours(1)))
                return Results.Ok(new { message = MensajeRecuperacion });

            var codigo = CorreoTokens.GenerarCodigo();
            QueryResult resultado;
            try
            {
                resultado = await db.Call("app_SolicitarRecuperacion", new SqlParameter[]
                {
                    Database.Param("Identificador", identificador, 150),
                    Hash("CodigoHash", CorreoTokens.Hash(PropositoRecuperacion, codigo)),
                    new SqlParameter("MinutosValidez", SqlDbType.Int) { Value = 10 }
                });
            }
            catch (SqlException ex) when (ex.Number >= 50000)
            {
                // Limites o cuentas sin correo: misma respuesta para no enumerar usuarios.
                return Results.Ok(new { message = MensajeRecuperacion });
            }

            var fila = resultado.Rows.FirstOrDefault();
            var destino = fila is null ? null : Texto(fila, "EmailDestino");
            if (fila is null || string.IsNullOrWhiteSpace(destino))
                return Results.Ok(new { message = MensajeRecuperacion });

            var envio = await smtp.EnviarCodigoAsync(destino, Texto(fila, "Nombre"), codigo, PropositoRecuperacion, 10, ctx.RequestAborted);
            if (!envio.Enviado) LimitesCorreo.Liberar(claveIdentificador);

            return Results.Ok(new { message = MensajeRecuperacion });
        });

        app.MapPost("/api/email/recuperacion/restablecer", async (RestablecerCorreoInput input, HttpContext ctx, Database db) =>
        {
            Database.Required(input.Identificador, "Correo o usuario", 150);
            ValidarCodigo(input.Codigo);
            AppPasswords.CheckNew(input.NuevaClave);

            var claveIp = $"res:ip:{Ip(ctx)}";
            if (!LimitesCorreo.Permite(claveIp, 20, TimeSpan.FromMinutes(10)))
                return Demasiado(ctx, claveIp);

            // El hash de la clave se calcula solo despues de validar formato y politica.
            var nuevoHash = AppPasswords.Hash(input.NuevaClave);

            await db.Call("app_RestablecerClave", new SqlParameter[]
            {
                Database.Param("Identificador", input.Identificador!.Trim(), 150),
                Hash("CodigoHash", CorreoTokens.Hash(PropositoRecuperacion, input.Codigo)),
                Database.Param("NuevoHash", nuevoHash, 255)
            });

            return Results.Ok(new { message = MensajeRestablecido });
        });
    }

    static int UsuarioId(HttpContext ctx) =>
        int.Parse(ctx.User.FindFirstValue(ClaimTypes.NameIdentifier)!, CultureInfo.InvariantCulture);

    static string Ip(HttpContext ctx) => ctx.Connection.RemoteIpAddress?.ToString() ?? "local";

    static void ValidarCodigo(string? codigo)
    {
        if (codigo is null || codigo.Length != 6 || !codigo.All(char.IsAsciiDigit))
            throw new ArgumentException("El código debe tener exactamente 6 dígitos.");
    }

    static SqlParameter Hash(string nombre, byte[] valor) =>
        new(nombre, SqlDbType.VarBinary, 32) { Value = valor };

    static IResult Demasiado(HttpContext ctx, params string[] claves)
    {
        var segundos = 0;
        foreach (var clave in claves)
        {
            var restantes = LimitesCorreo.SegundosRestantes(clave);
            if (restantes > segundos) segundos = restantes;
        }
        if (segundos < 1) segundos = 1;

        ctx.Response.Headers["Retry-After"] = segundos.ToString(CultureInfo.InvariantCulture);
        return Results.Json(new
        {
            error = "Demasiadas solicitudes. Espera unos segundos antes de reintentar.",
            retryAfterSegundos = segundos
        }, statusCode: StatusCodes.Status429TooManyRequests);
    }

    static object? Valor(Dictionary<string, object?> fila, string nombre) =>
        fila.TryGetValue(nombre, out var valor) ? valor : null;

    static string? Texto(Dictionary<string, object?> fila, string nombre) =>
        fila.TryGetValue(nombre, out var valor) && valor is not null ? Convert.ToString(valor, CultureInfo.InvariantCulture) : null;

    static bool Booleano(Dictionary<string, object?> fila, string nombre) =>
        fila.TryGetValue(nombre, out var valor) && valor is not null && Convert.ToBoolean(valor, CultureInfo.InvariantCulture);

    static int Entero(Dictionary<string, object?> fila, string nombre) =>
        fila.TryGetValue(nombre, out var valor) && valor is not null ? Convert.ToInt32(valor, CultureInfo.InvariantCulture) : 0;
}

record CodigoCorreoInput(string Codigo);
record IdentificadorCorreoInput(string Identificador);
record RestablecerCorreoInput(string Identificador, string Codigo, string NuevaClave);
