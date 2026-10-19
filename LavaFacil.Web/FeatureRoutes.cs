using System.Data;
using System.Security.Cryptography;
using System.Security.Claims;
using System.Text.Json;
using Microsoft.AspNetCore.Authentication;
using Microsoft.Data.SqlClient;

static class FeatureRoutes
{
    static SqlParameter Int(string name, int? value) => new(name, SqlDbType.Int) { Value = (object?)value ?? DBNull.Value };
    static SqlParameter Bit(string name, bool value) => new(name, SqlDbType.Bit) { Value = value };
    static SqlParameter Money(string name, decimal value) => new(name, SqlDbType.Decimal) { Precision=10, Scale=2, Value=value };
    static SqlParameter Date(string name, DateOnly? value) => new(name, SqlDbType.Date) { Value = value is null ? DBNull.Value : value.Value.ToDateTime(TimeOnly.MinValue) };
    static string Text(string? value, int max) { if (value?.Length>max) throw new ArgumentException($"El texto admite hasta {max} caracteres."); return value?.Trim() ?? ""; }
    static void Number(decimal value, bool positive=false) { if(value<0 || (positive && value==0) || value>99999999.99m || decimal.Round(value,2)!=value) throw new ArgumentException("Usa importes positivos con máximo dos decimales y dentro del rango permitido."); }
    public static void Map(RouteGroupBuilder api)
    {
        api.MapGet("/catalog", async (HttpContext ctx, Database db, string? search, bool? inactive) =>
            await db.Call("app_BuscarServicios", new[] { Database.Id(ctx),Database.Param("Busqueda",Text(search,100),100),Bit("IncluirInactivos",inactive??false) }));
        api.MapPost("/catalog", async (ServiceInput input,HttpContext ctx,Database db) => {
            Database.Required(input.Name,"Nombre",100); Text(input.Description,250);
            if(!new[]{"Unidad","Uniforme","Kilogramo"}.Contains(input.ChargeType)) throw new ArgumentException("Tipo de cobro inválido.");
            Number(input.BasePrice);Number(input.IncludedQuantity,true);Number(input.AdditionalPrice);
            return await db.Call("app_GuardarServicio",new[]{Database.Id(ctx),Int("IdServicio",input.Id),Database.Param("NombreServicio",input.Name.Trim(),100),
                Database.Param("Descripcion",input.Description,250),Database.Param("TipoCobro",input.ChargeType,20),Money("PrecioBase",input.BasePrice),
                Money("CantidadIncluida",input.IncludedQuantity),Money("PrecioAdicional",input.AdditionalPrice),Bit("Activo",input.Active)});
        });
        api.MapGet("/orders",async (HttpContext ctx,Database db,DateOnly? from,DateOnly? to,string? status,string? search,int? serviceId) =>
            await db.Call("app_BuscarPedidos",new[]{Database.Id(ctx),Date("Desde",from),Date("Hasta",to),Database.Param("Estado",Text(status,20),20),
                Database.Param("Busqueda",Text(search,100),100),Int("IdServicio",serviceId)}));
        api.MapGet("/orders/{id:int}",async(int id,HttpContext ctx,Database db)=>await db.Call("app_DetallePedido",new[]{Database.Id(ctx),Int("IdPedido",id)}));
        api.MapPost("/orders",async(OrderInput input,HttpContext ctx,Database db)=>{
            if(input.Lines is null || input.Lines.Length is <1 or >30) throw new ArgumentException("Agrega de 1 a 30 servicios.");
            foreach(var line in input.Lines) { Number(line.Quantity,true); if(line.ServiceId<=0 || line.Quantity>10000) throw new ArgumentException("Revisa el servicio y la cantidad."); }
            if(input.Lines.Select(l=>l.ServiceId).Distinct().Count()!=input.Lines.Length) throw new ArgumentException("No repitas servicios; ajusta su cantidad.");
            return await db.Call("app_CrearPedido",new[]{Database.Id(ctx),Int("IdCliente",input.ClientId),Database.Param("Observaciones",Text(input.Notes,300),300),
                new SqlParameter("Lineas",SqlDbType.NVarChar,-1){Value=JsonSerializer.Serialize(input.Lines,new JsonSerializerOptions{PropertyNamingPolicy=JsonNamingPolicy.CamelCase})}});
        });
        api.MapPost("/orders/{id:int}/status",async(int id,OrderStatus input,HttpContext ctx,Database db)=>
            await db.Call("app_CambiarEstadoPedido",new[]{Database.Id(ctx),Int("IdPedido",id),Database.Param("Estado",Text(input.Status,20),20)}));
        api.MapGet("/preferences",async(HttpContext ctx,Database db)=>await db.Call("app_Preferencias",new[]{Database.Id(ctx)}));
        api.MapPost("/preferences",async(PreferencesInput input,HttpContext ctx,Database db)=>await db.Call("app_GuardarPreferencias",new[]{Database.Id(ctx),
            Database.Param("Avatar",Text(input.Avatar,20),20),Database.Param("Tema",Text(input.Theme,20),20),
            new SqlParameter("Biografia",SqlDbType.NVarChar,200){Value=Text(input.Bio,200)},Database.Param("Direccion",Text(input.Address,250),250)}));
        api.MapPost("/client-account",async(ClientAccountInput input,HttpContext ctx,Database db)=>{
            Database.Required(input.Username,"Usuario",50); AppPasswords.CheckNew(input.Password);
            // Autorizar antes de invertir trabajo en el hash.
            await db.Call("app_ExigirAdministrador",new[]{Database.Id(ctx)});
            return await db.Call("app_CrearCuentaCliente",new[]{Database.Id(ctx),Int("IdCliente",input.ClientId),Database.Param("NombreUsuario",input.Username.Trim(),50),Database.Param("Hash",AppPasswords.Hash(input.Password),255)});
        });
        api.MapPost("/password",async(PasswordInput input,HttpContext ctx,Database db)=>{
            Database.Required(input.CurrentPassword,"Contraseña actual",255); AppPasswords.CheckNew(input.NewPassword);
            var result=await AppPasswords.Authenticate(db,ctx.User.Identity!.Name!,input.CurrentPassword);
            if(result.Rows.Count==0 || !Convert.ToBoolean(result.Rows[0]["LoginValido"]) || Convert.ToString(result.Rows[0]["IdUsuario"])!=ctx.User.FindFirstValue(ClaimTypes.NameIdentifier))
                throw new ArgumentException("La contraseña actual no es correcta.");
            await db.Call("app_GuardarClave",new[]{Database.Id(ctx),Database.Param("Hash",AppPasswords.Hash(input.NewPassword),255)});
            await ctx.SignOutAsync();
            return Results.Ok(new {message="Contraseña actualizada. Inicia sesión nuevamente."});
        });
    }
}
static class AppPasswords
{
    const int Iterations=210000;
    public static void CheckNew(string password) { Database.Required(password,"Contraseña",255); if(password.Length<10) throw new ArgumentException("Usa una contraseña de al menos 10 caracteres."); }
    public static string Hash(string password) {
        var salt=RandomNumberGenerator.GetBytes(16);
        var hash=Rfc2898DeriveBytes.Pbkdf2(password,salt,Iterations,HashAlgorithmName.SHA256,32);
        return $"PBKDF2-SHA256${Iterations}${Convert.ToBase64String(salt)}${Convert.ToBase64String(hash)}";
    }
    static bool Verify(string password,string hash) {
        try {
            var parts=hash.Split('$');
            if(parts.Length!=4 || parts[0]!="PBKDF2-SHA256" || !int.TryParse(parts[1],out var iterations) || iterations<100000 || iterations>1000000) return false;
            var actual=Rfc2898DeriveBytes.Pbkdf2(password,Convert.FromBase64String(parts[2]),iterations,HashAlgorithmName.SHA256,32);
            return CryptographicOperations.FixedTimeEquals(actual,Convert.FromBase64String(parts[3]));
        } catch(FormatException) { return false; }
    }
    public static async Task<QueryResult> Authenticate(Database db,string username,string password) {
        QueryResult? result=null;
        try { result=await db.Call("app_Credencial",new[]{Database.Param("NombreUsuario",username,50)}); }
        catch(SqlException ex) when(ex.Number==2812) { /* Compatibilidad con instalaciones anteriores a la migración. */ }
        if(result?.Rows.FirstOrDefault() is { } row && row["ClaveHash"] is string hash && !string.IsNullOrEmpty(hash)) {
            var valid=Verify(password,hash); row.Remove("ClaveHash"); row["LoginValido"]=valid;
            return result;
        }
        return await db.Call("usp_ValidarLogin",new[]{Database.Param("NombreUsuario",username,50),Database.Param("Clave",password,255)});
    }
}
record ServiceInput(int? Id,string Name,string? Description,string ChargeType,decimal BasePrice,decimal IncludedQuantity,decimal AdditionalPrice,bool Active);
record OrderLine(int ServiceId,decimal Quantity);
record OrderInput(int? ClientId,string? Notes,OrderLine[] Lines);
record OrderStatus(string Status);
record PreferencesInput(string Avatar,string Theme,string? Bio,string? Address);
record ClientAccountInput(int ClientId,string Username,string Password);
record PasswordInput(string CurrentPassword,string NewPassword);
