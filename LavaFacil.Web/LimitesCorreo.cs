using System.Collections.Concurrent;

/// <summary>
/// Limites de frecuencia en memoria para el modulo de correo.
/// Cada combinacion clave + ventana mantiene su propio contador.
/// </summary>
static class LimitesCorreo
{
    const int MaximoEntradas = 5000;

    sealed class Estado
    {
        public DateTime Inicio;
        public int Conteo;
        public DateTime Fin;
    }

    static readonly ConcurrentDictionary<string, Estado> estados = new(StringComparer.Ordinal);

    // Ultimo rechazo por clave base, para informar un Retry-After util.
    static readonly ConcurrentDictionary<string, DateTime> rechazos = new(StringComparer.Ordinal);

    // La aplicación es loopback y corre en una sola instancia; este límite no
    // pretende coordinar límites entre procesos o nodos (no es distribuido).
    static readonly object admision = new();

    /// <summary>
    /// Registra un intento si la clave no supero el maximo en la ventana.
    /// Devuelve false cuando debe rechazarse.
    /// </summary>
    public static bool Permite(string clave, int maximo, TimeSpan ventana)
    {
        if (string.IsNullOrWhiteSpace(clave) || maximo <= 0 || ventana <= TimeSpan.Zero) return false;

        var ahora = DateTime.UtcNow;
        var interno = clave + "|" + (long)ventana.TotalSeconds;
        if (!estados.TryGetValue(interno, out var estado))
        {
            lock (admision)
            {
                // Revalidar dentro del cerrojo evita que dos claves nuevas
                // superen el límite por una carrera entre GetOrAdd/Count.
                if (!estados.TryGetValue(interno, out estado))
                {
                    Purgar(ahora);
                    if (estados.Count >= MaximoEntradas) return false;

                    estado = new Estado { Inicio = ahora, Fin = ahora + ventana };
                    estados.TryAdd(interno, estado);
                }
            }
        }

        DateTime? rechazoHasta = null;
        lock (estado)
        {
            if (ahora >= estado.Fin)
            {
                estado.Inicio = ahora;
                estado.Conteo = 0;
                estado.Fin = ahora + ventana;
            }

            if (estado.Conteo >= maximo)
            {
                var segundos = (int)Math.Ceiling((estado.Fin - ahora).TotalSeconds);
                rechazoHasta = ahora.AddSeconds(segundos < 1 ? 1 : segundos);
            }
            else
            {
                estado.Conteo++;
            }
        }

        if (rechazoHasta.HasValue)
        {
            RegistrarRechazo(clave, rechazoHasta.Value, ahora);
            return false;
        }

        return true;
    }

    /// <summary>Segundos que faltan para que la ultima clave rechazada vuelva a estar disponible.</summary>
    public static int SegundosRestantes(string clave)
    {
        if (string.IsNullOrWhiteSpace(clave)) return 0;

        var ahora = DateTime.UtcNow;
        if (rechazos.TryGetValue(clave, out var hasta))
        {
            var segundos = (int)Math.Ceiling((hasta - ahora).TotalSeconds);
            if (segundos > 0) return segundos;
            rechazos.TryRemove(clave, out _);
        }

        var maximo = 0;
        foreach (var par in estados)
        {
            if (!Coincide(par.Key, clave)) continue;

            int restante;
            lock (par.Value)
            {
                restante = (int)Math.Ceiling((par.Value.Fin - ahora).TotalSeconds);
            }
            if (restante > maximo) maximo = restante;
        }
        return maximo;
    }

    /// <summary>Elimina los contadores de la clave para permitir un reintento inmediato.</summary>
    public static void Liberar(string clave)
    {
        if (string.IsNullOrWhiteSpace(clave)) return;

        rechazos.TryRemove(clave, out _);
        foreach (var interno in estados.Keys)
        {
            if (Coincide(interno, clave)) estados.TryRemove(interno, out _);
        }
    }

    static bool Coincide(string almacenada, string clave) =>
        almacenada.StartsWith(clave + "|", StringComparison.Ordinal);

    static void Purgar(DateTime ahora)
    {
        foreach (var par in estados)
        {
            lock (par.Value)
            {
                if (ahora >= par.Value.Fin) estados.TryRemove(par.Key, out _);
            }
        }

        foreach (var par in rechazos)
        {
            if (ahora >= par.Value) rechazos.TryRemove(par.Key, out _);
        }
    }

    static void RegistrarRechazo(string clave, DateTime hasta, DateTime ahora)
    {
        lock (admision)
        {
            if (rechazos.ContainsKey(clave))
            {
                rechazos[clave] = hasta;
                return;
            }

            // Purga antes de insertar y rechaza el registro auxiliar si no
            // queda espacio; el bucket principal ya ha sido rechazado.
            Purgar(ahora);
            if (rechazos.Count < MaximoEntradas)
                rechazos.TryAdd(clave, hasta);
        }
    }
}
