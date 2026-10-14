using Microsoft.Data.SqlClient;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using System.Data;

static class FinalDelivery {
    static readonly (string Table,string Key,string Query)[] Tables = {
        ("Clientes","IdCliente","ConsultarClientes"),("Empleados","IdEmpleado","ConsultarEmpleados"),
        ("Usuarios","IdUsuario","ConsultarUsuarios"),("Servicios","IdServicio","ConsultarServicios"),
        ("Pedidos","IdPedido","ConsultarPedidos"),("DetallePedido","IdDetalle","ConsultarDetallePedido"),
        ("Pagos","IdPago","ConsultarPagos"),("Recolecciones","IdRecoleccion","ConsultarRecolecciones"),
        ("Promociones","IdPromocion","ConsultarPromociones"),("Inventario","IdInventario","ConsultarInventario")
    };
    static async Task<object?> Scalar(SqlConnection c,string sql,SqlTransaction? tx=null) {
        using var cmd=new SqlCommand(sql,c,tx){CommandTimeout=30}; return await cmd.ExecuteScalarAsync();
    }
    static async Task Exec(SqlConnection c,string sql,SqlTransaction? tx=null) {
        using var cmd=new SqlCommand(sql,c,tx){CommandTimeout=30}; await cmd.ExecuteNonQueryAsync();
    }
    static async Task<string> Fingerprint(SqlConnection c,(string Table,string Key,string Query) table) {
        var names=new List<string>();
        using(var cmd=new SqlCommand($"SELECT name FROM sys.columns WHERE object_id=OBJECT_ID('dbo.{table.Table}') AND NOT (OBJECT_NAME(object_id)='Usuarios' AND name='Clave') ORDER BY column_id",c)) {
            using var r=await cmd.ExecuteReaderAsync(); while(await r.ReadAsync()) names.Add("["+r.GetString(0)+"]");
        }
        using var query=new SqlCommand($"SELECT {string.Join(',',names)} FROM dbo.[{table.Table}] ORDER BY [{table.Key}] FOR JSON PATH,INCLUDE_NULL_VALUES",c);
        using var reader=await query.ExecuteReaderAsync(); var text=new StringBuilder(); while(await reader.ReadAsync()) text.Append(reader.GetString(0));
        return Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(text.ToString())));
    }
    public static async Task Run(string root,string cs) {
        if(!string.Equals(Path.GetFullPath(root),"C:\\Users\\jm076\\Desktop\\LavaFacil",StringComparison.OrdinalIgnoreCase)) throw new Exception("Ruta no autorizada.");
        var rawPath=Path.Combine(Path.GetTempPath(),"LavaFacil_Final_SSMS_20261011.sql");
        var raw=await File.ReadAllTextAsync(rawPath);
        int tableCount=Regex.Matches(raw,@"(?im)^\s*CREATE\s+TABLE\s").Count;
        int procCount=Regex.Matches(raw,@"(?im)^\s*CREATE\s+(?:OR\s+ALTER\s+)?PROC(?:EDURE)?\s").Count;
        int triggerCount=Regex.Matches(raw,@"(?im)^\s*CREATE\s+(?:OR\s+ALTER\s+)?TRIGGER\s").Count;
        int inserts=Regex.Matches(raw,@"(?im)^\s*INSERT\s+\[dbo\]\.").Count;
        if(tableCount!=10 || procCount!=50 || triggerCount!=2 || inserts!=30)
            throw new Exception($"Exportación incompleta: tablas={tableCount}; SP={procCount}; triggers={triggerCount}; datos={inserts}.");
        using var source=new SqlConnection(cs); await source.OpenAsync();
        if(Convert.ToString(await Scalar(source,"SELECT @@SERVERNAME"))!="MADRENZO") throw new Exception("El servidor actual no es MADRENZO.");
        var protectedPasswords=new List<string>();
        using(var cmd=new SqlCommand("SELECT Clave FROM dbo.Usuarios",source)) {
            using var r=await cmd.ExecuteReaderAsync(); while(await r.ReadAsync()) protectedPasswords.Add(r.GetString(0));
        }
        var safe=raw;
        foreach(var key in protectedPasswords.Distinct()) {
            var literal="'"+key.Replace("'","''")+"'";
            if(!safe.Contains(literal,StringComparison.Ordinal)) throw new Exception("No se pudo localizar una clave en los datos exportados.");
            safe=safe.Replace(literal,"'REEMPLAZAR_CLAVE_"+Guid.NewGuid().ToString("N")+"'",StringComparison.Ordinal);
        }
        if(protectedPasswords.Any(p=>safe.Contains("'"+p.Replace("'","''")+"'",StringComparison.Ordinal))) throw new Exception("Quedó una clave real en el script compartible.");
        var expectedData=new Dictionary<string,string>();
        foreach(var table in Tables) expectedData[table.Table]=await Fingerprint(source,table);
        var tempDb="LavaFacil_Validacion_20261011_"+Guid.NewGuid().ToString("N")[..8];
        var localOptions=new SqlConnectionStringBuilder {DataSource=@".\SQLEXPRESS",InitialCatalog="master",IntegratedSecurity=true,Encrypt=true,TrustServerCertificate=true,ConnectTimeout=10,ApplicationName="LavaFacil-Validacion-Script"};
        using var localMaster=new SqlConnection(localOptions.ConnectionString); await localMaster.OpenAsync();
        await Exec(localMaster,$"CREATE DATABASE [{tempDb}]");
        Console.WriteLine("Base temporal de validación creada en la laptop: "+tempDb);
        var dataResults=new List<object>(); var moduleResults=new List<object>();
        try {
            localOptions.InitialCatalog=tempDb;
            using(var target=new SqlConnection(localOptions.ConnectionString)) {
                await target.OpenAsync();
                var replay=Regex.Replace(safe,@"(?im)^\s*USE\s+\[LavaFacil\]\s*;?\s*$",$"USE [{tempDb}]");
                int batchIndex=0;
                foreach(var batch in Regex.Split(replay,@"(?im)^\s*GO\s*$")) {
                    batchIndex++; if(string.IsNullOrWhiteSpace(batch)) continue;
                    try {await Exec(target,batch);} catch(SqlException ex) {throw new Exception($"Falló la reconstrucción en el lote {batchIndex}; SQL {ex.Number}. No se modificó MADRENZO.");}
                }
                foreach(var table in Tables) {
                    int count=Convert.ToInt32(await Scalar(target,$"SELECT COUNT(*) FROM dbo.[{table.Table}]"));
                    bool equal=await Fingerprint(target,table)==expectedData[table.Table];
                    if(count!=3 || !equal) throw new Exception("Los datos reconstruidos no coinciden: "+table.Table);
                    dataResults.Add(new{table.Table,Rows=count,DataMatchesSourceExceptPasswords=equal});
                    using var cmd=new SqlCommand("dbo."+table.Query,target){CommandType=CommandType.StoredProcedure};
                    cmd.Parameters.Add("@TipoConsulta",SqlDbType.Int).Value=1;
                    using var r=await cmd.ExecuteReaderAsync(); int rows=0; while(await r.ReadAsync()) rows++;
                    if(rows!=3) throw new Exception("Falló la consulta reconstruida "+table.Query);
                }
                foreach(var kind in new[]{"P","TR","PK","F","UQ","C","D"}) {
                    int live=Convert.ToInt32(await Scalar(source,$"SELECT COUNT(*) FROM sys.objects WHERE type='{kind}' AND is_ms_shipped=0"));
                    int copy=Convert.ToInt32(await Scalar(target,$"SELECT COUNT(*) FROM sys.objects WHERE type='{kind}' AND is_ms_shipped=0"));
                    if(live!=copy) throw new Exception($"Objetos de tipo {kind} diferentes: {live}/{copy}.");
                    moduleResults.Add(new{Type=kind,Source=live,Restored=copy});
                }
                using(var constraints=new SqlCommand("DBCC CHECKCONSTRAINTS WITH ALL_CONSTRAINTS",target)) {
                    using var r=await constraints.ExecuteReaderAsync();
                    do {if(r.FieldCount>0 && await r.ReadAsync()) throw new Exception("Restricciones inválidas tras reconstrucción.");} while(await r.NextResultAsync());
                }
                foreach(var code in new[]{50002,50001}) {
                    using var tx=target.BeginTransaction();
                    try {
                        int client=Convert.ToInt32(await Scalar(target,"SELECT MIN(IdCliente) FROM dbo.Clientes",tx));
                        int service=Convert.ToInt32(await Scalar(target,"SELECT MIN(IdServicio) FROM dbo.Servicios",tx));
                        int order=Convert.ToInt32(await Scalar(target,$"INSERT dbo.Pedidos(IdCliente) OUTPUT inserted.IdPedido VALUES({client})",tx));
                        int detail=Convert.ToInt32(await Scalar(target,$"INSERT dbo.DetallePedido(IdPedido,IdServicio,Cantidad,PrecioBase,MontoAdicional,Subtotal) VALUES({order},{service},1,111,0,111); SELECT CONVERT(INT,SCOPE_IDENTITY());",tx));
                        if(Convert.ToDecimal(await Scalar(target,$"SELECT Total FROM dbo.Pedidos WHERE IdPedido={order}",tx))!=111) throw new Exception("El trigger no recalculó el total.");
                        if(code==50001) await Exec(target,$"INSERT dbo.Pagos(IdPedido,Monto,MetodoPago,EstadoPago) VALUES({order},100,'Efectivo','Pagado')",tx);
                        try {
                            await Exec(target,code==50002?$"INSERT dbo.Pagos(IdPedido,Monto,MetodoPago,EstadoPago) VALUES({order},112,'Efectivo','Pagado')":$"UPDATE dbo.DetallePedido SET Subtotal=90 WHERE IdDetalle={detail}",tx);
                            throw new Exception("No se rechazó la operación inválida del trigger "+code);
                        } catch(SqlException ex) when(ex.Number==code) { Console.WriteLine("PASS trigger: error esperado "+code); }
                    } finally {try {tx.Rollback();} catch(InvalidOperationException) {}}
                }
            }
        } finally {
            SqlConnection.ClearAllPools();
            if(!Regex.IsMatch(tempDb,@"^LavaFacil_Validacion_20261011_[a-f0-9]{8}$")) throw new Exception("Nombre temporal inválido; no se eliminó.");
            await Exec(localMaster,$"DROP DATABASE [{tempDb}]");
            Console.WriteLine("Base temporal de validación eliminada. La base principal no se tocó durante la reconstrucción.");
        }
        var archiveFolder=Path.Combine(root,"LavaFacil.Web","Data","ExportacionesPrivadas"); Directory.CreateDirectory(archiveFolder);
        var archive=Path.Combine(archiveFolder,"LavaFacil_SSMS_20261011.dpapi");
        if(File.Exists(archive)) throw new Exception("Ya existe el archivo privado; no se sobrescribió.");
        await File.WriteAllBytesAsync(archive,ProtectedData.Protect(Encoding.UTF8.GetBytes(raw),null,DataProtectionScope.CurrentUser));
        var header="""
        -- LavaFacil: generado desde SSMS el 11/10/2026; esquema, datos, 50 SPs y 2 triggers.
        -- Copia PARA COMPARTIR: las claves de Usuarios fueron sustituidas solo en este archivo.
        -- Tu contraseña actual en MADRENZO NO se cambió.
        -- Para usar la cuenta en una reconstrucción, establecer su clave antes de iniciar sesión.
        -- Ejecutar en SSMS con Consulta > Modo SQLCMD. NO ejecutar sobre la base de trabajo existente.
        :ON ERROR EXIT
        USE [master]
        GO
        IF DB_ID(N'LavaFacil') IS NULL EXEC(N'CREATE DATABASE [LavaFacil]');
        GO
        USE [LavaFacil]
        GO
        IF EXISTS(SELECT 1 FROM sys.objects WHERE is_ms_shipped=0 AND type IN ('U','P','TR'))
            THROW 50000, 'La base ya contiene objetos. No se debe sobrescribir; usar una instancia de reconstruccion vacia.', 1;
        GO

        """;
        var final=header+Environment.NewLine+safe;
        var output=Path.Combine(root,"SQL","LavaFacil_Final.sql");
        if(File.Exists(output)) throw new Exception("Ya existe el script final; no se sobrescribió.");
        await File.WriteAllTextAsync(output,final,new UTF8Encoding(true));
        var report=new{CheckedAt=DateTimeOffset.Now,GeneratedBy="SSMS 22 / Generar scripts / esquema y datos / incluir triggers",Tables=tableCount,Procedures=procCount,Triggers=triggerCount,DataInsertStatements=inserts,Rows=dataResults,Objects=moduleResults,ReconstructionPassed=true,QueriesPassed=true,TriggersPassed=true,PrivatePasswordsExcluded=true,TemporaryDatabaseRemoved=true,FinalSqlSha256=Convert.ToHexString(SHA256.HashData(await File.ReadAllBytesAsync(output)))};
        await File.WriteAllTextAsync(Path.Combine(Path.GetTempPath(),"LavaFacil-Verificacion-ScriptFinal.json"),JsonSerializer.Serialize(report,new JsonSerializerOptions{WriteIndented=true}));
        // El original generado por SSMS se conserva íntegro, cifrado y local, no en el paquete compartible.
        if(Path.GetFullPath(rawPath)!=Path.Combine(Path.GetTempPath(),"LavaFacil_Final_SSMS_20261011.sql")) throw new Exception("Ruta temporal inesperada.");
        File.Delete(rawPath);
        Console.WriteLine($"PASS script final: {tableCount} tablas, {procCount} SPs, {triggerCount} triggers y {inserts} filas. Claves reales excluidas. Archivo: {output}");
    }
}
