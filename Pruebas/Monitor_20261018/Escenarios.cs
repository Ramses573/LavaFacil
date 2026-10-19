var now=DateTimeOffset.UtcNow;
ServerHealth S(string name,bool up,string? role,string? sync,string? prior=null)=>new(name,up,name,role,sync,prior,prior is null?null:now,"");
int passed=0;
void Check(string name,string? active,ServerHealth[] servers,string expected){var text=MirrorMonitor.Describe(active,servers);if(!text.Contains(expected))throw new Exception(name+": "+text);Console.WriteLine("OK: "+name);passed++;}
Check("Ambos sincronizados","MADRENZO",[S("M",true,"PRINCIPAL","SYNCHRONIZED"),S("R",true,"MIRROR","SYNCHRONIZED")],"Ambos servidores");
Check("Roles intercambiados","Rachel",[S("M",true,"MIRROR","SYNCHRONIZED"),S("R",true,"PRINCIPAL","SYNCHRONIZED")],"Ambos servidores");
Check("Espejo no responde","MADRENZO",[S("M",true,"PRINCIPAL","DISCONNECTED"),S("R",false,null,null,"MIRROR")],"último espejo");
Check("Principal no responde",null,[S("M",false,null,null,"PRINCIPAL"),S("R",true,"MIRROR","DISCONNECTED")],"último principal");
Check("Ambos no responden",null,[S("M",false,null,null),S("R",false,null,null)],"no está confirmado");
Check("Falta compañero","MADRENZO",[S("M",true,"PRINCIPAL","SYNCHRONIZED")],"Falta configurar");
Check("Sin permisos para rol","MADRENZO",[S("M",true,null,null),S("R",true,null,null)],"metadatos");
Check("Sincronización pendiente","MADRENZO",[S("M",true,"PRINCIPAL","SYNCHRONIZING"),S("R",true,"MIRROR","SYNCHRONIZING")],"aún no");
Check("Replica suspendida","MADRENZO",[S("M",true,"PRINCIPAL","SUSPENDED"),S("R",true,"MIRROR","SUSPENDED")],"interrupción");
Check("Caída inicial sin rol previo","MADRENZO",[S("M",true,"PRINCIPAL","SYNCHRONIZED"),S("R",false,null,null)],"rol actual no se pudo confirmar");
Console.WriteLine($"{passed} escenarios correctos.");
sealed class Database {internal string? MonitoringConnection=>null;}
