using System.Globalization;
using System.Text;
using System.Text.Json;
using PdfSharp;
using PdfSharp.Drawing;
using PdfSharp.Fonts;
using PdfSharp.Pdf;

/// <summary>
/// Genera el comprobante PDF adjunto de pedidos y pagos a partir del snapshot JSON
/// de la cola de correo. No escribe a disco y nunca propaga excepciones.
/// </summary>
static class ComprobantePdf
{
    const double Margen = 40;
    const double ResguardoInferior = 72;
    const int MaximoItems = 50;

    static readonly CultureInfo CulturaCr = CultureInfo.GetCultureInfo("es-CR");
    static readonly CultureInfo CulturaInv = CultureInfo.InvariantCulture;

    static readonly XColor ColorMarca = XColor.FromArgb(0x0F, 0x76, 0x6E);
    static readonly XColor ColorTexto = XColor.FromArgb(0x1F, 0x29, 0x37);
    static readonly XColor ColorSuave = XColor.FromArgb(0x47, 0x55, 0x69);
    static readonly XColor ColorLinea = XColor.FromArgb(0xE5, 0xE7, 0xEB);

    /// <summary>
    /// Inicialización única y thread-safe del ajuste global de fuentes. PDFsharp
    /// solo permite aplicar <c>UseWindowsFontsUnderWindows</c> una vez, por lo que
    /// un <see cref="InvalidOperationException"/> se trata como éxito (ya estaba
    /// aplicado) en lugar de dejar el estado en fallo.
    /// </summary>
    static readonly Lazy<bool> fuentesListas = new(InicializarFuentes, LazyThreadSafetyMode.ExecutionAndPublication);

    static bool InicializarFuentes()
    {
        try
        {
            if (!OperatingSystem.IsWindows()) return true;
            GlobalFontSettings.UseWindowsFontsUnderWindows = true;
            return true;
        }
        catch (InvalidOperationException)
        {
            // PDFsharp ya aplicó el ajuste (por ejemplo desde Program.cs). No es un
            // fallo: la tipografía está configurada y no debe envenenar el estado.
            return true;
        }
        catch
        {
            return false;
        }
    }

    /// <summary>
    /// true cuando la tipografía está disponible. <see cref="Lazy{T}"/> garantiza una
    /// sola inicialización thread-safe; un fallo real no se reintenta con cada correo,
    /// pero el ajuste externo aplicado antes del primer uso sí se respeta.
    /// </summary>
    static bool AsegurarFuentes() => fuentesListas.Value;

    /// <summary>
    /// Intenta crear el comprobante para <paramref name="tipo"/>. Devuelve false sin
    /// error cuando el tipo no aplica (por ejemplo PedidoEstado).
    /// </summary>
    public static bool TryCrear(string tipo, JsonElement datos, int idPedido, int idPago,
        out AdjuntoCorreo? adjunto, out string? error, int maximoBytes = AdjuntoCorreo.MaximoBytes)
    {
        adjunto = null;
        error = null;

        var nombreTipo = tipo?.Trim() ?? "";
        var esPedido = nombreTipo.Equals("PedidoCreado", StringComparison.OrdinalIgnoreCase);
        var esPago = nombreTipo.Equals("ComprobantePago", StringComparison.OrdinalIgnoreCase)
            || nombreTipo.Equals("PagoConfirmado", StringComparison.OrdinalIgnoreCase);
        if (!esPedido && !esPago) return false;

        if (datos.ValueKind != JsonValueKind.Object)
        {
            error = "snapshot invalido";
            return false;
        }

        if (esPedido && idPedido <= 0)
        {
            error = "pedido invalido";
            return false;
        }

        if (esPago && idPago <= 0)
        {
            error = "pago invalido";
            return false;
        }

        try
        {
            if (!AsegurarFuentes())
            {
                error = "no se pudo preparar la tipografia del comprobante";
                return false;
            }

            var nombre = esPedido
                ? $"LavaFacil-Pedido-{idPedido}.pdf"
                : $"LavaFacil-Comprobante-{idPago}.pdf";

            var bytes = Construir(datos, esPedido, idPedido, idPago);
            if (bytes.Length > maximoBytes)
            {
                error = "comprobante excede el limite";
                return false;
            }

            adjunto = new AdjuntoCorreo(nombre, bytes);
            return true;
        }
        catch (Exception ex)
        {
            adjunto = null;
            error = $"no se pudo generar el comprobante ({ex.GetType().Name})";
            return false;
        }
    }

    static byte[] Construir(JsonElement datos, bool esPedido, int idPedido, int idPago)
    {
        using var documento = new PdfDocument();
        documento.Info.Title = "Comprobante LavaFácil";
        documento.Info.Author = "LavaFácil";
        documento.Info.Subject = "Comprobante operativo";
        documento.Info.Creator = "LavaFácil";

        var paginaActual = documento.AddPage();
        paginaActual.Size = PageSize.A4;
        paginaActual.Orientation = PageOrientation.Portrait;

        XGraphics grafico = XGraphics.FromPdfPage(paginaActual);
        try
        {
            var ancho = paginaActual.Width.Point;
            var alto = paginaActual.Height.Point;
            var limite = alto - ResguardoInferior;
            var numeroPagina = 1;

            var y = DibujarEncabezado(grafico, datos, esPedido, idPedido, idPago, ancho, primera: true);
            DibujarPie(grafico, ancho, alto, numeroPagina);

            var cliente = Cliente(datos);
            if (cliente.Length > 0)
            {
                var fuenteCliente = Fuente(10, XFontStyleEx.Regular);
                const string prefijoCliente = "Cliente: ";
                var anchoCliente = ancho - (Margen * 2) - grafico.MeasureString(prefijoCliente, fuenteCliente).Width;
                grafico.DrawString(prefijoCliente + Ajustar(grafico, cliente, fuenteCliente, anchoCliente),
                    fuenteCliente, new XSolidBrush(ColorTexto), Margen, y);
                y += 24;
            }
            else
            {
                y += 8;
            }

            void SiguientePagina()
            {
                grafico.Dispose();
                paginaActual = documento.AddPage();
                paginaActual.Size = PageSize.A4;
                paginaActual.Orientation = PageOrientation.Portrait;
                grafico = XGraphics.FromPdfPage(paginaActual);
                numeroPagina++;
                y = DibujarEncabezado(grafico, datos, esPedido, idPedido, idPago, ancho, primera: false);
                DibujarPie(grafico, ancho, alto, numeroPagina);
                if (esPedido) y = DibujarEncabezadoTabla(grafico, y, ancho);
            }

            if (esPedido)
            {
                y = DibujarEncabezadoTabla(grafico, y, ancho);

                var total = 0;
                if (datos.TryGetProperty("Detalle", out var detalle) && detalle.ValueKind == JsonValueKind.Array)
                    total = detalle.GetArrayLength();

                var mostrados = 0;
                if (total > 0)
                {
                    foreach (var item in detalle.EnumerateArray())
                    {
                        if (mostrados >= MaximoItems) break;
                        if (y + 16 > limite) SiguientePagina();

                        var servicio = Limpiar(Texto(item, "NombreServicio"), 100);
                        if (servicio.Length == 0) servicio = "Servicio";
                        var cantidad = Cantidad(item, "Cantidad");
                        var subtotal = Dinero(item, "Subtotal");

                        y = DibujarFila(grafico, y, ancho, servicio, cantidad, subtotal);
                        mostrados++;
                    }
                }

                if (total > MaximoItems)
                {
                    if (y + 16 > limite) SiguientePagina();
                    grafico.DrawString($"... y {total - MaximoItems} servicios más", Fuente(9, XFontStyleEx.Italic),
                        new XSolidBrush(ColorSuave), Margen, y);
                    y += 16;
                }

                if (total == 0)
                {
                    grafico.DrawString("Sin detalle de servicios.", Fuente(9, XFontStyleEx.Italic),
                        new XSolidBrush(ColorSuave), Margen, y);
                    y += 16;
                }

                var totalPedido = Dinero(datos, "Total", "TotalPedido");
                if (totalPedido.Length > 0)
                {
                    y += 6;
                    if (y + 24 > limite) SiguientePagina();

                    var fuenteTotal = Fuente(12, XFontStyleEx.Bold);
                    var brushTotal = new XSolidBrush(ColorTexto);
                    var cantDerecha = ancho - Margen - 110;
                    var subtotalDerecha = ancho - Margen;

                    grafico.DrawString("Total", fuenteTotal, brushTotal,
                        new XRect(Margen, y, Math.Max(0, cantDerecha - Margen - 8), 18), XStringFormats.TopRight);
                    grafico.DrawString(totalPedido, fuenteTotal, brushTotal,
                        new XRect(cantDerecha, y, Math.Max(0, subtotalDerecha - cantDerecha), 18), XStringFormats.TopRight);
                }
            }
            else
            {
                var filas = new (string Etiqueta, string Valor)[]
                {
                    ("Monto", Dinero(datos, "Monto")),
                    ("Estado", Limpiar(Texto(datos, "EstadoPago"), 60)),
                    ("Método", Limpiar(Texto(datos, "MetodoPago"), 60)),
                    ("Referencia", Limpiar(Texto(datos, "Referencia"), 100)),
                    ("Total del pedido", Dinero(datos, "TotalPedido", "Total"))
                };

                var fuenteEtiqueta = Fuente(10, XFontStyleEx.Bold);
                var fuenteValor = Fuente(10, XFontStyleEx.Regular);
                var anchoValor = ancho - Margen - (Margen + 130);
                var filasDibujadas = 0;
                foreach (var fila in filas)
                {
                    if (string.IsNullOrWhiteSpace(fila.Valor)) continue;
                    if (y + 18 > limite) SiguientePagina();
                    grafico.DrawString(fila.Etiqueta, fuenteEtiqueta, new XSolidBrush(ColorSuave), Margen, y);
                    grafico.DrawString(Ajustar(grafico, fila.Valor, fuenteValor, anchoValor),
                        fuenteValor, new XSolidBrush(ColorTexto), Margen + 130, y);
                    y += 20;
                    filasDibujadas++;
                }

                if (filasDibujadas == 0)
                {
                    if (y + 16 > limite) SiguientePagina();
                    grafico.DrawString("Sin datos de pago registrados.", Fuente(9, XFontStyleEx.Italic),
                        new XSolidBrush(ColorSuave), Margen, y);
                    y += 16;
                }
            }

            using var memoria = new MemoryStream();
            documento.Save(memoria, false);
            return memoria.ToArray();
        }
        finally
        {
            grafico.Dispose();
        }
    }

    static double DibujarEncabezado(XGraphics grafico, JsonElement datos, bool esPedido, int idPedido, int idPago,
        double ancho, bool primera)
    {
        var y = Margen;

        grafico.DrawString("LavaFácil", Fuente(primera ? 20 : 12, XFontStyleEx.Bold),
            new XSolidBrush(ColorMarca), Margen, y);
        y += primera ? 24 : 15;

        grafico.DrawString(esPedido ? "Comprobante de pedido" : "Comprobante de pago",
            Fuente(primera ? 10 : 9, XFontStyleEx.Regular), new XSolidBrush(ColorSuave), Margen, y);
        y += primera ? 20 : 14;

        var numero = idPedido > 0 ? idPedido : NumeroPedido(datos);
        var etiquetaPedido = esPedido
            ? (numero > 0 ? $"Pedido #{numero}" : $"Comprobante #{idPago}")
            : (numero > 0
                ? $"Comprobante de pago #{idPago} · Pedido #{numero}"
                : $"Comprobante de pago #{idPago}");
        var fecha = Fecha(datos, esPedido ? "FechaPedido" : "FechaPago");

        grafico.DrawString(etiquetaPedido, Fuente(10, XFontStyleEx.Regular), new XSolidBrush(ColorTexto),
            new XRect(Margen, Margen, ancho - (Margen * 2), 16), XStringFormats.TopRight);
        grafico.DrawString(fecha.ToString("dd/MM/yyyy HH:mm", CulturaInv), Fuente(9, XFontStyleEx.Regular),
            new XSolidBrush(ColorSuave), new XRect(Margen, Margen + 16, ancho - (Margen * 2), 14), XStringFormats.TopRight);

        grafico.DrawLine(new XPen(ColorLinea, 1), Margen, y, ancho - Margen, y);
        return y + 12;
    }

    static void DibujarPie(XGraphics grafico, double ancho, double alto, int numeroPagina)
    {
        var fuente = Fuente(7.5, XFontStyleEx.Regular);
        var lineaY = alto - 58;
        grafico.DrawLine(new XPen(ColorLinea, 1), Margen, lineaY, ancho - Margen, lineaY);
        grafico.DrawString("Comprobante operativo de LavaFácil. Este documento no constituye una factura fiscal.",
            fuente, new XSolidBrush(ColorSuave), Margen, lineaY + 6);
        grafico.DrawString($"Generado automáticamente · Página {numeroPagina}",
            fuente, new XSolidBrush(ColorSuave), Margen, lineaY + 18);
    }

    static double DibujarEncabezadoTabla(XGraphics grafico, double y, double ancho)
    {
        var fuente = Fuente(9.5, XFontStyleEx.Bold);
        var brush = new XSolidBrush(ColorSuave);
        var cantDerecha = ancho - Margen - 110;
        var subtotalDerecha = ancho - Margen;

        grafico.DrawString("Servicio", fuente, brush, Margen, y);
        grafico.DrawString("Cant.", fuente, brush,
            new XRect(Margen, y, Math.Max(0, cantDerecha - Margen), 14), XStringFormats.TopRight);
        grafico.DrawString("Subtotal", fuente, brush,
            new XRect(cantDerecha, y, Math.Max(0, subtotalDerecha - cantDerecha), 14), XStringFormats.TopRight);
        y += 14;
        grafico.DrawLine(new XPen(ColorLinea, 1), Margen, y, ancho - Margen, y);
        return y + 4;
    }

    static double DibujarFila(XGraphics grafico, double y, double ancho, string servicio, string cantidad, string subtotal)
    {
        var fuente = Fuente(9, XFontStyleEx.Regular);
        var brush = new XSolidBrush(ColorTexto);
        var cantDerecha = ancho - Margen - 110;
        var subtotalDerecha = ancho - Margen;
        var disponible = Math.Max(0, cantDerecha - Margen - 20);

        grafico.DrawString(Ajustar(grafico, servicio, fuente, disponible), fuente, brush, Margen, y);
        grafico.DrawString(cantidad, fuente, brush,
            new XRect(Margen, y, Math.Max(0, cantDerecha - Margen), 14), XStringFormats.TopRight);
        grafico.DrawString(subtotal, fuente, brush,
            new XRect(cantDerecha, y, Math.Max(0, subtotalDerecha - cantDerecha), 14), XStringFormats.TopRight);
        return y + 16;
    }

    static string Ajustar(XGraphics grafico, string texto, XFont fuente, double maximo)
    {
        if (string.IsNullOrEmpty(texto) || maximo <= 0) return "";
        if (grafico.MeasureString(texto, fuente).Width <= maximo) return texto;

        var recorte = texto;
        while (recorte.Length > 0)
        {
            recorte = recorte[..^1];
            var prueba = recorte.TrimEnd() + "...";
            if (grafico.MeasureString(prueba, fuente).Width <= maximo) return prueba;
        }
        return "";
    }

    static XFont Fuente(double tamano, XFontStyleEx estilo) =>
        new("Arial", tamano, estilo, new XPdfFontOptions(PdfFontEncoding.Unicode));

    static string Cliente(JsonElement datos)
    {
        var nombre = Limpiar(Texto(datos, "Nombre"), 120);
        var apellidos = Limpiar(Texto(datos, "Apellidos"), 120);
        return Limpiar(string.Join(" ", new[] { nombre, apellidos }.Where(s => s.Length > 0)), 120);
    }

    static int NumeroPedido(JsonElement datos)
    {
        if (!datos.TryGetProperty("IdPedido", out var valor)) return 0;
        if (valor.ValueKind == JsonValueKind.Number && valor.TryGetInt32(out var numero)) return numero;
        return int.TryParse(valor.ToString(), NumberStyles.Integer, CulturaInv, out numero) ? numero : 0;
    }

    static DateTimeOffset Fecha(JsonElement datos, string propiedad)
    {
        if (datos.TryGetProperty(propiedad, out var valor))
        {
            if (valor.ValueKind == JsonValueKind.String
                && DateTimeOffset.TryParse(valor.GetString(), CulturaInv, DateTimeStyles.None, out var fecha))
                return fecha;

            if (valor.ValueKind == JsonValueKind.Number && valor.TryGetInt64(out var milisegundos))
            {
                try { return DateTimeOffset.FromUnixTimeMilliseconds(milisegundos); }
                catch (ArgumentOutOfRangeException) { /* Fuera de rango: se usa la fecha actual. */ }
            }
        }

        return DateTimeOffset.Now;
    }

    static string Cantidad(JsonElement elemento, string propiedad)
    {
        if (!elemento.TryGetProperty(propiedad, out var valor)) return "";
        if (valor.ValueKind == JsonValueKind.Number && valor.TryGetDecimal(out var numero))
            return numero.ToString("0.##", CulturaInv);
        if (decimal.TryParse(valor.ToString(), NumberStyles.Number, CulturaInv, out numero))
            return numero.ToString("0.##", CulturaInv);
        return Limpiar(valor.ToString(), 20);
    }

    static string Dinero(JsonElement elemento, params string[] propiedades)
    {
        foreach (var propiedad in propiedades)
        {
            if (!elemento.TryGetProperty(propiedad, out var valor)) continue;

            if (valor.ValueKind == JsonValueKind.Number && valor.TryGetDecimal(out var numero))
                return numero.ToString("C2", CulturaCr);

            if (valor.ValueKind == JsonValueKind.String
                && decimal.TryParse(valor.GetString(), NumberStyles.Number, CulturaInv, out numero))
                return numero.ToString("C2", CulturaCr);
        }

        return "";
    }

    static string Texto(JsonElement elemento, string propiedad)
    {
        if (!elemento.TryGetProperty(propiedad, out var valor)) return "";
        return valor.ValueKind is JsonValueKind.Null or JsonValueKind.Undefined ? "" : valor.ToString();
    }

    static string Limpiar(string? valor, int maximo)
    {
        if (string.IsNullOrEmpty(valor)) return "";

        var limpio = new StringBuilder(valor.Length);
        foreach (var c in valor)
        {
            if (c is '\r' or '\n' or '\t' || char.IsControl(c)) continue;
            limpio.Append(c);
        }

        var texto = limpio.ToString().Trim();
        return texto.Length > maximo ? texto[..maximo] : texto;
    }
}
