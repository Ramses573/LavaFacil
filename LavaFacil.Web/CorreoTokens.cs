using System.Security.Cryptography;
using System.Text;

/// <summary>
/// Genera y protege los codigos de 6 digitos del modulo de correo.
/// El codigo nunca se guarda en claro: solo su HMAC-SHA256 con un pepper local.
/// </summary>
static class CorreoTokens
{
    const string ArchivoPepper = "correo.pepper.dpapi";
    static readonly object Candado = new();
    static string? carpetaDatos;
    static byte[]? pepper;

    /// <summary>Fija la carpeta Data de la aplicacion. Debe llamarse una vez al iniciar las rutas.</summary>
    public static void Initialize(string contentRootPath)
    {
        lock (Candado)
        {
            carpetaDatos ??= Path.Combine(contentRootPath, "Data");
        }
    }

    /// <summary>Pepper de 32 bytes, generado la primera vez y cifrado con DPAPI del usuario de Windows.</summary>
    public static byte[] Pepper
    {
        get
        {
            lock (Candado)
            {
                var actual = pepper;
                if (actual is not null) return actual;

                if (string.IsNullOrEmpty(carpetaDatos))
                    throw new InvalidOperationException("El modulo de correo no se inicializo correctamente.");

                var ruta = Path.Combine(carpetaDatos, ArchivoPepper);
                if (File.Exists(ruta))
                {
                    byte[] leido;
                    try
                    {
                        leido = ProtectedData.Unprotect(File.ReadAllBytes(ruta), null, DataProtectionScope.CurrentUser);
                    }
                    catch (CryptographicException)
                    {
                        throw new InvalidOperationException("No se pudo leer el secreto de correo. Verifica que la app se ejecute con el mismo usuario de Windows que lo creo.");
                    }

                    if (leido.Length != 32)
                        throw new InvalidOperationException("El secreto de correo esta danado. Deten la app, elimina Data/correo.pepper.dpapi y vuelve a iniciarla.");

                    pepper = leido;
                    return leido;
                }

                var generado = RandomNumberGenerator.GetBytes(32);
                Directory.CreateDirectory(carpetaDatos);
                File.WriteAllBytes(ruta, ProtectedData.Protect(generado, null, DataProtectionScope.CurrentUser));
                pepper = generado;
                return generado;
            }
        }
    }

    /// <summary>Codigo de 6 digitos criptograficamente aleatorio.</summary>
    public static string GenerarCodigo() => RandomNumberGenerator.GetInt32(0, 1_000_000).ToString("D6");

    /// <summary>Hash del codigo ligado a su proposito para que no se reutilice entre flujos.</summary>
    public static byte[] Hash(string proposito, string codigo)
    {
        ArgumentException.ThrowIfNullOrEmpty(proposito);
        ArgumentException.ThrowIfNullOrEmpty(codigo);
        return HMACSHA256.HashData(Pepper, Encoding.UTF8.GetBytes(proposito + "|" + codigo));
    }
}
