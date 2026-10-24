using Microsoft.AspNetCore.DataProtection;
using System.Text.Json;

namespace LavaFacil.GraphQL.Security;

public sealed record AppIdentity(int IdUsuario, string NombreUsuario, string Rol);
public sealed class TokenService(IDataProtectionProvider provider)
{
    private readonly IDataProtector _protector = provider.CreateProtector("LavaFacil.GraphQL.Auth.v1");
    public string Create(AppIdentity identity) => _protector.Protect(JsonSerializer.Serialize(identity));
    public AppIdentity? Read(string token)
    {
        try { return JsonSerializer.Deserialize<AppIdentity>(_protector.Unprotect(token)); }
        catch { return null; }
    }
}
