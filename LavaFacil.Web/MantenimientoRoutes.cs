using System.Data;
using System.Globalization;
using System.Security.Claims;
using Microsoft.Data.SqlClient;

/// <summary>
/// Rutas de mantenimiento del proyecto final: empresa, empleados, usuarios,
/// inventario, promociones, recolecciones, pagos y borrado de servicios.
/// Todo el acceso a datos ocurre por procedimientos almacenados.
/// </summary>
static class MantenimientoRoutes
{
    static SqlParameter Int(string name, int? value) => new(name, SqlDbType.Int) { Value = (object?)value ?? DBNull.Value };
    static SqlParameter Bit(string name, bool value) => new(name, SqlDbType.Bit) { Value = value };
    static SqlParameter Money(string name, decimal value) => new(name, SqlDbType.Decimal) { Precision = 10, Scale = 2, Value = value };
    static SqlParameter Pct(string name, decimal value) => new(name, SqlDbType.Decimal) { Precision = 5, Scale = 2, Value = value };
    static SqlParameter Qty(string name, decimal value) => new(name, SqlDbType.Decimal) { Precision = 9, Scale = 2, Value = value };
    static SqlParameter Date(string name, DateOnly? value) => new(name, SqlDbType.Date) { Value = value is null ? DBNull.Value : value.Value.ToDateTime(TimeOnly.MinValue) };
    static SqlParameter Stamp(string name, DateTime? value) => new(name, SqlDbType.DateTime) { Value = value is null ? DBNull.Value : value.Value };

    static string Text(string? value, int max) {
        if (value?.Length > max) throw new ArgumentException($"El texto admite hasta {max} caracteres.");
        return (value ?? "").Trim();
    }
    static string Text(string? value, string label, int max) {
        var text = Text(value, max);
        if (text.Length == 0) throw new ArgumentException($"{label} es obligatorio.");
        return text;
    }
    static void Range(decimal value, decimal min, decimal max, string label) {
        if (value < min || value > max || decimal.Round(value, 2) != value)
            throw new ArgumentException($"{label} debe estar entre {min} y {max} con máximo dos decimales.");
    }

    public static void Map(RouteGroupBuilder api, WebApplication app)
    {
        // ---------- Información corporativa (pública) ----------
        app.MapGet("/api/public/empresa", async (Database db) => await db.Call("app_EmpresaPublica", Array.Empty<SqlParameter>()));
        app.MapGet("/api/public/servicios", async (Database db) => await db.Call("app_ServiciosPublicos", Array.Empty<SqlParameter>()));

        api.MapGet("/empresa", async (HttpContext ctx, Database db) =>
            await db.Call("app_EmpresaPublica", Array.Empty<SqlParameter>()));
        api.MapPost("/empresa", async (EmpresaInput input, HttpContext ctx, Database db) =>
            await db.Call("app_GuardarEmpresa", new[] {
                Database.Id(ctx),
                Database.Param("Nombre", Text(input.Name, "Nombre", 150), 150),
                Database.Param("Eslogan", Text(input.Slogan, 200), 200),
                new SqlParameter("Descripcion", SqlDbType.NVarChar, 1000) { Value = Text(input.Description, 1000) },
                Database.Param("Telefono", Text(input.Phone, 20), 20),
                Database.Param("Email", Text(input.Email, 150), 150),
                Database.Param("Direccion", Text(input.Address, 250), 250),
                Database.Param("Horario", Text(input.Schedule, 200), 200),
                Database.Param("Facebook", Text(input.Facebook, 200), 200),
                Database.Param("Instagram", Text(input.Instagram, 200), 200)
            }));

        // ---------- Empleados ----------
        api.MapGet("/employees", async (HttpContext ctx, Database db, string? search, bool? inactive) =>
            await db.Call("app_ConsultarEmpleados", new[] { Database.Id(ctx), Database.Param("Busqueda", Text(search, 100), 100), Bit("IncluirInactivos", inactive ?? false) }));
        api.MapPost("/employees", async (EmployeeInput input, HttpContext ctx, Database db) =>
            await db.Call("app_GuardarEmpleado", new[] {
                Database.Id(ctx), Int("IdEmpleado", input.Id),
                Database.Param("Cedula", Text(input.Identity, "Cédula", 20), 20),
                Database.Param("Nombre", Text(input.Name, "Nombre", 50), 50),
                Database.Param("Apellidos", Text(input.LastName, "Apellidos", 100), 100),
                Database.Param("Telefono", Text(input.Phone, "Teléfono", 20), 20),
                Database.Param("Email", Text(input.Email, "Correo", 150), 150),
                Database.Param("Cargo", Text(input.Job, "Cargo", 30), 30),
                Date("FechaIngreso", input.StartDate),
                Bit("Activo", input.Active)
            }));
        api.MapPost("/employees/{id:int}/status", async (int id, StatusInput input, HttpContext ctx, Database db) =>
            await db.Call("app_CambiarEstadoEmpleado", new[] { Database.Id(ctx), Int("IdEmpleado", id), Bit("Activo", input.Active) }));
        api.MapPost("/employees/{id:int}/delete", async (int id, HttpContext ctx, Database db) =>
            await db.Call("app_EliminarEmpleado", new[] { Database.Id(ctx), Int("IdEmpleado", id) }));

        // ---------- Usuarios ----------
        api.MapGet("/users", async (HttpContext ctx, Database db, string? search, bool? inactive) =>
            await db.Call("app_ConsultarUsuarios", new[] { Database.Id(ctx), Database.Param("Busqueda", Text(search, 100), 100), Bit("IncluirInactivos", inactive ?? true) }));
        api.MapPost("/users", async (UserInput input, HttpContext ctx, Database db) => {
            var role = Text(input.Role, "Rol", 20);
            if (role is not ("Cliente" or "Empleado" or "Administrador")) throw new ArgumentException("Rol inválido.");
            var hash = string.IsNullOrEmpty(input.Password) ? null : AppPasswords.Hash(RequireNewPassword(input.Password));
            return await db.Call("app_GuardarUsuario", new[] {
                Database.Id(ctx), Int("IdUsuarioObjetivo", input.Id),
                Database.Param("NombreUsuario", Text(input.Username, "Usuario", 50), 50),
                Database.Param("TipoUsuario", role, 20),
                Int("IdCliente", input.ClientId),
                Int("IdEmpleado", input.EmployeeId),
                Bit("Activo", input.Active),
                Database.Param("NuevoHash", hash, 255)
            });
        });
        api.MapPost("/users/{id:int}/status", async (int id, StatusInput input, HttpContext ctx, Database db) =>
            await db.Call("app_CambiarEstadoUsuario", new[] { Database.Id(ctx), Int("IdUsuarioObjetivo", id), Bit("Activo", input.Active) }));
        api.MapPost("/users/{id:int}/delete", async (int id, HttpContext ctx, Database db) =>
            await db.Call("app_EliminarUsuario", new[] { Database.Id(ctx), Int("IdUsuarioObjetivo", id) }));

        // ---------- Inventario ----------
        api.MapGet("/inventory", async (HttpContext ctx, Database db, string? search, bool? lowOnly) =>
            await db.Call("app_ConsultarInventario", new[] { Database.Id(ctx), Database.Param("Busqueda", Text(search, 100), 100), Bit("SoloBajoMinimo", lowOnly ?? false) }));
        api.MapPost("/inventory", async (InventoryInput input, HttpContext ctx, Database db) => {
            Range(input.Quantity, 0, 99999999, "Cantidad");
            Range(input.MinQuantity, 0, 99999999, "Cantidad mínima");
            return await db.Call("app_GuardarInventario", new[] {
                Database.Id(ctx), Int("IdInventario", input.Id),
                Database.Param("NombreProducto", Text(input.Name, "Producto", 100), 100),
                Database.Param("Descripcion", Text(input.Description, 250), 250),
                Qty("Cantidad", input.Quantity),
                Database.Param("UnidadMedida", Text(input.Unit, "Unidad de medida", 20), 20),
                Qty("CantidadMinima", input.MinQuantity),
                Bit("Activo", input.Active)
            });
        });
        api.MapPost("/inventory/{id:int}/status", async (int id, StatusInput input, HttpContext ctx, Database db) =>
            await db.Call("app_CambiarEstadoInventario", new[] { Database.Id(ctx), Int("IdInventario", id), Bit("Activo", input.Active) }));
        api.MapPost("/inventory/{id:int}/delete", async (int id, HttpContext ctx, Database db) =>
            await db.Call("app_EliminarInventario", new[] { Database.Id(ctx), Int("IdInventario", id) }));

        // ---------- Promociones ----------
        api.MapGet("/promotions", async (HttpContext ctx, Database db, string? search, bool? inactive) =>
            await db.Call("app_ConsultarPromociones", new[] { Database.Id(ctx), Database.Param("Busqueda", Text(search, 100), 100), Bit("IncluirInactivas", inactive ?? false) }));
        api.MapPost("/promotions", async (PromotionInput input, HttpContext ctx, Database db) => {
            if (input.Start is null || input.End is null) throw new ArgumentException("Indica la fecha de inicio y la fecha final.");
            if (input.End < input.Start) throw new ArgumentException("La fecha final no puede ser anterior a la inicial.");
            return await db.Call("app_GuardarPromocion", new[] {
                Database.Id(ctx), Int("IdPromocion", input.Id), Int("IdServicio", input.ServiceId),
                Database.Param("NombrePromocion", Text(input.Name, "Nombre", 100), 100),
                Database.Param("Descripcion", Text(input.Description, 250), 250),
                Pct("PorcentajeDescuento", input.Percent),
                Date("FechaInicio", input.Start),
                Date("FechaFin", input.End),
                Bit("Activa", input.Active)
            });
        });
        api.MapPost("/promotions/{id:int}/status", async (int id, StatusInput input, HttpContext ctx, Database db) =>
            await db.Call("app_CambiarEstadoPromocion", new[] { Database.Id(ctx), Int("IdPromocion", id), Bit("Activa", input.Active) }));
        api.MapPost("/promotions/{id:int}/delete", async (int id, HttpContext ctx, Database db) =>
            await db.Call("app_EliminarPromocion", new[] { Database.Id(ctx), Int("IdPromocion", id) }));

        // ---------- Recolecciones ----------
        api.MapGet("/collections", async (HttpContext ctx, Database db, string? search, string? status) =>
            await db.Call("app_ConsultarRecolecciones", new[] {
                Database.Id(ctx),
                Database.Param("Busqueda", Text(search, 100), 100),
                Database.Param("Estado", Text(status, 20), 20)
            }));
        api.MapPost("/collections", async (CollectionInput input, HttpContext ctx, Database db) => {
            if (input.OrderId is null) throw new ArgumentException("Selecciona el pedido.");
            if (input.Scheduled is null) throw new ArgumentException("Indica la fecha programada.");
            return await db.Call("app_GuardarRecoleccion", new[] {
                Database.Id(ctx), Int("IdRecoleccion", input.Id), Int("IdPedido", input.OrderId),
                Database.Param("Direccion", Text(input.Address, "Dirección", 250), 250),
                Stamp("FechaProgramada", input.Scheduled),
                Database.Param("Estado", Text(input.Status, "Estado", 20), 20),
                Database.Param("Observaciones", Text(input.Notes, 300), 300)
            });
        });
        api.MapPost("/collections/{id:int}/status", async (int id, CollectionStatusInput input, HttpContext ctx, Database db) =>
            await db.Call("app_CambiarEstadoRecoleccion", new[] {
                Database.Id(ctx), Int("IdRecoleccion", id), Database.Param("Estado", Text(input.Status, "Estado", 20), 20)
            }));
        api.MapPost("/collections/{id:int}/delete", async (int id, HttpContext ctx, Database db) =>
            await db.Call("app_EliminarRecoleccion", new[] { Database.Id(ctx), Int("IdRecoleccion", id) }));

        // ---------- Pagos ----------
        api.MapGet("/payments", async (HttpContext ctx, Database db, int? orderId, string? status, string? search) =>
            await db.Call("app_ConsultarPagos", new[] {
                Database.Id(ctx), Int("IdPedido", orderId),
                Database.Param("Estado", Text(status, 20), 20),
                Database.Param("Busqueda", Text(search, 100), 100)
            }));
        api.MapPost("/payments", async (PaymentInput input, HttpContext ctx, Database db) => {
            if (input.OrderId is null) throw new ArgumentException("Selecciona el pedido.");
            if (input.Amount <= 0) throw new ArgumentException("El monto debe ser mayor que cero.");
            return await db.Call("app_GuardarPago", new[] {
                Database.Id(ctx), Int("IdPago", input.Id), Int("IdPedido", input.OrderId),
                Money("Monto", input.Amount),
                Database.Param("MetodoPago", Text(input.Method, "Método", 20), 20),
                Database.Param("EstadoPago", Text(input.Status, "Estado", 20), 20),
                Database.Param("Referencia", Text(input.Reference, 100), 100)
            });
        });
        api.MapPost("/payments/{id:int}/delete", async (int id, HttpContext ctx, Database db) =>
            await db.Call("app_EliminarPago", new[] { Database.Id(ctx), Int("IdPago", id) }));

        // ---------- Borrado de servicios ----------
        api.MapPost("/catalog/{id:int}/delete", async (int id, HttpContext ctx, Database db) =>
            await db.Call("app_EliminarServicio", new[] { Database.Id(ctx), Int("IdServicio", id) }));
    }

    static string RequireNewPassword(string password) {
        AppPasswords.CheckNew(password);
        return password;
    }
}

record EmpresaInput(string Name, string? Slogan, string? Description, string? Phone, string? Email, string? Address, string? Schedule, string? Facebook, string? Instagram);
record EmployeeInput(int? Id, string Identity, string Name, string LastName, string Phone, string Email, string Job, DateOnly? StartDate, bool Active);
record UserInput(int? Id, string Username, string Role, int? ClientId, int? EmployeeId, bool Active, string? Password);
record InventoryInput(int? Id, string Name, string? Description, decimal Quantity, string Unit, decimal MinQuantity, bool Active);
record PromotionInput(int? Id, int? ServiceId, string Name, string? Description, decimal Percent, DateOnly? Start, DateOnly? End, bool Active);
record CollectionInput(int? Id, int? OrderId, string Address, DateTime? Scheduled, string? Status, string? Notes);
record PaymentInput(int? Id, int? OrderId, decimal Amount, string Method, string? Status, string? Reference);
record StatusInput(bool Active);
record CollectionStatusInput(string Status);