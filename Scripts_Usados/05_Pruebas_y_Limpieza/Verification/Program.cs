using Microsoft.Data.SqlClient;
using System.Security.Cryptography;
using System.Runtime.Versioning;
using System.Text;
using System.Text.RegularExpressions;
using System.Data;
using System.Text.Json;
[assembly: SupportedOSPlatform("windows")]
var root = args[0];
var cs = Encoding.UTF8.GetString(ProtectedData.Unprotect(File.ReadAllBytes(Path.Combine(root,"LavaFacil.Web","Data","connection.dpapi")),null,DataProtectionScope.CurrentUser));
if(args[1]=="--finalize-ssms") { await FinalDelivery.Run(root,cs); return; }
if (args[1] == "--verify-queries") {
    using var db = new SqlConnection(cs);
    await db.OpenAsync();
    var cases = new (string Table,string Proc,string Key)[] {
        ("Clientes","ConsultarClientes","IdCliente"),("Empleados","ConsultarEmpleados","IdEmpleado"),
        ("Usuarios","ConsultarUsuarios","IdUsuario"),("Servicios","ConsultarServicios","IdServicio"),
        ("Pedidos","ConsultarPedidos","IdPedido"),("DetallePedido","ConsultarDetallePedido","IdDetalle"),
        ("Pagos","ConsultarPagos","IdPago"),("Recolecciones","ConsultarRecolecciones","IdRecoleccion"),
        ("Promociones","ConsultarPromociones","IdPromocion"),("Inventario","ConsultarInventario","IdInventario")
    };
    var checks = new List<object>();
    foreach (var item in cases) {
        using var countCommand = new SqlCommand($"SELECT COUNT(*) FROM dbo.[{item.Table}]; SELECT TOP(1) [{item.Key}] FROM dbo.[{item.Table}] ORDER BY [{item.Key}]; SELECT name FROM sys.columns WHERE object_id=OBJECT_ID('dbo.{item.Table}') ORDER BY column_id",db);
        int expected,id; var columns = new List<string>();
        using (var r=await countCommand.ExecuteReaderAsync()) {
            await r.ReadAsync(); expected=r.GetInt32(0);
            await r.NextResultAsync(); if(!await r.ReadAsync()) throw new Exception("Tabla sin datos: "+item.Table); id=r.GetInt32(0);
            await r.NextResultAsync(); while(await r.ReadAsync()) columns.Add(r.GetString(0));
        }
        if(expected<3) throw new Exception("Faltan tres registros en "+item.Table);
        foreach(var mode in new[]{1,2,3}) {
            using var command=new SqlCommand("dbo."+item.Proc,db){CommandType=CommandType.StoredProcedure};
            command.Parameters.Add("@TipoConsulta",SqlDbType.Int).Value=mode==1?1:2;
            if(mode!=1) command.Parameters.Add("@"+item.Key,SqlDbType.Int).Value=mode==2?id:int.MinValue;
            using var reader=await command.ExecuteReaderAsync();
            var actualColumns=Enumerable.Range(0,reader.FieldCount).Select(reader.GetName).ToArray();
            if(!actualColumns.SequenceEqual(columns)) throw new Exception("Columnas incorrectas en "+item.Proc);
            int rows=0; while(await reader.ReadAsync()) { rows++; if(mode==2 && Convert.ToInt32(reader[item.Key])!=id) throw new Exception("Filtro incorrecto."); }
            int wanted=mode==1?expected:mode==2?1:0;
            if(rows!=wanted) throw new Exception($"{item.Proc}: se esperaban {wanted} filas, hubo {rows}.");
            checks.Add(new {item.Table,item.Proc,Test=mode==1?"Tabla completa":mode==2?"Filtro por ID existente":"ID inexistente",Rows=rows,Passed=true});
            Console.WriteLine($"PASS {item.Proc}: "+(mode==1?$"tabla completa ({rows} filas)":mode==2?"filtro por ID":"ID inexistente"));
        }
    }
    using(var integrity=new SqlCommand("DBCC CHECKCONSTRAINTS WITH ALL_CONSTRAINTS",db)) {
        using var reader=await integrity.ExecuteReaderAsync();
        do {if(reader.FieldCount>0 && await reader.ReadAsync()) throw new Exception("Se encontró una restricción incumplida.");} while(await reader.NextResultAsync());
    }
    using(var totals=new SqlCommand("SELECT COUNT(*) FROM dbo.Pedidos p WHERE p.Total<>(SELECT COALESCE(SUM(d.Subtotal),0) FROM dbo.DetallePedido d WHERE d.IdPedido=p.IdPedido) OR p.Total<(SELECT COALESCE(SUM(pg.Monto),0) FROM dbo.Pagos pg WHERE pg.IdPedido=p.IdPedido AND pg.EstadoPago='Pagado')",db))
        if(Convert.ToInt32(await totals.ExecuteScalarAsync())!=0) throw new Exception("Totales o pagos inconsistentes.");
    using(var admin=new SqlCommand("SELECT COUNT(*) FROM dbo.Usuarios u JOIN dbo.Empleados e ON e.IdEmpleado=u.IdEmpleado WHERE u.NombreUsuario='ramses.aguilar' AND u.TipoUsuario='Administrador' AND u.Activo=1 AND e.Nombre='Jose Ramses' AND e.Apellidos='Aguilar'",db))
        if(Convert.ToInt32(await admin.ExecuteScalarAsync())!=1) throw new Exception("No se confirmó la cuenta administradora original.");
    using(var inactive=new SqlCommand("SELECT COUNT(*) FROM dbo.Usuarios WHERE NombreUsuario LIKE 'demo.entrega.%' AND Activo<>0",db))
        if(Convert.ToInt32(await inactive.ExecuteScalarAsync())!=0) throw new Exception("Una cuenta ficticia está activa.");
    var report=new{CheckedAt=DateTimeOffset.Now,Tests=checks,ConstraintsValid=true,TotalsValid=true,RealAdminPreserved=true,DemoAccountsInactive=true};
    await File.WriteAllTextAsync(Path.Combine(Path.GetTempPath(),"LavaFacil-Verificacion-Consultas.json"),JsonSerializer.Serialize(report,new JsonSerializerOptions{WriteIndented=true}));
    Console.WriteLine("PASS 30 pruebas de consultas; integridad, totales y cuenta original verificados.");
    return;
}
if (args[1] is "--configure-failover" or "--verify-failover") {
    if (!string.Equals(Path.GetFullPath(root), "C:\\Users\\jm076\\Desktop\\LavaFacil", StringComparison.OrdinalIgnoreCase))
        throw new Exception("Ruta de configuración no autorizada.");
    var options = new SqlConnectionStringBuilder(cs);
    if (options.DataSource != "100.98.252.109,1433" || options.InitialCatalog != "LavaFacil" || options.UserID != "ramses_proyecto")
        throw new Exception("La conexión actual no coincide con la esperada. No se modificó.");
    var oldPartner = options.FailoverPartner;
    if (args[1] == "--configure-failover") options.FailoverPartner = "100.117.134.120,56640";
    if (options.FailoverPartner != "100.117.134.120,56640") throw new Exception("Failover Partner no coincide.");
    using var check = new SqlConnection(options.ConnectionString);
    await check.OpenAsync();
    using var query = new SqlCommand("SELECT @@SERVERNAME, DB_NAME(), mirroring_role_desc, mirroring_state_desc FROM sys.database_mirroring WHERE database_id=DB_ID()", check);
    using var result = await query.ExecuteReaderAsync();
    if (!await result.ReadAsync() || result.GetString(0) != "MADRENZO" || result.GetString(2) != "PRINCIPAL" || result.GetString(3) != "SYNCHRONIZED")
        throw new Exception("No se confirmó MADRENZO como principal sincronizado. No se modificó.");
    Console.WriteLine($"Servidor conectado: {result.GetString(0)} | Base: {result.GetString(1)} | Rol: {result.GetString(2)} | Estado: {result.GetString(3)}");
    if (args[1] == "--configure-failover" && oldPartner != options.FailoverPartner) {
        var path = Path.Combine(root,"LavaFacil.Web","Data","connection.dpapi");
        var suffix = Guid.NewGuid().ToString("N");
        var pending = path + ".pending-" + suffix;
        var backup = path + ".before-failover-" + suffix;
        await File.WriteAllBytesAsync(pending, ProtectedData.Protect(Encoding.UTF8.GetBytes(options.ConnectionString), null, DataProtectionScope.CurrentUser));
        File.Replace(pending, path, backup);
        Console.WriteLine("Configuración actualizada. Respaldo anterior conservado cifrado en Data.");
    }
    Console.WriteLine($"Server={options.DataSource};Database={options.InitialCatalog};User ID={options.UserID};Failover Partner={options.FailoverPartner};Contraseña=[NO MOSTRADA]");
    return;
}
if (args.Length > 2) {
    if (args[2] != "100.117.134.120,56640") throw new Exception("Destino de verificación no autorizado.");
    var options = new SqlConnectionStringBuilder(cs) {
        DataSource = args[2], InitialCatalog = "master", FailoverPartner = "", ConnectTimeout = 10,
        ApplicationName = "LavaFacil-VerificarLoginEspejo"
    };
    cs = options.ConnectionString;
}
using var connection = new SqlConnection(cs);
await connection.OpenAsync();
var script = await File.ReadAllTextAsync(args[1]);
foreach(var batch in Regex.Split(script,@"^\s*GO\s*$",RegexOptions.Multiline|RegexOptions.IgnoreCase)) {
    if(string.IsNullOrWhiteSpace(batch)) continue;
    using var command = new SqlCommand(batch,connection){CommandTimeout=30};
    using var reader=await command.ExecuteReaderAsync();
    do {
        if(reader.FieldCount==0) continue;
        Console.WriteLine(string.Join(" | ",Enumerable.Range(0,reader.FieldCount).Select(reader.GetName)));
        while(await reader.ReadAsync()) Console.WriteLine(string.Join(" | ",Enumerable.Range(0,reader.FieldCount).Select(i=>reader.IsDBNull(i)?"NULL":Convert.ToString(reader.GetValue(i)))));
    } while(await reader.NextResultAsync());
}
