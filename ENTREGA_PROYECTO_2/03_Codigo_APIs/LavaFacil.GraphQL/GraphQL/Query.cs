using LavaFacil.GraphQL.Data;
using LavaFacil.GraphQL.Security;

namespace LavaFacil.GraphQL.GraphQL;

public sealed class Query
{
    public string Estado() => "LavaFacil GraphQL disponible";
    public Task<List<Servicio>> Servicios(DbGateway db) => All<Servicio>(db, "ConsultarServicios", true);
    public Task<List<Promocion>> Promociones(DbGateway db) => All<Promocion>(db, "ConsultarPromociones", true);
    public Task<List<Cliente>> Clientes(DbGateway db, RequestIdentity auth) { auth.RequireStaff(); return All<Cliente>(db, "ConsultarClientes"); }
    public Task<List<Empleado>> Empleados(DbGateway db, RequestIdentity auth) { auth.RequireStaff(); return All<Empleado>(db, "ConsultarEmpleados"); }
    public Task<List<Usuario>> Usuarios(DbGateway db, RequestIdentity auth) { auth.RequireStaff(); return All<Usuario>(db, "ConsultarUsuarios"); }
    public Task<List<Pedido>> Pedidos(DbGateway db, RequestIdentity auth) { auth.RequireStaff(); return All<Pedido>(db, "ConsultarPedidos"); }
    public Task<List<DetallePedido>> DetallesPedido(DbGateway db, RequestIdentity auth) { auth.RequireStaff(); return All<DetallePedido>(db, "ConsultarDetallePedido"); }
    public Task<List<Pago>> Pagos(DbGateway db, RequestIdentity auth) { auth.RequireStaff(); return All<Pago>(db, "ConsultarPagos"); }
    public Task<List<Recoleccion>> Recolecciones(DbGateway db, RequestIdentity auth) { auth.RequireStaff(); return All<Recoleccion>(db, "ConsultarRecolecciones"); }
    public Task<List<Inventario>> Inventario(DbGateway db, RequestIdentity auth) { auth.RequireStaff(); return All<Inventario>(db, "ConsultarInventario"); }
    private static Task<List<T>> All<T>(DbGateway db, string sp, bool publicRead = false) where T : new() =>
        db.QueryAsync<T>(sp, new Dictionary<string, object?> { ["TipoConsulta"] = 1 }, publicRead: publicRead);
}
