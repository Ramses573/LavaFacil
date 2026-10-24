namespace LavaFacil.GraphQL.Security;

public sealed class RequestIdentity(IHttpContextAccessor accessor, TokenService tokens)
{
    public AppIdentity? Current
    {
        get
        {
            var value = accessor.HttpContext?.Request.Headers.Authorization.ToString();
            if (string.IsNullOrWhiteSpace(value) || !value.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase)) return null;
            return tokens.Read(value[7..].Trim());
        }
    }
    public bool IsStaff => Current?.Rol is "Administrador" or "Empleado";
    public void RequireStaff()
    {
        if (!IsStaff) throw new GraphQLException("Esta operación requiere una cuenta de empleado o administrador.");
    }
}
