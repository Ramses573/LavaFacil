/// <summary>
/// Archivo adjunto listo para enviarse por correo. Un adjunto invalido se descarta
/// sin interrumpir el envio del mensaje.
/// </summary>
sealed record AdjuntoCorreo(string NombreArchivo, byte[] Contenido)
{
    public const int MaximoBytes = 1_500_000;

    /// <summary>
    /// Valida nombre (ASCII, extension .pdf, sin caracteres de control, separadores
    /// de ruta, comillas ni "..") y contenido. Devuelve true cuando el adjunto puede
    /// enviarse.
    /// </summary>
    public bool TryValidar(out string? error)
    {
        error = null;

        var nombre = NombreArchivo;
        if (string.IsNullOrWhiteSpace(nombre))
        {
            error = "adjunto sin nombre";
            return false;
        }

        if (nombre.Length is < 5 or > 80)
        {
            error = "nombre de adjunto fuera de rango";
            return false;
        }

        if (nombre.Contains('/') || nombre.Contains('\\')
            || nombre.Contains('\r') || nombre.Contains('\n') || nombre.Contains('"') || nombre.Contains('\'')
            || nombre.Contains("..", StringComparison.Ordinal))
        {
            error = "nombre de adjunto invalido";
            return false;
        }

        foreach (var c in nombre)
        {
            if (c is < (char)0x20 or > (char)0x7E)
            {
                error = "nombre de adjunto no ASCII";
                return false;
            }
        }

        if (!nombre.EndsWith(".pdf", StringComparison.OrdinalIgnoreCase))
        {
            error = "adjunto no es PDF";
            return false;
        }

        if (Contenido is null || Contenido.Length == 0)
        {
            error = "adjunto vacio";
            return false;
        }

        if (Contenido.Length > MaximoBytes)
        {
            error = "adjunto excede el limite";
            return false;
        }

        if (Contenido.Length < 5
            || Contenido[0] != (byte)'%' || Contenido[1] != (byte)'P'
            || Contenido[2] != (byte)'D' || Contenido[3] != (byte)'F'
            || Contenido[4] != (byte)'-')
        {
            error = "contenido de adjunto no es PDF";
            return false;
        }

        return true;
    }
}
