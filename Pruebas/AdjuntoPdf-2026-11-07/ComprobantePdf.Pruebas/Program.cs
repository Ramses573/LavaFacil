using System.Globalization;
using System.Reflection;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.FileProviders;
using UglyToad.PdfPig;

var salida = args.Length > 0 ? Path.GetFullPath(args[0]) : Directory.GetCurrentDirectory();
Directory.CreateDirectory(salida);

var casos = new List<Caso>();
var consola = new StringBuilder();

void Ejecutar(string id, string titulo, Action prueba)
{
    try
    {
        prueba();
        casos.Add(new Caso(id, titulo, "PASS", ""));
        consola.AppendLine($"PASS  {id}  {titulo}");
    }
    catch (Exception ex)
    {
        var mensaje = ex is FalloPrueba ? ex.Message : $"{ex.GetType().Name}: {ex.Message}";
        casos.Add(new Caso(id, titulo, "FAIL", mensaje));
        consola.AppendLine($"FAIL  {id}  {titulo}");
        consola.AppendLine($"      {mensaje}");
    }
}

static void Exigir(bool condicion, string mensaje)
{
    if (!condicion) throw new FalloPrueba(mensaje);
}

static void ExigirTexto(string texto, string esperado, string contexto)
{
    if (!Normalizar(texto).Contains(esperado, StringComparison.Ordinal))
        throw new FalloPrueba($"{contexto}: no se encontro '{esperado}'. Texto extraido: {Recortar(texto)}");
}

// PdfPig separa palabras con U+00A0 en este PDF; se normaliza solo para comparar.
static string Normalizar(string texto) =>
    texto.Replace('\u00A0', ' ').Replace('\u202F', ' ').Replace('\u2007', ' ');

static int Contar(string texto, string buscado)
{
    var total = 0;
    var indice = 0;
    while ((indice = texto.IndexOf(buscado, indice, StringComparison.Ordinal)) >= 0)
    {
        total++;
        indice += buscado.Length;
    }
    return total;
}

static string Recortar(string texto) =>
    texto.Length <= 600 ? texto : texto[..600] + "…";

static string TextoPdf(byte[] bytes, out int paginas)
{
    using var pdf = PdfDocument.Open(bytes);
    paginas = pdf.NumberOfPages;
    var partes = new List<string>();
    for (var i = 1; i <= paginas; i++) partes.Add(pdf.GetPage(i).Text);
    return string.Join("\n", partes);
}

static string SnapshotPedido(int id, string nombre, string apellidos, decimal total, int items, string servicioBase = "Servicio")
{
    var detalle = new StringBuilder();
    for (var i = 1; i <= items; i++)
    {
        if (i > 1) detalle.Append(',');
        var subtotal = total / Math.Max(1, items);
        detalle.Append($$"""
            {"NombreServicio":"{{servicioBase}} {{i:00}}","Cantidad":1,"Subtotal":{{subtotal.ToString("0.00", CultureInfo.InvariantCulture)}}}
            """);
    }

    return $$"""
        {
          "IdPedido": {{id}},
          "Nombre": {{JsonSerializer.Serialize(nombre)}},
          "Apellidos": {{JsonSerializer.Serialize(apellidos)}},
          "FechaPedido": "2026-11-07T10:15:00-06:00",
          "Total": {{total.ToString("0.00", CultureInfo.InvariantCulture)}},
          "Estado": "Pendiente",
          "Detalle": [{{detalle}}]
        }
        """;
}

// El snapshot real de pago trae TotalPedido. El parámetro permite reproducir el
// caso legado (solo Total) y el caso con filas opcionales vacías.
static string SnapshotPago(int idPedido, int idPago, bool incluirTotalPedido = true, bool incluirCamposOpcionales = true)
{
    var campos = new List<string>
    {
        $"\"IdPedido\": {idPedido}",
        $"\"IdPago\": {idPago}",
        "\"Nombre\": \"María\"",
        "\"Apellidos\": \"Solano Vega\"",
        "\"FechaPago\": \"2026-11-07T11:30:00-06:00\"",
        "\"Monto\": 4500.00"
    };
    if (incluirCamposOpcionales)
    {
        campos.Add("\"EstadoPago\": \"Aprobado\"");
        campos.Add("\"MetodoPago\": \"Tarjeta\"");
        campos.Add("\"Referencia\": \"REF-2026-0001\"");
    }
    campos.Add(incluirTotalPedido ? "\"TotalPedido\": 4500.00" : "\"Total\": 4500.00");
    return "{\n  " + string.Join(",\n  ", campos) + "\n}";
}

// ---------------------------------------------------------------------------
// Caso 1: PedidoCreado real (snapshot representativo de la cola)
// ---------------------------------------------------------------------------
Ejecutar("1", "PedidoCreado genera PDF A4 legible con datos del pedido", () =>
{
    const string json = """
        {
          "IdPedido": 18,
          "Nombre": "Carlos",
          "Apellidos": "Ramírez Quesada",
          "FechaPedido": "2026-11-07T09:05:00-06:00",
          "Total": 4500.00,
          "Estado": "Pendiente",
          "Detalle": [
            {"NombreServicio":"Lavado por kilo","Cantidad":2,"Subtotal":3000.00},
            {"NombreServicio":"Planchado","Cantidad":1,"Subtotal":1500.00}
          ]
        }
        """;
    using var doc = JsonDocument.Parse(json);
    var ok = ComprobantePdf.TryCrear("PedidoCreado", doc.RootElement, 18, 0, out var adjunto, out var error);
    Exigir(ok, $"TryCrear devolvio false. error={error}");
    Exigir(adjunto is not null, "adjunto nulo");
    Exigir(error is null, $"error inesperado: {error}");
    var bytes = adjunto!.Contenido;
    Exigir(bytes.Length >= 5 && Encoding.ASCII.GetString(bytes, 0, 5) == "%PDF-", "los bytes no empiezan con %PDF-");
    Exigir(bytes.Length < 1_500_000, $"tamano {bytes.Length} >= 1.5 MB");
    var texto = TextoPdf(bytes, out var paginas);
    var visible = Normalizar(texto);
    Exigir(paginas >= 1, $"paginas={paginas}");
    ExigirTexto(texto, "LavaFácil", "marca");
    ExigirTexto(texto, "Pedido #18", "numero");
    ExigirTexto(texto, "Lavado por kilo", "servicio");
    var totalExacto = visible.Contains("₡4 500,00", StringComparison.Ordinal)
        || visible.Contains("₡4.500,00", StringComparison.Ordinal);
    var totalDigitos = visible.Contains("4 500,00", StringComparison.Ordinal)
        || visible.Contains("4.500,00", StringComparison.Ordinal);
    var nota = totalExacto ? "total exacto con simbolo ₡" : totalDigitos ? "total sin simbolo, digitos encontrados" : "TOTAL DEL PEDIDO AUSENTE";
    File.WriteAllText(Path.Combine(salida, "caso1-texto-extraido.txt"),
        $"paginas={paginas}\nbytes={bytes.Length}\n{nota}\n\n{texto}", new UTF8Encoding(false));
    Exigir(totalExacto || totalDigitos,
        $"total con formato es-CR no encontrado (se esperaba el total del pedido). Texto: {Recortar(visible)}");
});

// ---------------------------------------------------------------------------
// Caso 2: acentos
// ---------------------------------------------------------------------------
Ejecutar("2", "Acentos y ñ se conservan en el PDF", () =>
{
    using var doc = JsonDocument.Parse(SnapshotPedido(19, "José Ñandú", "Muñoz", 1000m, 1, "Lavandería"));
    var ok = ComprobantePdf.TryCrear("PedidoCreado", doc.RootElement, 19, 0, out var adjunto, out var error);
    Exigir(ok, $"TryCrear false: {error}");
    var texto = TextoPdf(adjunto!.Contenido, out _);
    ExigirTexto(texto, "José Ñandú Muñoz", "cliente");
    ExigirTexto(texto, "Lavandería", "servicio");
    Exigir(!texto.Contains('?'), "el texto contiene '?' (posible perdida de acentos)");
    File.WriteAllText(Path.Combine(salida, "caso2-texto-extraido.txt"), texto, new UTF8Encoding(false));
});

// ---------------------------------------------------------------------------
// Caso 3a: 30 items (capacidad de una sola pagina)
//
// Nota: la expectativa original de ">=2 paginas" era incorrecta. Con filas de
// 16 pt, 30 filas caben en una A4 (empezando en y~138 y terminando en y~618,
// por debajo del limite ~770), por lo que el PDF correcto tiene 1 pagina. La
// paginacion real se verifica aparte en el caso 3c (45 items -> >=2 paginas).
// Aqui se comprueba lo que de verdad importa: el contenido completo y el total.
// ---------------------------------------------------------------------------
Ejecutar("3a", "30 items: los 30 nombres y el total (una sola vez) caben en la A4", () =>
{
    using var doc = JsonDocument.Parse(SnapshotPedido(20, "Ana", "Mora", 3000m, 30, "Servicio"));
    var ok = ComprobantePdf.TryCrear("PedidoCreado", doc.RootElement, 20, 0, out var adjunto, out var error);
    Exigir(ok, $"TryCrear false: {error}");

    // El PDF abre con PdfPig y no excede el tamano permitido.
    var bytes = adjunto!.Contenido;
    Exigir(bytes.Length >= 5 && Encoding.ASCII.GetString(bytes, 0, 5) == "%PDF-", "los bytes no empiezan con %PDF-");
    Exigir(bytes.Length < 1_500_000, $"tamano {bytes.Length} >= 1.5 MB");
    var texto = TextoPdf(bytes, out var paginas);
    var visible = Normalizar(texto);

    var faltantes = Enumerable.Range(1, 30)
        .Select(i => $"Servicio {i:00}")
        .Where(n => !visible.Contains(n, StringComparison.Ordinal))
        .ToList();
    Exigir(faltantes.Count == 0, $"faltan nombres: {string.Join(", ", faltantes)}; paginas={paginas}");

    // El total del pedido (3000.00) debe aparecer exactamente una vez.
    var ocurrenciasTotal = Contar(visible, "3 000,00");
    Exigir(ocurrenciasTotal == 1,
        $"se esperaba el total '3 000,00' una sola vez, aparece {ocurrenciasTotal} vez/veces. Texto: {Recortar(visible)}");

    File.WriteAllText(Path.Combine(salida, "caso3a-texto-extraido.txt"),
        $"paginas={paginas}\nbytes={bytes.Length}\nnombresPresentes={30 - faltantes.Count}\nocurrenciasTotal={ocurrenciasTotal}\n\n{texto}", new UTF8Encoding(false));
});

// ---------------------------------------------------------------------------
// Caso 3b: 60 items -> tope 50
// ---------------------------------------------------------------------------
Ejecutar("3b", "60 items: se corta en 50 y aparece '... y 10 servicios mas'", () =>
{
    using var doc = JsonDocument.Parse(SnapshotPedido(21, "Luis", "Vargas", 6000m, 60, "Servicio"));
    var ok = ComprobantePdf.TryCrear("PedidoCreado", doc.RootElement, 21, 0, out var adjunto, out var error);
    Exigir(ok, $"TryCrear false: {error}");
    var texto = TextoPdf(adjunto!.Contenido, out var paginas);
    var visible = Normalizar(texto);
    var presentes = Enumerable.Range(1, 60)
        .Select(i => $"Servicio {i:00}")
        .Count(n => visible.Contains(n, StringComparison.Ordinal));
    Exigir(presentes == 50, $"se esperaban exactamente 50 nombres, presentes={presentes}");
    Exigir(visible.Contains("... y 10 servicios más", StringComparison.Ordinal),
        $"no aparece el aviso de corte; paginas={paginas}. Texto: {Recortar(visible)}");
    File.WriteAllText(Path.Combine(salida, "caso3b-texto-extraido.txt"),
        $"paginas={paginas}\nnombresPresentes={presentes}\n\n{texto}", new UTF8Encoding(false));
});

// ---------------------------------------------------------------------------
// Caso 3c (diagnostico): 45 items para comprobar que la paginacion existe
// ---------------------------------------------------------------------------
Ejecutar("3c-diagnostico", "45 items: la paginacion si entra en accion (>=2 paginas)", () =>
{
    using var doc = JsonDocument.Parse(SnapshotPedido(22, "Rosa", "Jiménez", 4500m, 45, "Servicio"));
    var ok = ComprobantePdf.TryCrear("PedidoCreado", doc.RootElement, 22, 0, out var adjunto, out var error);
    Exigir(ok, $"TryCrear false: {error}");
    var texto = Normalizar(TextoPdf(adjunto!.Contenido, out var paginas));
    var faltantes = Enumerable.Range(1, 45)
        .Select(i => $"Servicio {i:00}")
        .Where(n => !texto.Contains(n, StringComparison.Ordinal))
        .ToList();
    Exigir(faltantes.Count == 0, $"faltan nombres: {string.Join(", ", faltantes)}; paginas={paginas}");
    Exigir(paginas >= 2, $"45 items tampoco alcanzaron 2 paginas (paginas={paginas})");
    File.WriteAllText(Path.Combine(salida, "caso3c-texto-extraido.txt"),
        $"paginas={paginas}\n\n{texto}", new UTF8Encoding(false));
});

// ---------------------------------------------------------------------------
// Caso 4: ComprobantePago (snapshot real con TotalPedido)
// ---------------------------------------------------------------------------
Ejecutar("4", "ComprobantePago: titulo con idPago/idPedido, datos, TotalPedido y sin tabla", () =>
{
    using var doc = JsonDocument.Parse(SnapshotPago(18, 77));
    var ok = ComprobantePdf.TryCrear("ComprobantePago", doc.RootElement, 18, 77, out var adjunto, out var error);
    Exigir(ok, $"TryCrear false: {error}");
    Exigir(adjunto!.NombreArchivo == "LavaFacil-Comprobante-77.pdf",
        $"nombre={adjunto.NombreArchivo}");
    var texto = TextoPdf(adjunto.Contenido, out _);
    var visible = Normalizar(texto);
    ExigirTexto(texto, "Comprobante de pago #77", "titulo pago");
    ExigirTexto(texto, "Pedido #18", "pedido en titulo");
    ExigirTexto(texto, "Tarjeta", "metodo");
    ExigirTexto(texto, "REF-2026-0001", "referencia");
    ExigirTexto(texto, "Total del pedido", "fila TotalPedido");
    Exigir(visible.Contains("4 500,00", StringComparison.Ordinal) || visible.Contains("4.500,00", StringComparison.Ordinal),
        $"monto no encontrado. Texto: {Recortar(visible)}");
    Exigir(visible.Contains("no constituye una factura fiscal", StringComparison.OrdinalIgnoreCase),
        "falta la leyenda fiscal");
    Exigir(!visible.Contains("Subtotal", StringComparison.Ordinal), "el comprobante de pago contiene tabla de servicios (Subtotal)");
    Exigir(!visible.Contains("Servicio", StringComparison.Ordinal), "el comprobante de pago contiene 'Servicio'");
    File.WriteAllText(Path.Combine(salida, "caso4-texto-extraido.txt"), texto, new UTF8Encoding(false));
});

// ---------------------------------------------------------------------------
// Caso 4b: fallback TotalPedido -> Total (snapshot legado)
// ---------------------------------------------------------------------------
Ejecutar("4b", "ComprobantePago sin TotalPedido usa Total como respaldo", () =>
{
    using var doc = JsonDocument.Parse(SnapshotPago(18, 77, incluirTotalPedido: false));
    var ok = ComprobantePdf.TryCrear("ComprobantePago", doc.RootElement, 18, 77, out var adjunto, out var error);
    Exigir(ok, $"TryCrear false: {error}");
    var texto = Normalizar(TextoPdf(adjunto!.Contenido, out _));
    Exigir(texto.Contains("Total del pedido", StringComparison.Ordinal),
        $"falta la fila de total con fallback. Texto: {Recortar(texto)}");
    Exigir(texto.Contains("4 500,00", StringComparison.Ordinal) || texto.Contains("4.500,00", StringComparison.Ordinal),
        $"el fallback Total no se mostro. Texto: {Recortar(texto)}");
    File.WriteAllText(Path.Combine(salida, "caso4b-texto-extraido.txt"), texto, new UTF8Encoding(false));
});

// ---------------------------------------------------------------------------
// Caso 4c: las filas de pago vacías se omiten
// ---------------------------------------------------------------------------
Ejecutar("4c", "ComprobantePago omite filas vacias (Estado, Metodo, Referencia)", () =>
{
    using var doc = JsonDocument.Parse(SnapshotPago(18, 77, incluirTotalPedido: true, incluirCamposOpcionales: false));
    var ok = ComprobantePdf.TryCrear("ComprobantePago", doc.RootElement, 18, 77, out var adjunto, out var error);
    Exigir(ok, $"TryCrear false: {error}");
    var texto = Normalizar(TextoPdf(adjunto!.Contenido, out _));
    foreach (var etiqueta in new[] { "Estado", "Método", "Referencia" })
        Exigir(!texto.Contains(etiqueta, StringComparison.Ordinal),
            $"se dibujo la fila vacia '{etiqueta}'. Texto: {Recortar(texto)}");
    Exigir(texto.Contains("Total del pedido", StringComparison.Ordinal),
        $"no se dibujo la fila de total. Texto: {Recortar(texto)}");
    File.WriteAllText(Path.Combine(salida, "caso4c-texto-extraido.txt"), texto, new UTF8Encoding(false));
});

// ---------------------------------------------------------------------------
// Caso 5: PedidoEstado no aplica
// ---------------------------------------------------------------------------
Ejecutar("5", "PedidoEstado: TryCrear false sin error", () =>
{
    using var doc = JsonDocument.Parse(SnapshotPedido(18, "Carlos", "Ramírez", 4500m, 2));
    var ok = ComprobantePdf.TryCrear("PedidoEstado", doc.RootElement, 18, 0, out var adjunto, out var error);
    Exigir(!ok, "TryCrear devolvio true para PedidoEstado");
    Exigir(adjunto is null, "adjunto no nulo para PedidoEstado");
    Exigir(error is null, $"error no nulo: {error}");
});

// ---------------------------------------------------------------------------
// Caso 6: errores controlados
// ---------------------------------------------------------------------------
Ejecutar("6", "snapshot invalido (array) y limite de tamano: false con error, sin excepcion", () =>
{
    using var array = JsonDocument.Parse("[]");
    var ok = ComprobantePdf.TryCrear("PedidoCreado", array.RootElement, 18, 0, out var adjunto, out var error);
    Exigir(!ok, "array aceptado como snapshot");
    Exigir(adjunto is null, "adjunto no nulo para array");
    Exigir(!string.IsNullOrWhiteSpace(error), "error vacio para array");

    using var pedido = JsonDocument.Parse(SnapshotPedido(18, "Carlos", "Ramírez", 4500m, 2));
    var okLimite = ComprobantePdf.TryCrear("PedidoCreado", pedido.RootElement, 18, 0, out var adjuntoLimite, out var errorLimite, maximoBytes: 10);
    Exigir(!okLimite, "limite de 10 bytes aceptado");
    Exigir(adjuntoLimite is null, "adjunto no nulo con limite excedido");
    Exigir(!string.IsNullOrWhiteSpace(errorLimite), "error vacio con limite excedido");
});

// ---------------------------------------------------------------------------
// Casos 7-9: outbox con IWebHostEnvironment falso
// ---------------------------------------------------------------------------
Ejecutar("7", "Outbox con adjunto: boundaries aleatorios, alternative anidado y PDF base64", () =>
{
    var trabajo = NuevoEntornoPrueba();
    try
    {
        Environment.SetEnvironmentVariable("LAVAFACIL_CORREO_SALIDA", trabajo.Outbox);
        var env = new EntornoFalso { EnvironmentName = "Test", ContentRootPath = trabajo.Content, WebRootPath = trabajo.WebRoot };
        var smtp = new CorreoSmtp(env);
        Exigir(smtp.OutboxActivo, "OutboxActivo=false");

        using var doc = JsonDocument.Parse(SnapshotPedido(18, "Carlos", "Ramírez Quesada", 4500m, 2));
        Exigir(ComprobantePdf.TryCrear("PedidoCreado", doc.RootElement, 18, 0, out var pdf, out var error), $"no se pudo generar PDF: {error}");
        var adjunto = new AdjuntoCorreo("LavaFacil-Pedido-18.pdf", pdf!.Contenido);

        var resultado = smtp.EnviarMensajeAsync("cliente@example.com", "Carlos", "LavaFácil · Confirmación de pedido #18",
            "Texto plano", "<p>HTML</p>", new[] { adjunto }, CancellationToken.None).GetAwaiter().GetResult();
        Exigir(resultado.Enviado, $"envio fallo: {resultado.Error}");
        Exigir(resultado.Advertencia is null, $"advertencia inesperada: {resultado.Advertencia}");

        var ruta = ArchivoUnico(trabajo.Outbox, ".eml");
        var eml = File.ReadAllText(ruta, Encoding.UTF8).Replace("\r\n", "\n");

        // Los boundaries son aleatorios: se descubren del propio EML.
        var mixto = BoundaryDe(eml, "multipart/mixed");
        var alternativo = BoundaryDe(eml, "multipart/alternative");
        Exigir(mixto != alternativo, "los boundaries de mixed y alternative son iguales");
        foreach (var boundary in new[] { mixto, alternativo })
            Exigir(Regex.IsMatch(boundary, "^lavafacil-[0-9a-f]{32}$", RegexOptions.CultureInvariant),
                $"boundary no aleatorio: {boundary}");
        Exigir(!eml.Contains("lavafacil-mixed", StringComparison.Ordinal), "quedo el boundary fijo lavafacil-mixed");
        Exigir(!eml.Contains("lavafacil-boundary", StringComparison.Ordinal), "quedo el boundary fijo lavafacil-boundary");

        var primerContentType = eml.IndexOf("Content-Type:", StringComparison.Ordinal);
        var tipoRaiz = eml.IndexOf($"Content-Type: multipart/mixed; boundary=\"{mixto}\"", StringComparison.Ordinal);
        Exigir(tipoRaiz == primerContentType, "multipart/mixed no es el Content-Type raiz");
        Exigir(eml.Contains($"--{mixto}\nContent-Type: multipart/alternative; boundary=\"{alternativo}\"", StringComparison.Ordinal),
            "multipart/alternative no esta anidado como primera parte de multipart/mixed");
        Exigir(eml.IndexOf("multipart/mixed", StringComparison.Ordinal) < eml.IndexOf("multipart/alternative", StringComparison.Ordinal),
            "multipart/mixed no contiene al alternative");

        ExigirTexto(eml, "Content-Type: application/pdf; name=\"LavaFacil-Pedido-18.pdf\"", "parte PDF");
        ExigirTexto(eml, "Content-Transfer-Encoding: base64", "base64");
        ExigirTexto(eml, "filename=\"LavaFacil-Pedido-18.pdf\"", "filename");

        var bytes = DecodificarPartePdf(eml, mixto);
        Exigir(bytes.Length == pdf.Contenido.Length, $"longitud decodificada {bytes.Length} != original {pdf.Contenido.Length}");
        Exigir(bytes.Length >= 5 && Encoding.ASCII.GetString(bytes, 0, 5) == "%PDF-", "el adjunto decodificado no es PDF");
        var texto = TextoPdf(bytes, out var paginas);
        Exigir(paginas >= 1, $"paginas={paginas}");
        ExigirTexto(texto, "LavaFácil", "PDF decodificado");
        ExigirTexto(texto, "Pedido #18", "PDF decodificado");
        File.WriteAllText(Path.Combine(salida, "caso7-eml-normalizado.txt"), eml, new UTF8Encoding(false));
    }
    finally
    {
        Environment.SetEnvironmentVariable("LAVAFACIL_CORREO_SALIDA", null);
        Limpiar(trabajo.Base);
    }
});

Ejecutar("8", "Regresion OTP: sin multipart/mixed ni application/pdf", () =>
{
    var trabajo = NuevoEntornoPrueba();
    try
    {
        Environment.SetEnvironmentVariable("LAVAFACIL_CORREO_SALIDA", trabajo.Outbox);
        var env = new EntornoFalso { EnvironmentName = "Test", ContentRootPath = trabajo.Content, WebRootPath = trabajo.WebRoot };
        var smtp = new CorreoSmtp(env);
        Exigir(smtp.OutboxActivo, "OutboxActivo=false");
        var resultado = smtp.EnviarCodigoAsync("ana@example.com", "Ana", "123456", "verificacion", 10, CancellationToken.None)
            .GetAwaiter().GetResult();
        Exigir(resultado.Enviado, $"envio fallo: {resultado.Error}");
        var ruta = ArchivoUnico(trabajo.Outbox, ".eml");
        var eml = File.ReadAllText(ruta, Encoding.UTF8).Replace("\r\n", "\n");
        Exigir(!eml.Contains("multipart/mixed", StringComparison.Ordinal), "OTP contiene multipart/mixed");
        Exigir(!eml.Contains("application/pdf", StringComparison.OrdinalIgnoreCase), "OTP contiene application/pdf");
        ExigirTexto(eml, "multipart/alternative", "alternative");
        ExigirTexto(eml, "Codigo: 123456", "codigo en cuerpo");
        File.WriteAllText(Path.Combine(salida, "caso8-eml-normalizado.txt"), eml, new UTF8Encoding(false));
    }
    finally
    {
        Environment.SetEnvironmentVariable("LAVAFACIL_CORREO_SALIDA", null);
        Limpiar(trabajo.Base);
    }
});

Ejecutar("9", "Adjunto invalido: se descarta, Enviado=true y Advertencia no nula", () =>
{
    var trabajo = NuevoEntornoPrueba();
    try
    {
        Environment.SetEnvironmentVariable("LAVAFACIL_CORREO_SALIDA", trabajo.Outbox);
        var env = new EntornoFalso { EnvironmentName = "Test", ContentRootPath = trabajo.Content, WebRootPath = trabajo.WebRoot };
        var smtp = new CorreoSmtp(env);
        Exigir(smtp.OutboxActivo, "OutboxActivo=false");

        using var doc = JsonDocument.Parse(SnapshotPedido(18, "Carlos", "Ramírez", 4500m, 1));
        Exigir(ComprobantePdf.TryCrear("PedidoCreado", doc.RootElement, 18, 0, out var pdf, out _), "no se pudo generar PDF base");
        var invalidos = new[]
        {
            new AdjuntoCorreo("Lava\r\nFacil.pdf", pdf!.Contenido),
            new AdjuntoCorreo("LavaFacil-Pedido-18.pdf", Array.Empty<byte>()),
            new AdjuntoCorreo("LavaFacil-Pedido-18.pdf", Encoding.ASCII.GetBytes("NO ES UN PDF"))
        };
        var resultado = smtp.EnviarMensajeAsync("cliente@example.com", "Carlos", "Asunto valido", "Texto", "<p>HTML</p>", invalidos, CancellationToken.None)
            .GetAwaiter().GetResult();
        Exigir(resultado.Enviado, $"envio fallo: {resultado.Error}");
        Exigir(!string.IsNullOrWhiteSpace(resultado.Advertencia), "Advertencia nula para adjuntos invalidos");
        var ruta = ArchivoUnico(trabajo.Outbox, ".eml");
        var eml = File.ReadAllText(ruta, Encoding.UTF8);
        Exigir(!eml.Contains("application/pdf", StringComparison.OrdinalIgnoreCase), "el EML contiene el adjunto invalido");
        Exigir(!eml.Contains("multipart/mixed", StringComparison.Ordinal), "el EML usa multipart/mixed sin adjuntos validos");
        ExigirTexto(eml, "multipart/alternative", "alternative");
        File.WriteAllText(Path.Combine(salida, "caso9-advertencia.txt"), resultado.Advertencia!, new UTF8Encoding(false));
        File.WriteAllText(Path.Combine(salida, "caso9-eml-normalizado.txt"),
            eml.Replace("\r\n", "\n"), new UTF8Encoding(false));
    }
    finally
    {
        Environment.SetEnvironmentVariable("LAVAFACIL_CORREO_SALIDA", null);
        Limpiar(trabajo.Base);
    }
});

// ---------------------------------------------------------------------------
// Caso 10: regla de seguridad del outbox
// ---------------------------------------------------------------------------
Ejecutar("10", "Outbox deshabilitado si LAVAFACIL_CORREO_SALIDA cae dentro del sitio", () =>
{
    var trabajo = NuevoEntornoPrueba();
    var webRootExterno = Path.Combine(trabajo.Base, "web-externo");
    Directory.CreateDirectory(webRootExterno);
    try
    {
        // (a) dentro de ContentRootPath -> deshabilitado
        var dentroContent = Path.Combine(trabajo.Content, "outbox-interno");
        Directory.CreateDirectory(dentroContent);
        Environment.SetEnvironmentVariable("LAVAFACIL_CORREO_SALIDA", dentroContent);
        var envContent = new EntornoFalso { EnvironmentName = "Test", ContentRootPath = trabajo.Content, WebRootPath = trabajo.WebRoot };
        Exigir(!new CorreoSmtp(envContent).OutboxActivo,
            "OutboxActivo=true con outbox dentro de ContentRootPath");

        // (b) dentro de WebRootPath -> deshabilitado
        var dentroWeb = Path.Combine(webRootExterno, "outbox-web");
        Directory.CreateDirectory(dentroWeb);
        Environment.SetEnvironmentVariable("LAVAFACIL_CORREO_SALIDA", dentroWeb);
        var envWeb = new EntornoFalso { EnvironmentName = "Test", ContentRootPath = trabajo.Content, WebRootPath = webRootExterno };
        Exigir(!new CorreoSmtp(envWeb).OutboxActivo,
            "OutboxActivo=true con outbox dentro de WebRootPath");

        // (c) control: fuera de ambos -> habilitado
        Environment.SetEnvironmentVariable("LAVAFACIL_CORREO_SALIDA", trabajo.Outbox);
        var envFuera = new EntornoFalso { EnvironmentName = "Test", ContentRootPath = trabajo.Content, WebRootPath = trabajo.WebRoot };
        Exigir(new CorreoSmtp(envFuera).OutboxActivo,
            "OutboxActivo=false con outbox fuera del sitio (control)");
    }
    finally
    {
        Environment.SetEnvironmentVariable("LAVAFACIL_CORREO_SALIDA", null);
        Limpiar(trabajo.Base);
    }
});

// ---------------------------------------------------------------------------
// Caso 11: validacion de contenido PDF en AdjuntoCorreo
// ---------------------------------------------------------------------------
Ejecutar("11", "AdjuntoCorreo rechaza contenido que no empieza por %PDF-", () =>
{
    var valido = new AdjuntoCorreo("LavaFacil-Pedido-18.pdf", Encoding.ASCII.GetBytes("%PDF-1.7\n%prueba"));
    Exigir(valido.TryValidar(out var errorValido), $"contenido %PDF- rechazado: {errorValido}");

    var invalido = new AdjuntoCorreo("LavaFacil-Pedido-18.pdf", Encoding.ASCII.GetBytes("<html>no es un pdf</html>"));
    Exigir(!invalido.TryValidar(out var error), "TryValidar acepto contenido sin la firma %PDF-");
    Exigir(!string.IsNullOrWhiteSpace(error), "error vacio para contenido sin firma PDF");

    // Firma incompleta (4 bytes) tambien debe rechazarse sin excepcion.
    var truncado = new AdjuntoCorreo("LavaFacil-Pedido-18.pdf", Encoding.ASCII.GetBytes("%PDF"));
    Exigir(!truncado.TryValidar(out var errorTruncado), "TryValidar acepto '%PDF' sin guion");
    Exigir(!string.IsNullOrWhiteSpace(errorTruncado), "error vacio para firma PDF incompleta");
});

// ---------------------------------------------------------------------------
// Extra: integracion con CorreoPedidos (comprobacion por reflexion, sin DB)
// ---------------------------------------------------------------------------
Ejecutar("extra-correopedidos", "CorreoPedidos adjunta en PedidoCreado/Pago y no en PedidoEstado", () =>
{
    var metodo = typeof(CorreoPedidos).GetMethod("CrearMensaje", BindingFlags.NonPublic | BindingFlags.Static);
    Exigir(metodo is not null, "no se encontro CorreoPedidos.CrearMensaje por reflexion");

    object Invocar(string tipo, string datosJson, object? idPedido, object? idPago)
    {
        var fila = new Dictionary<string, object?>
        {
            ["Tipo"] = tipo,
            ["DatosJson"] = datosJson,
            ["Destino"] = "cliente@example.com",
            ["IdPedido"] = idPedido,
            ["IdPago"] = idPago
        };
        return metodo!.Invoke(null, new object?[] { fila })!;
    }

    static object? Prop(object instancia, string nombre) =>
        instancia.GetType().GetProperty(nombre)?.GetValue(instancia);

    var creado = Invocar("PedidoCreado", SnapshotPedido(18, "Carlos", "Ramírez", 4500m, 2), 18, 0);
    Exigir(Prop(creado, "Adjunto") is not null, "PedidoCreado sin adjunto");
    Exigir(Prop(creado, "ErrorAdjunto") is null, $"PedidoCreado con ErrorAdjunto: {Prop(creado, "ErrorAdjunto")}");

    var pago = Invocar("ComprobantePago", SnapshotPago(18, 77), 18, 77);
    Exigir(Prop(pago, "Adjunto") is not null, "ComprobantePago sin adjunto");
    var nombrePago = (string?)Prop(Prop(pago, "Adjunto")!, "NombreArchivo");
    Exigir(nombrePago == "LavaFacil-Comprobante-77.pdf", $"nombre del adjunto de pago: {nombrePago}");

    var estado = Invocar("PedidoEstado", SnapshotPedido(18, "Carlos", "Ramírez", 4500m, 2), 18, 0);
    Exigir(Prop(estado, "Adjunto") is null, "PedidoEstado genero adjunto");
});

File.WriteAllText(Path.Combine(salida, "resultados.json"),
    JsonSerializer.Serialize(new
    {
        generado = DateTimeOffset.Now.ToString("O", CultureInfo.InvariantCulture),
        total = casos.Count,
        pasan = casos.Count(c => c.Estado == "PASS"),
        fallan = casos.Count(c => c.Estado == "FAIL"),
        casos
    }, new JsonSerializerOptions { WriteIndented = true, Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping }),
    new UTF8Encoding(false));

Console.WriteLine(consola.ToString());
Console.WriteLine($"TOTAL: {casos.Count(c => c.Estado == "PASS")} PASS / {casos.Count(c => c.Estado == "FAIL")} FAIL");
return casos.Any(c => c.Estado == "FAIL") ? 1 : 0;

static EntornoPrueba NuevoEntornoPrueba()
{
    var baseDir = Path.Combine(Path.GetTempPath(), "lavafacil-adjuntopdf-" + Guid.NewGuid().ToString("N"));
    var content = Path.Combine(baseDir, "sitio");
    var webRoot = Path.Combine(content, "wwwroot");
    // Outbox deliberadamente fuera de ContentRootPath y WebRootPath.
    var outbox = Path.Combine(baseDir, "outbox");
    Directory.CreateDirectory(webRoot);
    Directory.CreateDirectory(outbox);
    return new EntornoPrueba(baseDir, content, webRoot, outbox);
}

static void Limpiar(string ruta)
{
    try { if (Directory.Exists(ruta)) Directory.Delete(ruta, true); } catch { /* limpieza best effort */ }
}

static string ArchivoUnico(string carpeta, string extension)
{
    var archivos = Directory.Exists(carpeta)
        ? Directory.GetFiles(carpeta, "*" + extension)
        : Array.Empty<string>();
    if (archivos.Length == 0) throw new FalloPrueba($"no se genero ningun {extension} en {carpeta}");
    return archivos.OrderByDescending(File.GetLastWriteTimeUtc).First();
}

// Descubre el boundary que el propio EML declara para un tipo multipart.
static string BoundaryDe(string eml, string tipo)
{
    var patron = "Content-Type:\\s*" + Regex.Escape(tipo) + ";[^\\n]*boundary=\"([^\"]+)\"";
    var coincidencia = Regex.Match(eml, patron, RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);
    if (!coincidencia.Success) throw new FalloPrueba($"no se encontro boundary para {tipo}");
    return coincidencia.Groups[1].Value;
}

static byte[] DecodificarPartePdf(string eml, string boundaryMixto)
{
    var indice = eml.IndexOf("Content-Type: application/pdf", StringComparison.Ordinal);
    if (indice < 0) throw new FalloPrueba("no se encontro la parte application/pdf");
    var inicio = eml.IndexOf("\n\n", indice, StringComparison.Ordinal);
    if (inicio < 0) throw new FalloPrueba("no se encontro el cuerpo de la parte PDF");
    inicio += 2;
    var fin = eml.IndexOf("\n--" + boundaryMixto, inicio, StringComparison.Ordinal);
    if (fin < 0) throw new FalloPrueba("no se encontro el fin de la parte PDF");
    var base64 = new string(eml[inicio..fin].Where(c => !char.IsWhiteSpace(c)).ToArray());
    return Convert.FromBase64String(base64);
}

sealed record EntornoPrueba(string Base, string Content, string WebRoot, string Outbox);

sealed class FalloPrueba(string mensaje) : Exception(mensaje);

sealed record Caso(string Id, string Titulo, string Estado, string Detalle);

sealed class EntornoFalso : IWebHostEnvironment
{
    public string ApplicationName { get; set; } = "LavaFacil.Pruebas";
    public IFileProvider WebRootFileProvider { get; set; } = new NullFileProvider();
    public string WebRootPath { get; set; } = "";
    public string EnvironmentName { get; set; } = "Test";
    public string ContentRootPath { get; set; } = "";
    public IFileProvider ContentRootFileProvider { get; set; } = new NullFileProvider();
}

// Stub minimo de la clase Database que CorreoPedidos.cs referencia.
// No se conecta a SQL: el harness no ejercita el bucle del BackgroundService.
sealed class Database
{
    public bool Configured => false;

    public Task<ResultadoConsultaStub> Call(string procedure, IEnumerable<Microsoft.Data.SqlClient.SqlParameter> parameters)
        => Task.FromResult(new ResultadoConsultaStub());
}

sealed class ResultadoConsultaStub
{
    public List<Dictionary<string, object?>> Rows { get; } = new();
}
