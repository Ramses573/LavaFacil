using LavaFacil.GraphQL.Data;
using LavaFacil.GraphQL.Security;

namespace LavaFacil.GraphQL.GraphQL;

[ExtendObjectType(typeof(Query))]
public sealed class RachelQueries
{
    public Task<Cliente?> ClientePorId(int idCliente, DbGateway db, RequestIdentity auth)
    { auth.RequireStaff(); return Find<Cliente>(db, "ConsultarClientes", "IdCliente", idCliente); }

    public Task<Servicio?> ServicioPorId(int idServicio, DbGateway db) =>
        Find<Servicio>(db, "ConsultarServicios", "IdServicio", idServicio, publicRead: true);

    public Task<Promocion?> PromocionPorId(int idPromocion, DbGateway db) =>
        Find<Promocion>(db, "ConsultarPromociones", "IdPromocion", idPromocion, publicRead: true);

    public Task<Pedido?> PedidoPorId(int idPedido, DbGateway db, RequestIdentity auth)
    { auth.RequireStaff(); return Find<Pedido>(db, "ConsultarPedidos", "IdPedido", idPedido); }

    public Task<Pago?> PagoPorId(int idPago, DbGateway db, RequestIdentity auth)
    { auth.RequireStaff(); return Find<Pago>(db, "ConsultarPagos", "IdPago", idPago); }

    private static async Task<T?> Find<T>(DbGateway db, string procedure, string key,
        int id, bool publicRead = false) where T : class, new()
    {
        if (id <= 0) throw new GraphQLException("El identificador debe ser positivo.");
        var rows = await db.QueryAsync<T>(procedure,
            new Dictionary<string, object?> { ["TipoConsulta"] = 2, [key] = id }, publicRead: publicRead);
        return rows.SingleOrDefault();
    }
}
