using System.Net;
using System.Net.Mail;
using System.Net.Mime;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

/// <summary>
/// Envio de codigos por SMTP. La configuracion vive cifrada con DPAPI en Data/correo.dpapi.
/// En Development o Test, LAVAFACIL_CORREO_SALIDA escribe el mensaje en esa carpeta en lugar de enviarlo.
/// </summary>
sealed class CorreoSmtp
{
    const int SegundosEspera = 12;

    static readonly JsonSerializerOptions OpcionesJson = new() { PropertyNameCaseInsensitive = true };

    readonly ConfiguracionCorreo? configuracion;
    readonly string? outbox;

    public CorreoSmtp(IWebHostEnvironment env)
    {
        var ruta = Path.Combine(env.ContentRootPath, "Data", "correo.dpapi");
        var salida = Environment.GetEnvironmentVariable("LAVAFACIL_CORREO_SALIDA");
        var entornoDePruebas = env.IsDevelopment() || env.IsEnvironment("Test");
        outbox = entornoDePruebas && !string.IsNullOrWhiteSpace(salida) ? salida.Trim() : null;

        if (!File.Exists(ruta)) return;

        try
        {
            var json = Encoding.UTF8.GetString(ProtectedData.Unprotect(File.ReadAllBytes(ruta), null, DataProtectionScope.CurrentUser));
            var leida = JsonSerializer.Deserialize<ConfiguracionCorreo>(json, OpcionesJson);
            if (leida is null) return;
            if (string.IsNullOrWhiteSpace(leida.Host) || string.IsNullOrWhiteSpace(leida.Remitente)) return;
            if (!MailAddress.TryCreate(leida.Remitente, out _)) return;

            leida.Host = leida.Host.Trim();
            leida.Remitente = leida.Remitente.Trim();
            leida.Usuario = leida.Usuario?.Trim() ?? "";
            leida.Clave ??= "";
            var nombreConfigurado = leida.Nombre ?? "";
            leida.Nombre = nombreConfigurado.Replace("\r", " ").Replace("\n", " ").Trim();
            if (leida.Port is < 1 or > 65535) leida.Port = 587;
            if (string.IsNullOrWhiteSpace(leida.Nombre)) leida.Nombre = "LavaFácil";
            configuracion = leida;
        }
        catch (CryptographicException) { /* Sin configuracion valida el modulo queda deshabilitado. */ }
        catch (JsonException) { /* Archivo ilegible o con formato viejo. */ }
        catch (IOException) { /* Archivo bloqueado o inaccesible. */ }
        catch (NotSupportedException) { /* Configuracion con tipos inesperados. */ }
    }

    /// <summary>true cuando Data/correo.dpapi existe y tiene host y remitente validos.</summary>
    public bool Configurado => configuracion is not null;

    /// <summary>true cuando LAVAFACIL_CORREO_SALIDA apunta a una carpeta en Development o Test.</summary>
    public bool OutboxActivo => outbox is not null;

    public async Task<ResultadoEnvio> EnviarMensajeAsync(string destino, string? nombre, string asunto, string texto, string html, CancellationToken ct)
    {
        if (!MailAddress.TryCreate(destino, out var para) || string.IsNullOrWhiteSpace(para.Address))
            return new(false, "destinatario invalido");
        if (string.IsNullOrWhiteSpace(asunto) || asunto.Contains('\r') || asunto.Contains('\n') || asunto.Length > 200)
            return new(false, "asunto invalido");
        if (texto is null || html is null) return new(false, "contenido invalido");

        var nombreSeguro = string.IsNullOrWhiteSpace(nombre)
            ? "LavaFácil"
            : nombre.Replace("\r", " ").Replace("\n", " ").Trim();
        if (nombreSeguro.Length > 150) nombreSeguro = nombreSeguro[..150];

        if (outbox is not null)
        {
            try
            {
                await EscribirOutboxAsync(outbox, para.Address, asunto, "mensaje", texto, html, ct);
                return new(true, null);
            }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException or ArgumentException or NotSupportedException)
            {
                return new(false, ex.Message);
            }
        }

        var cfg = configuracion;
        if (cfg is null) return new(false, "no configurado");
        return await EnviarPorSmtpAsync(cfg, para.Address, nombreSeguro, asunto, html, texto, ct);
    }

    public async Task<ResultadoEnvio> EnviarCodigoAsync(string destino, string? nombre, string codigo, string proposito, int minutos, CancellationToken ct)
    {
        if (!MailAddress.TryCreate(destino, out var para) || string.IsNullOrWhiteSpace(para.Address))
            return new(false, "destinatario invalido");
        if (codigo.Length != 6 || !codigo.All(char.IsAsciiDigit))
            return new(false, "codigo invalido");

        var verificacion = proposito == "verificacion";
        var asunto = verificacion
            ? "LavaFácil · Confirma tu correo"
            : "LavaFácil · Código para restablecer tu contraseña";
        var (html, texto) = ConstruirCuerpo(nombre, codigo, proposito, minutos);

        if (outbox is not null)
        {
            try
            {
                await EscribirOutboxAsync(outbox, para.Address, asunto, proposito, texto, html, ct);
                return new(true, null);
            }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException or ArgumentException or NotSupportedException)
            {
                return new(false, ex.Message);
            }
        }

        var cfg = configuracion;
        if (cfg is null) return new(false, "no configurado");

        return await EnviarPorSmtpAsync(cfg, para.Address, nombre, asunto, html, texto, ct);
    }

    static async Task<ResultadoEnvio> EnviarPorSmtpAsync(ConfiguracionCorreo cfg, string destino, string? nombre, string asunto, string html, string texto, CancellationToken ct)
    {
        var nombreSeguro = string.IsNullOrWhiteSpace(nombre) ? null : nombre.Replace("\r", " ").Replace("\n", " ").Trim();
        using var mensaje = new MailMessage
        {
            From = new MailAddress(cfg.Remitente, cfg.Nombre, Encoding.UTF8),
            Subject = asunto,
            SubjectEncoding = Encoding.UTF8,
            Body = html,
            BodyEncoding = Encoding.UTF8,
            IsBodyHtml = true
        };
        mensaje.To.Add(string.IsNullOrWhiteSpace(nombreSeguro)
            ? new MailAddress(destino)
            : new MailAddress(destino, nombreSeguro, Encoding.UTF8));
        using var alterno = AlternateView.CreateAlternateViewFromString(texto, Encoding.UTF8, MediaTypeNames.Text.Plain);
        mensaje.AlternateViews.Add(alterno);

        using var cliente = new SmtpClient(cfg.Host, cfg.Port)
        {
            EnableSsl = cfg.Ssl,
            UseDefaultCredentials = false,
            DeliveryMethod = SmtpDeliveryMethod.Network,
            Timeout = SegundosEspera * 1000
        };
        if (cfg.Usuario.Length > 0) cliente.Credentials = new NetworkCredential(cfg.Usuario, cfg.Clave);

        using var limite = CancellationTokenSource.CreateLinkedTokenSource(ct);
        limite.CancelAfter(TimeSpan.FromSeconds(SegundosEspera));

        try
        {
            await cliente.SendMailAsync(mensaje, limite.Token);
            return new(true, null);
        }
        catch (OperationCanceledException)
        {
            return new(false, "El servidor de correo no respondio a tiempo.");
        }
        catch (SmtpException ex)
        {
            return new(false, ex.Message);
        }
        catch (Exception ex)
        {
            return new(false, ex.Message);
        }
    }

    static (string Html, string Texto) ConstruirCuerpo(string? nombre, string codigo, string proposito, int minutos)
    {
        var accion = proposito == "verificacion" ? "confirmar tu correo electrónico" : "restablecer tu contraseña";
        var vence = minutos == 1 ? "1 minuto" : $"{minutos} minutos";
        var nombreLimpio = string.IsNullOrWhiteSpace(nombre) ? "" : nombre.Trim();

        var saludoTexto = nombreLimpio.Length == 0 ? "Hola:" : $"Hola, {nombreLimpio}:";
        var saludoHtml = nombreLimpio.Length == 0 ? "Hola:" : $"Hola, {WebUtility.HtmlEncode(nombreLimpio)}:";

        var texto = string.Join(Environment.NewLine, new[]
        {
            saludoTexto,
            "",
            $"Usa este código para {accion} en LavaFácil:",
            $"Codigo: {codigo}",
            "",
            $"El código vence en {vence}. Si no solicitaste este mensaje, ignóralo.",
            "",
            "LavaFácil"
        });

        var html = $"""
            <div style="margin:0;padding:24px;background:#f4f6f8;font-family:Segoe UI,Arial,sans-serif;color:#1f2937;">
              <div style="max-width:480px;margin:0 auto;background:#ffffff;border:1px solid #e5e7eb;border-radius:12px;padding:28px;">
                <div style="font-size:18px;font-weight:700;color:#0f766e;margin-bottom:16px;">LavaFácil</div>
                <p style="margin:0 0 12px;font-size:15px;line-height:1.5;">{saludoHtml}</p>
                <p style="margin:0 0 18px;font-size:15px;line-height:1.5;">Usa este código para {accion}:</p>
                <div style="font-family:Consolas,Menlo,monospace;font-size:34px;font-weight:700;letter-spacing:10px;text-align:center;padding:16px;background:#f0fdfa;border:1px dashed #0f766e;border-radius:10px;color:#0f172a;">{codigo}</div>
                <p style="margin:18px 0 0;font-size:14px;line-height:1.5;color:#475569;">El código vence en {vence}. Si no solicitaste este mensaje, ignóralo.</p>
              </div>
            </div>
            """;

        return (html, texto);
    }

    static async Task EscribirOutboxAsync(string carpeta, string destino, string asunto, string proposito, string texto, string html, CancellationToken ct)
    {
        Directory.CreateDirectory(carpeta);
        var archivo = DateTime.Now.ToString("yyyyMMdd-HHmmss") + "-" + Guid.NewGuid().ToString("N") + ".eml";
        var ruta = Path.Combine(carpeta, archivo);
        var contenido = string.Join(Environment.NewLine, new[]
        {
            "From: LavaFacil <no-reply@lavafacil.local>",
            $"To: {destino}",
            $"Subject: {asunto}",
            $"Date: {DateTimeOffset.Now:R}",
            $"Message-ID: <{Guid.NewGuid():N}@lavafacil.local>",
            "MIME-Version: 1.0",
            $"X-LavaFacil-Proposito: {proposito}",
            "Content-Type: multipart/alternative; boundary=\"lavafacil-boundary\"",
            "",
            "--lavafacil-boundary",
            "Content-Type: text/plain; charset=utf-8",
            "Content-Transfer-Encoding: 8bit",
            "",
            texto,
            "--lavafacil-boundary",
            "Content-Type: text/html; charset=utf-8",
            "Content-Transfer-Encoding: 8bit",
            "",
            html,
            "--lavafacil-boundary--"
        });
        await File.WriteAllTextAsync(ruta, contenido, new UTF8Encoding(false), ct);
    }

    sealed class ConfiguracionCorreo
    {
        public string Host { get; set; } = "";
        public int Port { get; set; } = 587;
        public string Usuario { get; set; } = "";
        public string Clave { get; set; } = "";
        public string Remitente { get; set; } = "";
        public string Nombre { get; set; } = "LavaFácil";
        public bool Ssl { get; set; } = true;
    }
}

record ResultadoEnvio(bool Enviado, string? Error);
