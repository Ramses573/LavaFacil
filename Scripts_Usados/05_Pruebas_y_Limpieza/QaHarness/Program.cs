using Microsoft.Data.SqlClient;
using System.Security.Cryptography;
using System.Runtime.Versioning;
using System.Text;
using System.Text.Json;
using System.Net;
using System.Net.Http.Json;
[assembly:SupportedOSPlatform("windows")]
var root="C:/Users/jm076/Desktop/LavaFacil";
var manifestPath=Path.Combine(AppContext.BaseDirectory,"../../../manifest.json");
var tables=new Dictionary<string,string>{{"Usuarios","IdUsuario"},{"Clientes","IdCliente"},{"Empleados","IdEmpleado"},{"Servicios","IdServicio"},{"Pedidos","IdPedido"},{"DetallePedido","IdDetalle"},{"Pagos","IdPago"},{"Recolecciones","IdRecoleccion"},{"Promociones","IdPromocion"},{"Inventario","IdInventario"}};
var cs=Encoding.UTF8.GetString(ProtectedData.Unprotect(File.ReadAllBytes(Path.Combine(root,"LavaFacil.Web/Data/connection.dpapi")),null,DataProtectionScope.CurrentUser));
using var conn=new SqlConnection(cs);await conn.OpenAsync();
async Task<Dictionary<string,Snapshot>> SnapshotAll(){
  var output=new Dictionary<string,Snapshot>();
  foreach(var (table,key) in tables){
    using var cmd=new SqlCommand($"SELECT COUNT(*) FROM dbo.[{table}]; SELECT * FROM dbo.[{table}] ORDER BY [{key}] FOR JSON PATH, INCLUDE_NULL_VALUES",conn);
    using var reader=await cmd.ExecuteReaderAsync();await reader.ReadAsync();int count=reader.GetInt32(0);await reader.NextResultAsync();var json=new StringBuilder();while(await reader.ReadAsync())json.Append(reader.GetString(0));
    output[table]=new(count,Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(json.ToString()))));
  }return output;
}
async Task<int> Insert(string sql,SqlTransaction tx,params (string,object)[] ps){using var cmd=new SqlCommand(sql,conn,tx);foreach(var (n,v) in ps)cmd.Parameters.AddWithValue(n,v);return Convert.ToInt32(await cmd.ExecuteScalarAsync());}
if(args[0]=="seed"){
  if(File.Exists(manifestPath))throw new Exception("Ya hay un manifiesto. Limpia la prueba anterior antes de crear otra.");
  var m=new Manifest{Run="LFQA_"+Guid.NewGuid().ToString("N")[..10],Password="QA!"+Guid.NewGuid().ToString("N"),Baseline=await SnapshotAll()};
  await File.WriteAllTextAsync(manifestPath,JsonSerializer.Serialize(m));
  using var tx=conn.BeginTransaction();
  try{
    foreach(var role in new[]{"Administrador","Empleado"}){
      var tag=role=="Administrador"?"admin":"empleado";
      int eid=await Insert("INSERT dbo.Empleados(Cedula,Nombre,Apellidos,Telefono,Email,Cargo,FechaIngreso) OUTPUT INSERTED.IdEmpleado VALUES(@cedula,@nombre,'Prueba temporal','88888888',@email,@rol,CONVERT(date,GETDATE()))",tx,("@cedula",m.Run+tag[..1]),("@nombre","QA "+tag),("@email",tag+"@"+m.Run+".example.test"),("@rol",role));
      int uid=await Insert("INSERT dbo.Usuarios(NombreUsuario,Clave,TipoUsuario,IdEmpleado) OUTPUT INSERTED.IdUsuario VALUES(@usuario,@clave,@rol,@id)",tx,("@usuario",m.Run+"_"+tag),("@clave",m.Password),("@rol",role),("@id",eid));
      m.EmployeeIds.Add(eid);m.UserIds.Add(uid);
    }
    int cid=await Insert("INSERT dbo.Clientes(Cedula,Nombre,Apellidos,Telefono,Email) OUTPUT INSERTED.IdCliente VALUES(@cedula,'QA Cliente','Prueba temporal','88888888',@email)",tx,("@cedula",m.Run+"c"),("@email","cliente@"+m.Run+".example.test"));
    m.ClientIds.Add(cid);
    int cuid=await Insert("INSERT dbo.Usuarios(NombreUsuario,Clave,TipoUsuario,IdCliente) OUTPUT INSERTED.IdUsuario VALUES(@usuario,@clave,'Cliente',@id)",tx,("@usuario",m.Run+"_cliente"),("@clave",m.Password),("@id",cid));m.UserIds.Add(cuid);
    foreach(var active in new[]{true,false})m.ServiceIds.Add(await Insert("INSERT dbo.Servicios(NombreServicio,Descripcion,TipoCobro,PrecioBase,CantidadIncluida,Activo) OUTPUT INSERTED.IdServicio VALUES(@nombre,'Servicio temporal de prueba','Kilogramo',1500,1,@activo)",tx,("@nombre",m.Run+(active?" Lavado prueba":" Inactivo prueba")),("@activo",active)));
    await File.WriteAllTextAsync(manifestPath,JsonSerializer.Serialize(m));tx.Commit();
  }catch{tx.Rollback();throw;}
  Console.WriteLine(JsonSerializer.Serialize(new{m.Run,m.Password,m.UserIds,m.EmployeeIds,m.ClientIds,m.ServiceIds,Baseline=m.Baseline.ToDictionary(p=>p.Key,p=>p.Value.Count)}));
}else{
  var m=JsonSerializer.Deserialize<Manifest>(await File.ReadAllTextAsync(manifestPath))!;
  if(args[0]=="verify"){
    var results=new List<string>();
    void Check(bool ok,string label){if(!ok)throw new Exception("FAIL: "+label);Console.WriteLine("PASS: "+label);results.Add(label);}
    foreach(var tag in new[]{"admin","empleado","cliente"}){
      using var http=new HttpClient(new HttpClientHandler{CookieContainer=new CookieContainer()}){BaseAddress=new Uri("http://127.0.0.1:5088"),Timeout=TimeSpan.FromSeconds(20)};
      var bootstrap=(await http.GetFromJsonAsync<JsonElement>("/api/bootstrap"));
      var token=bootstrap.GetProperty("token").GetString()!;
      async Task<HttpResponseMessage> Post(string url,object body,string csrf){using var req=new HttpRequestMessage(HttpMethod.Post,url){Content=JsonContent.Create(body)};req.Headers.Add("X-CSRF-TOKEN",csrf);return await http.SendAsync(req);}
      var login=await Post("/api/login",new{username=m.Run+"_"+tag,password=m.Password},token);
      Check(login.StatusCode==HttpStatusCode.OK,"Login HTTP "+tag);
      bootstrap=await http.GetFromJsonAsync<JsonElement>("/api/bootstrap");token=bootstrap.GetProperty("token").GetString()!;
      Check((await http.GetAsync("/api/home")).StatusCode==HttpStatusCode.OK,"Resumen HTTP "+tag);
      var services=await http.GetFromJsonAsync<JsonElement>("/api/services");
      Check(services.GetProperty("rows").GetArrayLength()==1,"Servicio inactivo excluido HTTP "+tag);
      var clients=await http.GetAsync("/api/clients");
      Check(tag=="cliente"?!clients.IsSuccessStatusCode:clients.IsSuccessStatusCode,"Permiso de consulta de clientes HTTP "+tag);
      if(tag=="cliente"){
        var denied=await Post("/api/clients",new{identity=m.Run+"d",name="No autorizado",lastName="Prueba",phone="88888888",email="denied+"+m.Run+"@example.test",address=""},token);
        Check(!denied.IsSuccessStatusCode,"Cliente no puede registrar por API directa");
      }
      var profile=await http.GetFromJsonAsync<JsonElement>("/api/profile");var p=profile.GetProperty("rows")[0];
      Check(p.GetProperty("NombreUsuario").GetString()==m.Run+"_"+tag,"Perfil vinculado a la cuenta HTTP "+tag);
      var invalid=await Post("/api/profile",new{name=p.GetProperty("Nombre").GetString(),lastName=p.GetProperty("Apellidos").GetString(),phone="88888888",email="no-es-correo"},token);
      Check(invalid.StatusCode==HttpStatusCode.BadRequest,"API valida correo incorrecto "+tag);
      var missingCsrf=await http.PostAsJsonAsync("/api/profile",new{name="No cambiar",lastName="Sin token",phone="88888888",email="qa@example.test"});
      Check(missingCsrf.StatusCode==HttpStatusCode.BadRequest,"API rechaza escritura sin CSRF "+tag);
      Check((await Post("/api/logout",new{},token)).IsSuccessStatusCode,"Cierre de sesión HTTP "+tag);
      Check((await http.GetAsync("/api/profile")).StatusCode==HttpStatusCode.Unauthorized,"Sesión cerrada no accede al perfil "+tag);
    }
    using var persisted=new SqlCommand("SELECT CONVERT(bit,CASE WHEN EXISTS(SELECT 1 FROM dbo.Empleados WHERE IdEmpleado=@employee AND Nombre='QA Editado' AND Apellidos='Perfil actualizado' AND Telefono='86666666' AND Email=@email) THEN 1 ELSE 0 END), CONVERT(bit,CASE WHEN EXISTS(SELECT 1 FROM dbo.Clientes WHERE IdCliente=@client AND Nombre='QA Cliente editado') THEN 1 ELSE 0 END), CONVERT(bit,CASE WHEN EXISTS(SELECT 1 FROM dbo.Clientes WHERE Cedula=@cedula AND Nombre='QA Registrado' AND Apellidos='Recorrido completo' AND Telefono='87777777' AND Direccion='Dirección ficticia para la prueba temporal' AND Email=@registered) THEN 1 ELSE 0 END), (SELECT COUNT(*) FROM dbo.Clientes WHERE Cedula=@cedula)",conn);
    persisted.Parameters.AddWithValue("@employee",m.EmployeeIds[0]);persisted.Parameters.AddWithValue("@email","edited+"+m.Run+"@example.test");persisted.Parameters.AddWithValue("@client",m.ClientIds[0]);persisted.Parameters.AddWithValue("@cedula",m.Run+"r");persisted.Parameters.AddWithValue("@registered","registered+"+m.Run+"@example.test");
    using(var reader=await persisted.ExecuteReaderAsync()){await reader.ReadAsync();Check(reader.GetBoolean(0),"SQL confirma nombre, apellidos, teléfono y correo del perfil actualizado");Check(reader.GetBoolean(1),"SQL confirma edición del perfil propio de cliente");Check(reader.GetBoolean(2),"SQL confirma todos los datos del cliente registrado por la interfaz");Check(reader.GetInt32(3)==1,"SQL confirma que el intento duplicado no creó otra fila");}
    await File.WriteAllTextAsync(Path.Combine(AppContext.BaseDirectory,"../../../api-results.json"),JsonSerializer.Serialize(results));
  }else if(args[0]=="repair-fixture-emails"){
    foreach(var (table,tag) in new[]{("Empleados","admin"),("Empleados","empleado"),("Clientes","cliente")}){
      using var cmd=new SqlCommand($"UPDATE dbo.[{table}] SET Email=@new WHERE Email=@old AND [{tables[table]}] IN ({string.Join(',',table=="Empleados"?m.EmployeeIds:m.ClientIds)})",conn);
      cmd.Parameters.AddWithValue("@new",tag+"+"+m.Run+"@example.test");cmd.Parameters.AddWithValue("@old",tag+"@"+m.Run+".example.test");Console.WriteLine(table+" fixture email corrected: "+await cmd.ExecuteNonQueryAsync());
    }
  }else if(args[0]=="inspect"){
    foreach(var table in new[]{"Usuarios","Empleados","Clientes","Servicios"}){
      string condition=table switch{"Usuarios"=>"NombreUsuario LIKE @prefix","Servicios"=>"NombreServicio LIKE @prefix",_=>"Email IN (@admin,@edited,@employee,@client,@registered)"};
      using var cmd=new SqlCommand($"SELECT [{tables[table]}] FROM dbo.[{table}] WHERE {condition}",conn);cmd.Parameters.AddWithValue("@prefix",m.Run+"%");
      foreach(var tag in new[]{"admin","edited","employee","client","registered"})cmd.Parameters.AddWithValue("@"+tag,(tag switch{"employee"=>"empleado","client"=>"cliente",_=>tag})+"+"+m.Run+"@example.test");
      using var reader=await cmd.ExecuteReaderAsync();var ids=new List<int>();while(await reader.ReadAsync())ids.Add(reader.GetInt32(0));Console.WriteLine(table+" exact fixture IDs: "+string.Join(',',ids));
    }
  }else if(args[0]=="cleanup"){
    using var tx=conn.BeginTransaction();
    try{
      foreach(var table in new[]{"Usuarios","Clientes","Empleados","Servicios"}){
        string condition=table switch{
          "Usuarios"=>$"IdUsuario IN ({string.Join(',',m.UserIds)}) AND NombreUsuario IN (@uadmin,@uemployee,@uclient)",
          "Empleados"=>$"IdEmpleado IN ({string.Join(',',m.EmployeeIds)}) AND Email IN (@admin,@edited,@employee)",
          "Servicios"=>$"IdServicio IN ({string.Join(',',m.ServiceIds)}) AND NombreServicio IN (@sactive,@sinactive)",
          _=>"Email IN (@client,@registered) AND Cedula IN (@cclient,@cregistered)"
        };
        using var cmd=new SqlCommand($"DELETE FROM dbo.[{table}] WHERE {condition}",conn,tx);
        foreach(var (n,v) in new[]{("@uadmin",m.Run+"_admin"),("@uemployee",m.Run+"_empleado"),("@uclient",m.Run+"_cliente"),("@admin","admin+"+m.Run+"@example.test"),("@edited","edited+"+m.Run+"@example.test"),("@employee","empleado+"+m.Run+"@example.test"),("@client","cliente+"+m.Run+"@example.test"),("@registered","registered+"+m.Run+"@example.test"),("@cclient",m.Run+"c"),("@cregistered",m.Run+"r"),("@sactive",m.Run+" Lavado prueba"),("@sinactive",m.Run+" Inactivo prueba")})cmd.Parameters.AddWithValue(n,v);
        Console.WriteLine(table+" removed: "+await cmd.ExecuteNonQueryAsync());
      }
      tx.Commit();
    }catch{tx.Rollback();throw;}
    var after=await SnapshotAll();bool allSame=true;
    foreach(var table in tables.Keys){bool same=after[table]==m.Baseline[table];allSame&=same;Console.WriteLine($"{table}: before={m.Baseline[table].Count}, after={after[table].Count}, original contents unchanged={same}");}
    Console.WriteLine("ALL ORIGINAL DATA UNCHANGED: "+allSame);
    await File.WriteAllTextAsync(Path.Combine(AppContext.BaseDirectory,"../../../cleanup-result.json"),JsonSerializer.Serialize(new{allSame,After=after.ToDictionary(p=>p.Key,p=>p.Value.Count)}));
    if(!allSame)Environment.ExitCode=2;
  }else throw new Exception("Modo desconocido");
}
record Snapshot(int Count,string Hash);
class Manifest{public string Run{get;set;}="";public string Password{get;set;}="";public Dictionary<string,Snapshot> Baseline{get;set;}=new();public List<int>UserIds{get;set;}=new();public List<int>EmployeeIds{get;set;}=new();public List<int>ClientIds{get;set;}=new();public List<int>ServiceIds{get;set;}=new();}
