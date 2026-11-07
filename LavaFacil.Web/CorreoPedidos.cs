using System.Globalization;
using System.Net;
using System.Net.Mail;
using System.Text;
using System.Text.Json;
using System.Data;
using Microsoft.Data.SqlClient;

sealed class CorreoPedidos : BackgroundService
{
    const int Lote = 10;
    readonly Database db;
    readonly CorreoSmtp smtp;
    readonly ILogger<CorreoPedidos> log;

    public CorreoPedidos(Database db, CorreoSmtp smtp, ILogger<CorreoPedidos> log)
    {
        this.db = db;
        this.smtp = smtp;
        this.log = log;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(TimeSpan.FromSeconds(10));
        while (await timer.WaitForNextTickAsync(stoppingToken))
        {
            if (!db.Configured || (!smtp.Configurado && !smtp.OutboxActivo)) continue;
            try { await ProcesarLoteAsync(stoppingToken); }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { return; }
            catch (SqlException ex) { log.LogWarning("No se pudo procesar la cola de correo ({Number}).", ex.Number); }
            catch (Exception ex) { log.LogError(ex, "Error inesperado procesando la cola de correo."); }
        }
    }

    async Task ProcesarLoteAsync(CancellationToken ct)
    {
        var reclamados = await db.Call("app_ReclamarCorreo", new[]
        {
            new SqlParameter("@Lote", SqlDbType.Int) { Value = Lote }
        });
        foreach (var fila in reclamados.Rows)
        {
            ct.ThrowIfCancellationRequested();
            var id = EnteroLargo(fila, "IdEnvio");
            var tokenLease = TokenLease(fila);
            if (tokenLease is null)
            {
                log.LogWarning("No se pudo procesar el envío de correo {IdEnvio}: falta un TokenLease válido.", id);
                continue;
            }

            try
            {
                var mensaje = CrearMensaje(fila);
                var resultado = await smtp.EnviarMensajeAsync(mensaje.Destino, mensaje.Nombre, mensaje.Asunto, mensaje.Texto, mensaje.Html, ct);
                await ResolverAsync(id, tokenLease.Value, resultado.Enviado, resultado.Error, ct);
            }
            catch (OperationCanceledException) when (ct.IsCancellationRequested) { throw; }
            catch (Exception ex)
            {
                log.LogWarning(ex, "No se pudo preparar el envío de correo {IdEnvio}.", id);
                try { await ResolverAsync(id, tokenLease.Value, false, "No se pudo preparar el correo.", ct); }
                catch (SqlException resolverEx) { log.LogWarning("No se pudo resolver el envío de correo ({Number}).", resolverEx.Number); }
            }
        }
    }

    async Task ResolverAsync(long id, Guid tokenLease, bool exito, string? error, CancellationToken ct)
    {
        await db.Call("app_ResolverCorreo", new SqlParameter[]
        {
            new("@IdEnvio", SqlDbType.BigInt) { Value = id },
            new("@TokenLease", SqlDbType.UniqueIdentifier) { Value = tokenLease },
            new("@Exito", SqlDbType.Bit) { Value = exito },
            new("@Error", SqlDbType.VarChar, 1000) { Value = (object?)Sanitizar(error) ?? DBNull.Value }
        });
    }

    static MensajeCorreo CrearMensaje(Dictionary<string, object?> fila)
    {
        var tipo = Texto(fila, "Tipo") ?? "";
        var datos = Texto(fila, "DatosJson") ?? throw new InvalidOperationException("DatosJson ausente");
        using var documento = JsonDocument.Parse(datos);
        var root = documento.RootElement;
        var destino = Texto(fila, "Destino");
        if (!MailAddress.TryCreate(destino, out var address)) throw new InvalidOperationException("Destinatario invalido");

        var pedido = Entero(fila, "IdPedido");
        var pago = Entero(fila, "IdPago");
        var nombre = TextoJson(root, "Nombre");
        var apellidos = TextoJson(root, "Apellidos");
        var nombreCompleto = string.Join(" ", new[] { nombre, apellidos }.Where(s => !string.IsNullOrWhiteSpace(s))).Trim();
        var esPago = tipo.Equals("PagoConfirmado", StringComparison.OrdinalIgnoreCase) || tipo.Equals("ComprobantePago", StringComparison.OrdinalIgnoreCase);
        var esPedidoEstado = tipo.Equals("PedidoEstado", StringComparison.OrdinalIgnoreCase);
        var estadoNuevo = TextoJson(root, "EstadoNuevo");
        var asunto = esPago
            ? $"LavaFácil · Comprobante de pago #{pago}"
            : esPedidoEstado
                ? $"LavaFácil · Pedido #{pedido}: {estadoNuevo}"
                : $"LavaFácil · Confirmación de pedido #{pedido}";

        var lineas = new List<(string Etiqueta, string Valor)>();
        if (esPago)
        {
            Agregar(lineas, "Pedido", TextoJson(root, "IdPedido"));
            Agregar(lineas, "Monto", Dinero(root, "Monto"));
            Agregar(lineas, "Estado", TextoJson(root, "EstadoPago"));
            Agregar(lineas, "Método", TextoJson(root, "MetodoPago"));
            Agregar(lineas, "Referencia", TextoJson(root, "Referencia"));
        }
        else if (esPedidoEstado)
        {
            Agregar(lineas, "Pedido", TextoJson(root, "IdPedido"));
            Agregar(lineas, "Estado", string.Join(" → ", new[] { TextoJson(root, "EstadoAnterior"), estadoNuevo }.Where(s => !string.IsNullOrWhiteSpace(s))));
            Agregar(lineas, "Total", Dinero(root, "Total"));
            Agregar(lineas, "Detalle", DetalleTexto(root));
        }
        else
        {
            Agregar(lineas, "Pedido", TextoJson(root, "IdPedido"));
            Agregar(lineas, "Detalle", DetalleTexto(root));
            Agregar(lineas, "Monto", Dinero(root, "Total"));
            Agregar(lineas, "Estado", TextoJson(root, "Estado"));
        }

        var saludo = string.IsNullOrWhiteSpace(nombreCompleto) ? "Hola:" : $"Hola, {nombreCompleto}:";
        var introduccion = esPago
            ? "Hemos registrado tu pago en LavaFácil."
            : esPedidoEstado
                ? "El estado de tu pedido ha cambiado en LavaFácil."
                : "Recibimos tu pedido en LavaFácil.";
        var texto = new StringBuilder().AppendLine(saludo).AppendLine().AppendLine(introduccion).AppendLine();
        foreach (var linea in lineas) texto.AppendLine($"{linea.Etiqueta}: {linea.Valor}");
        texto.AppendLine().Append("Gracias,\nLavaFácil");
        var html = new StringBuilder("<div style=\"font-family:Segoe UI,Arial,sans-serif;color:#1f2937;max-width:600px\">")
            .Append("<h2 style=\"color:#0f766e\">LavaFácil</h2>")
            .Append("<p>").Append(WebUtility.HtmlEncode(saludo)).Append("</p>")
            .Append("<p>").Append(WebUtility.HtmlEncode(introduccion)).Append("</p><dl>");
        foreach (var linea in lineas) html.Append("<dt><strong>").Append(WebUtility.HtmlEncode(linea.Etiqueta)).Append("</strong></dt><dd>").Append(WebUtility.HtmlEncode(linea.Valor)).Append("</dd>");
        html.Append("</dl><p>Gracias,<br>LavaFácil</p></div>");
        return new(address.Address, nombreCompleto, asunto, texto.ToString(), html.ToString());
    }

    static string? DetalleTexto(JsonElement root)
    {
        if (!root.TryGetProperty("Detalle", out var detalle) || detalle.ValueKind != JsonValueKind.Array) return null;
        var partes = new List<string>();
        foreach (var item in detalle.EnumerateArray())
        {
            var nombre = TextoJson(item, "NombreServicio") ?? "Servicio";
            var cantidad = TextoJson(item, "Cantidad") ?? "";
            var subtotal = Dinero(item, "Subtotal");
            partes.Add(string.Join(" · ", new[] { nombre, cantidad, subtotal }.Where(s => !string.IsNullOrWhiteSpace(s))));
        }
        return partes.Count == 0 ? null : string.Join("; ", partes);
    }

    static void Agregar(List<(string Etiqueta, string Valor)> lista, string etiqueta, string? valor) { if (!string.IsNullOrWhiteSpace(valor)) lista.Add((etiqueta, valor)); }
    static string? TextoJson(JsonElement e, string propiedad) => e.TryGetProperty(propiedad, out var v) && v.ValueKind is not JsonValueKind.Null and not JsonValueKind.Undefined ? v.ToString() : null;
    static string? Dinero(JsonElement e, string propiedad) => e.TryGetProperty(propiedad, out var v) && v.TryGetDecimal(out var d) ? d.ToString("C2", CultureInfo.GetCultureInfo("es-CR")) : TextoJson(e, propiedad);
    static string? Texto(Dictionary<string, object?> f, string k) => f.TryGetValue(k, out var v) && v is not null ? Convert.ToString(v, CultureInfo.InvariantCulture) : null;
    static int Entero(Dictionary<string, object?> f, string k) => int.TryParse(Texto(f, k), NumberStyles.Integer, CultureInfo.InvariantCulture, out var v) ? v : 0;
    static long EnteroLargo(Dictionary<string, object?> f, string k) => long.TryParse(Texto(f, k), NumberStyles.Integer, CultureInfo.InvariantCulture, out var v) ? v : 0;
    static Guid? TokenLease(Dictionary<string, object?> f) => f.TryGetValue("TokenLease", out var v) && v is Guid token && token != Guid.Empty ? token : null;
    static string? Sanitizar(string? error) { if (string.IsNullOrWhiteSpace(error)) return null; var limpio = new string(error.Where(c => !char.IsControl(c) || c is '\t').ToArray()).Trim(); return limpio.Length > 1000 ? limpio[..1000] : limpio; }
    readonly record struct MensajeCorreo(string Destino, string? Nombre, string Asunto, string Texto, string Html);
}
