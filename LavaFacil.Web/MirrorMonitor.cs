using Microsoft.Data.SqlClient;
using System.Data;

sealed record ServerHealth(string Endpoint, bool Reachable, string? Server, string? Role, string? Sync,
    string? LastRole, DateTimeOffset? LastConfirmedAt, string Detail);
sealed record MonitorReport(DateTimeOffset CheckedAt, bool ApplicationAvailable, string? ActiveServer,
    string? LastActiveServer, DateTimeOffset? LastActiveAt, string Message, ServerHealth[] Servers);

sealed class MirrorMonitor(Database db)
{
    private readonly SemaphoreSlim gate = new(1,1);
    private readonly Dictionary<string,(string Server,string Role,DateTimeOffset At)> last = new();
    private MonitorReport? cached;
    private string? lastActive;
    private DateTimeOffset? lastActiveAt;
    public async Task<MonitorReport> Check()
    {
        await gate.WaitAsync();
        try {
            if(cached is not null && DateTimeOffset.UtcNow-cached.CheckedAt<TimeSpan.FromSeconds(10)) return cached;
            var original=db.MonitoringConnection;
            if(string.IsNullOrEmpty(original)) return new(DateTimeOffset.UtcNow,false,null,lastActive,lastActiveAt,"Falta configurar la conexión del aplicativo.",[]);
            var settings=new SqlConnectionStringBuilder(original);
            var endpoints=new[]{settings.DataSource,settings.FailoverPartner}.Where(x=>!string.IsNullOrWhiteSpace(x)).Distinct(StringComparer.OrdinalIgnoreCase).ToArray();
            // Las sondas de cada instancia van a master SIN Failover Partner: no deben redirigirse.
            var checks=endpoints.Select(endpoint=>Probe(settings,endpoint)).ToArray();
            var activeTask=ProbeApplication(settings);
            var servers=await Task.WhenAll(checks);
            var active=await activeTask;
            var now=DateTimeOffset.UtcNow;
            if(active is not null){lastActive=active;lastActiveAt=now;}
            foreach(var s in servers) if(s.Role is not null && s.Server is not null) last[s.Endpoint]=(s.Server,s.Role,now);
            cached=new(now,active is not null,active,lastActive,lastActiveAt,Describe(active,servers),servers);
            return cached;
        } finally {gate.Release();}
    }
    internal static string Describe(string? active,ServerHealth[] servers)
    {
        if(active is null) {
            var failed=servers.FirstOrDefault(s=>!s.Reachable && s.LastRole=="PRINCIPAL");
            return failed is null ? "No se pudo abrir la base del aplicativo. El estado actual del principal no está confirmado; revisa red, SQL Server y permisos." :
                $"No se puede acceder a la base. No responde {failed.Server ?? failed.Endpoint}, último principal confirmado. No se confirmó ninguna operación de escritura.";
        }
        if(servers.Any(s=>!s.Reachable && s.LastRole=="MIRROR"))
            return "La base está disponible, pero el último espejo confirmado no responde desde esta portátil. Revisa la réplica; puedes continuar trabajando.";
        if(servers.Any(s=>s.Sync is "DISCONNECTED" or "SUSPENDED" or "PENDING_FAILOVER"))
            return "La base está disponible, pero Mirroring informa una interrupción. Revisa el estado de sincronización.";
        if(servers.Any(s=>!s.Reachable)) return "La base está disponible, pero una instancia no responde o rechaza la conexión. Su rol actual no se pudo confirmar.";
        if(servers.Length<2) return "La base está disponible. Falta configurar el servidor compañero para comprobar ambas instancias.";
        if(servers.Any(s=>s.Role is null)) return "La base está disponible, pero no se pudieron determinar todos los roles. Revisa la visibilidad de metadatos y la configuración de Mirroring.";
        if(servers.Any(s=>s.Sync!="SYNCHRONIZED")) return "La base está disponible. La réplica aún no está completamente sincronizada.";
        return "Ambos servidores responden y Mirroring está sincronizado.";
    }
    private async Task<ServerHealth> Probe(SqlConnectionStringBuilder original,string endpoint)
    {
        last.TryGetValue(endpoint,out var previous);
        var cs=new SqlConnectionStringBuilder(original.ConnectionString){DataSource=endpoint,InitialCatalog="master",FailoverPartner="",ConnectTimeout=3,ConnectRetryCount=0,Pooling=false};
        string? server=null;
        bool opened=false;
        using var deadline=new CancellationTokenSource(TimeSpan.FromSeconds(5));
        try {
            using var connection=new SqlConnection(cs.ConnectionString);
            await connection.OpenAsync(deadline.Token);opened=true;
            using var command=new SqlCommand("SELECT CONVERT(nvarchar(128),@@SERVERNAME),m.mirroring_role_desc,m.mirroring_state_desc FROM (VALUES(1)) a(n) LEFT JOIN sys.database_mirroring m ON m.database_id=DB_ID(@database)",connection){CommandTimeout=2};
            command.Parameters.Add("@database",SqlDbType.NVarChar,128).Value=original.InitialCatalog;
            using var r=await command.ExecuteReaderAsync(deadline.Token);await r.ReadAsync(deadline.Token);
            server=r.GetString(0);var role=r.IsDBNull(1)?null:r.GetString(1);var sync=r.IsDBNull(2)?null:r.GetString(2);
            return new(endpoint,true,server,role,sync,previous.Role,previous.Role is null?null:previous.At,
                role is null ? "SQL responde; rol no disponible (metadatos sin permisos o Mirroring no configurado)." : "Consulta directa de la instancia completada.");
        } catch(Exception ex) when(ex is SqlException or OperationCanceledException) {
            var detail=ex is SqlException sql && sql.Number==18456 ? "SQL rechazó el login; no confirma que el servidor esté apagado." :
                opened ? "SQL aceptó la conexión, pero no se pudieron consultar sus metadatos." : "Sin respuesta confirmada desde esta portátil. Puede ser red, Tailscale o SQL Server.";
            return new(endpoint,opened,server??previous.Server,null,null,previous.Role,previous.Role is null?null:previous.At,detail);
        }
    }
    private static async Task<string?> ProbeApplication(SqlConnectionStringBuilder settings)
    {
        var cs=new SqlConnectionStringBuilder(settings.ConnectionString){ConnectTimeout=4,ConnectRetryCount=0};
        using var deadline=new CancellationTokenSource(TimeSpan.FromSeconds(6));
        try {
            using var connection=new SqlConnection(cs.ConnectionString);await connection.OpenAsync(deadline.Token);
            using var cmd=new SqlCommand("SELECT CONVERT(nvarchar(128),@@SERVERNAME)",connection){CommandTimeout=2};
            return Convert.ToString(await cmd.ExecuteScalarAsync(deadline.Token));
        }catch(Exception ex) when(ex is SqlException or OperationCanceledException){return null;}
    }
}
