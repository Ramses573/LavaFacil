using LavaFacil.GraphQL.Data;
using LavaFacil.GraphQL.Security;

namespace LavaFacil.GraphQL.GraphQL;

public sealed class Mutation
{
    public async Task<LoginPayload> Login(string usuario, string clave, DbGateway db, TokenService tokens)
    {
        var rows = await db.QueryAsync<LoginRow>("usp_ValidarLogin", P(("NombreUsuario", usuario), ("Clave", clave)), login: true);
        var row = rows.FirstOrDefault();
        if (row is null || !row.LoginValido || row.IdUsuario is null || row.NombreUsuario is null || row.TipoUsuario is null)
            return new(false, "Usuario o contraseña incorrectos.", null, null, null, null);
        var token = tokens.Create(new(row.IdUsuario.Value, row.NombreUsuario, row.TipoUsuario));
        return new(true, "Inicio de sesión correcto.", token, row.IdUsuario, row.NombreUsuario, row.TipoUsuario);
    }

    public Task<OperationResult> InsertarCliente(string cedula,string nombre,string apellidos,string telefono,string email,string? direccion,DbGateway db,RequestIdentity a) => Run("InsertarCliente",P(("Cedula",cedula),("Nombre",nombre),("Apellidos",apellidos),("Telefono",telefono),("Email",email),("Direccion",direccion)),db,a);
    public Task<OperationResult> ActualizarCliente(int idCliente,string cedula,string nombre,string apellidos,string telefono,string email,string? direccion,DbGateway db,RequestIdentity a) => Run("ActualizarCliente",P(("IdCliente",idCliente),("Cedula",cedula),("Nombre",nombre),("Apellidos",apellidos),("Telefono",telefono),("Email",email),("Direccion",direccion)),db,a);
    public Task<OperationResult> EliminarCliente(int idCliente,DbGateway db,RequestIdentity a) => Delete("EliminarCliente","IdCliente",idCliente,db,a);
    public Task<OperationResult> InsertarEmpleado(string cedula,string nombre,string apellidos,string telefono,string email,string cargo,DateTime fechaIngreso,DbGateway db,RequestIdentity a) => Run("InsertarEmpleado",P(("Cedula",cedula),("Nombre",nombre),("Apellidos",apellidos),("Telefono",telefono),("Email",email),("Cargo",cargo),("FechaIngreso",fechaIngreso)),db,a);
    public Task<OperationResult> ActualizarEmpleado(int idEmpleado,string cedula,string nombre,string apellidos,string telefono,string email,string cargo,DateTime fechaIngreso,DbGateway db,RequestIdentity a) => Run("ActualizarEmpleado",P(("IdEmpleado",idEmpleado),("Cedula",cedula),("Nombre",nombre),("Apellidos",apellidos),("Telefono",telefono),("Email",email),("Cargo",cargo),("FechaIngreso",fechaIngreso)),db,a);
    public Task<OperationResult> EliminarEmpleado(int idEmpleado,DbGateway db,RequestIdentity a) => Delete("EliminarEmpleado","IdEmpleado",idEmpleado,db,a);
    public Task<OperationResult> InsertarUsuario(string nombreUsuario,string clave,string tipoUsuario,int? idCliente,int? idEmpleado,DbGateway db,RequestIdentity a) => Run("InsertarUsuario",P(("NombreUsuario",nombreUsuario),("Clave",clave),("TipoUsuario",tipoUsuario),("IdCliente",idCliente),("IdEmpleado",idEmpleado)),db,a);
    public Task<OperationResult> ActualizarUsuario(int idUsuario,string nombreUsuario,string clave,string tipoUsuario,int? idCliente,int? idEmpleado,DbGateway db,RequestIdentity a) => Run("ActualizarUsuario",P(("IdUsuario",idUsuario),("NombreUsuario",nombreUsuario),("Clave",clave),("TipoUsuario",tipoUsuario),("IdCliente",idCliente),("IdEmpleado",idEmpleado)),db,a);
    public Task<OperationResult> EliminarUsuario(int idUsuario,DbGateway db,RequestIdentity a) => Delete("EliminarUsuario","IdUsuario",idUsuario,db,a);
    public Task<OperationResult> InsertarServicio(string nombreServicio,string? descripcion,string tipoCobro,decimal precioBase,decimal cantidadIncluida,decimal precioAdicional,DbGateway db,RequestIdentity a) => Run("InsertarServicio",P(("NombreServicio",nombreServicio),("Descripcion",descripcion),("TipoCobro",tipoCobro),("PrecioBase",precioBase),("CantidadIncluida",cantidadIncluida),("PrecioAdicional",precioAdicional)),db,a);
    public Task<OperationResult> ActualizarServicio(int idServicio,string nombreServicio,string? descripcion,string tipoCobro,decimal precioBase,decimal cantidadIncluida,decimal precioAdicional,DbGateway db,RequestIdentity a) => Run("ActualizarServicio",P(("IdServicio",idServicio),("NombreServicio",nombreServicio),("Descripcion",descripcion),("TipoCobro",tipoCobro),("PrecioBase",precioBase),("CantidadIncluida",cantidadIncluida),("PrecioAdicional",precioAdicional)),db,a);
    public Task<OperationResult> EliminarServicio(int idServicio,DbGateway db,RequestIdentity a) => Delete("EliminarServicio","IdServicio",idServicio,db,a);
    public Task<OperationResult> InsertarPedido(int idCliente,DateTime fechaEntregaEstimada,string estado,decimal total,string? observaciones,DbGateway db,RequestIdentity a) => Run("InsertarPedido",P(("IdCliente",idCliente),("FechaEntregaEstimada",fechaEntregaEstimada),("Estado",estado),("Total",total),("Observaciones",observaciones)),db,a);
    public Task<OperationResult> ActualizarPedido(int idPedido,int idCliente,DateTime fechaEntregaEstimada,string estado,decimal total,string? observaciones,DbGateway db,RequestIdentity a) => Run("ActualizarPedido",P(("IdPedido",idPedido),("IdCliente",idCliente),("FechaEntregaEstimada",fechaEntregaEstimada),("Estado",estado),("Total",total),("Observaciones",observaciones)),db,a);
    public Task<OperationResult> EliminarPedido(int idPedido,DbGateway db,RequestIdentity a) => Delete("EliminarPedido","IdPedido",idPedido,db,a);
    public Task<OperationResult> InsertarDetallePedido(int idPedido,int idServicio,decimal cantidad,decimal precioBase,decimal montoAdicional,decimal subtotal,DbGateway db,RequestIdentity a) => Run("InsertarDetallePedido",P(("IdPedido",idPedido),("IdServicio",idServicio),("Cantidad",cantidad),("PrecioBase",precioBase),("MontoAdicional",montoAdicional),("Subtotal",subtotal)),db,a);
    public Task<OperationResult> ActualizarDetallePedido(int idDetalle,int idPedido,int idServicio,decimal cantidad,decimal precioBase,decimal montoAdicional,decimal subtotal,DbGateway db,RequestIdentity a) => Run("ActualizarDetallePedido",P(("IdDetalle",idDetalle),("IdPedido",idPedido),("IdServicio",idServicio),("Cantidad",cantidad),("PrecioBase",precioBase),("MontoAdicional",montoAdicional),("Subtotal",subtotal)),db,a);
    public Task<OperationResult> EliminarDetallePedido(int idDetalle,DbGateway db,RequestIdentity a) => Delete("EliminarDetallePedido","IdDetalle",idDetalle,db,a);
    public Task<OperationResult> InsertarPago(int idPedido,decimal monto,string metodoPago,string estadoPago,string? referencia,DbGateway db,RequestIdentity a) => Run("InsertarPago",P(("IdPedido",idPedido),("Monto",monto),("MetodoPago",metodoPago),("EstadoPago",estadoPago),("Referencia",referencia)),db,a);
    public Task<OperationResult> ActualizarPago(int idPago,int idPedido,decimal monto,string metodoPago,string estadoPago,string? referencia,DbGateway db,RequestIdentity a) => Run("ActualizarPago",P(("IdPago",idPago),("IdPedido",idPedido),("Monto",monto),("MetodoPago",metodoPago),("EstadoPago",estadoPago),("Referencia",referencia)),db,a);
    public Task<OperationResult> EliminarPago(int idPago,DbGateway db,RequestIdentity a) => Delete("EliminarPago","IdPago",idPago,db,a);
    public Task<OperationResult> InsertarRecoleccion(int idPedido,string direccion,DateTime fechaProgramada,string estado,string? observaciones,DbGateway db,RequestIdentity a) => Run("InsertarRecoleccion",P(("IdPedido",idPedido),("Direccion",direccion),("FechaProgramada",fechaProgramada),("Estado",estado),("Observaciones",observaciones)),db,a);
    public Task<OperationResult> ActualizarRecoleccion(int idRecoleccion,int idPedido,string direccion,DateTime fechaProgramada,string estado,string? observaciones,DbGateway db,RequestIdentity a) => Run("ActualizarRecoleccion",P(("IdRecoleccion",idRecoleccion),("IdPedido",idPedido),("Direccion",direccion),("FechaProgramada",fechaProgramada),("Estado",estado),("Observaciones",observaciones)),db,a);
    public Task<OperationResult> EliminarRecoleccion(int idRecoleccion,DbGateway db,RequestIdentity a) => Delete("EliminarRecoleccion","IdRecoleccion",idRecoleccion,db,a);
    public Task<OperationResult> InsertarPromocion(int idServicio,string nombrePromocion,string? descripcion,decimal porcentajeDescuento,DateTime fechaInicio,DateTime fechaFin,DbGateway db,RequestIdentity a) => Run("InsertarPromocion",P(("IdServicio",idServicio),("NombrePromocion",nombrePromocion),("Descripcion",descripcion),("PorcentajeDescuento",porcentajeDescuento),("FechaInicio",fechaInicio),("FechaFin",fechaFin)),db,a);
    public Task<OperationResult> ActualizarPromocion(int idPromocion,int idServicio,string nombrePromocion,string? descripcion,decimal porcentajeDescuento,DateTime fechaInicio,DateTime fechaFin,DbGateway db,RequestIdentity a) => Run("ActualizarPromocion",P(("IdPromocion",idPromocion),("IdServicio",idServicio),("NombrePromocion",nombrePromocion),("Descripcion",descripcion),("PorcentajeDescuento",porcentajeDescuento),("FechaInicio",fechaInicio),("FechaFin",fechaFin)),db,a);
    public Task<OperationResult> EliminarPromocion(int idPromocion,DbGateway db,RequestIdentity a) => Delete("EliminarPromocion","IdPromocion",idPromocion,db,a);
    public Task<OperationResult> InsertarInventario(string nombreProducto,string? descripcion,decimal cantidad,string unidadMedida,decimal cantidadMinima,DbGateway db,RequestIdentity a) => Run("InsertarInventario",P(("NombreProducto",nombreProducto),("Descripcion",descripcion),("Cantidad",cantidad),("UnidadMedida",unidadMedida),("CantidadMinima",cantidadMinima)),db,a);
    public Task<OperationResult> ActualizarInventario(int idInventario,string nombreProducto,string? descripcion,decimal cantidad,string unidadMedida,decimal cantidadMinima,DbGateway db,RequestIdentity a) => Run("ActualizarInventario",P(("IdInventario",idInventario),("NombreProducto",nombreProducto),("Descripcion",descripcion),("Cantidad",cantidad),("UnidadMedida",unidadMedida),("CantidadMinima",cantidadMinima)),db,a);
    public Task<OperationResult> EliminarInventario(int idInventario,DbGateway db,RequestIdentity a) => Delete("EliminarInventario","IdInventario",idInventario,db,a);

    private static Dictionary<string,object?> P(params (string Key,object? Value)[] values) => values.ToDictionary(x=>x.Key,x=>x.Value);
    private static Task<OperationResult> Delete(string sp,string key,int id,DbGateway db,RequestIdentity auth) => Run(sp,P((key,id)),db,auth);
    private static async Task<OperationResult> Run(string sp,Dictionary<string,object?> parameters,DbGateway db,RequestIdentity auth)
    {
        auth.RequireStaff();
        try { await db.ExecuteAsync(sp,parameters); return new(true,$"{sp} ejecutado correctamente."); }
        catch (Exception ex) when (ex is not GraphQLException) { return new(false,ex.Message); }
    }
}
