$ErrorActionPreference='Stop'
$dir=Split-Path -Parent $MyInvocation.MyCommand.Path
$line=Get-Content (Join-Path $dir 'fixture-result.txt') | Select-Object -Last 1
$p=$line -split '\|'; $tag=$p[1]; $adminUser=$p[7]; $clientUser=$p[8]; $pw=$p[9]; $pedido=[int]$p[5]
$extra=(Get-Content (Join-Path $dir 'fixture-extra-result.txt') | Select-Object -Last 1) -split '\|'; $invalid=[int]$extra[1]; $terminal=[int]$extra[2]; $cancelado=[int]$extra[3]; $noemail=[int]$extra[4]
$base='http://127.0.0.1:5088'; $checks=@();
function Req($session,$method,$path,$body=$null,$token=$null) {
  try { $headers=@{}; if($token){$headers['X-CSRF-TOKEN']=$token}; $r=Invoke-WebRequest -UseBasicParsing -WebSession $session -Method $method -Uri ($base+$path) -Headers $headers -ContentType 'application/json' -Body $(if($null -ne $body){$body|ConvertTo-Json -Compress}else{$null}); [pscustomobject]@{Status=[int]$r.StatusCode;Body=$r.Content} }
  catch { if($_.Exception.Response){$q=$_.Exception.Response;$rd=New-Object IO.StreamReader($q.GetResponseStream());[pscustomobject]@{Status=[int]$q.StatusCode;Body=$rd.ReadToEnd()}}else{throw} }
}
function C($n,$ok,$d){$script:checks+=[pscustomobject]@{prueba=$n;estado=if($ok){'PASS'}else{'FAIL'};detalle=$d}}
function Login($user) {
  $s=New-Object Microsoft.PowerShell.Commands.WebRequestSession; $b=Req $s GET '/api/bootstrap'; $token=($b.Body|ConvertFrom-Json).token; $r=Req $s POST '/api/login' @{username=$user;password=$pw} $token; $after=Req $s GET '/api/bootstrap'; return [pscustomobject]@{S=$s;Token=(($after.Body|ConvertFrom-Json).token);Login=$r}
}
$a=Login $adminUser; C 'login administrador' ($a.Login.Status -eq 200) $a.Login.Body
$trans=@('Recibido','Recibido','En proceso','Listo','Entregado'); $expected=@('Recibido','Recibido','En proceso','Listo','Entregado');
for($i=0;$i -lt $trans.Count;$i++){ $r=Req $a.S POST "/api/orders/$pedido/status" @{status=$trans[$i]} $a.Token; C "endpoint estado $($trans[$i])" ($r.Status -eq 200) "status=$($r.Status); body=$($r.Body)" }
$c=Login $clientUser; C 'login cliente' ($c.Login.Status -eq 200) $c.Login.Body
$r=Req $c.S POST "/api/orders/$pedido/status" @{status='Cancelado'} $c.Token; C 'cliente no puede cambiar estado' ($r.Status -eq 403) "status=$($r.Status); body=$($r.Body)"
$r=Req $a.S POST "/api/orders/999999/status" @{status='Recibido'} $a.Token; C 'pedido inexistente' ($r.Status -eq 404) "status=$($r.Status); body=$($r.Body)"
foreach($x in @(@{id=$invalid;state='Pendiente';name='Recibido a Pendiente'},@{id=$terminal;state='En proceso';name='Entregado a En proceso'},@{id=$cancelado;state='Recibido';name='Cancelado a Recibido'})) { $r=Req $a.S POST "/api/orders/$($x.id)/status" @{status=$x.state} $a.Token; C $x.name ($r.Status -eq 400) "status=$($r.Status); body=$($r.Body)" }
$r=Req $a.S POST "/api/orders/$noemail/status" @{status='Recibido'} $a.Token; C 'pedido sin email cambia sin cola' ($r.Status -eq 200) "status=$($r.Status); body=$($r.Body)"
Start-Sleep -Seconds 14
$q="SET NOCOUNT ON; SELECT p.IdPedido,p.Estado,(SELECT COUNT(*) FROM dbo.CorreoEnvios c WHERE c.IdPedido=p.IdPedido AND c.Tipo='PedidoEstado') AS Cola FROM dbo.Pedidos p WHERE p.IdPedido IN ($pedido,$invalid,$terminal,$cancelado,$noemail) FOR JSON PATH;"; sqlcmd -S MADRENZO -d LavaFacil -E -C -I -h -1 -W -Q $q | Set-Content (Join-Path $dir 'status-query.json'); $db=((Get-Content (Join-Path $dir 'status-query.json') | Where-Object {$_ -match '^\s*\['}) -join '')
$rows=$db|ConvertFrom-Json; $main=$rows|Where-Object{$_.IdPedido -eq $pedido}; $none=$rows|Where-Object{$_.IdPedido -eq $noemail}; C 'estado y cuatro colas' ($main.Estado -eq 'Entregado' -and $main.Cola -eq 4) $db; C 'sin email sin cola' ($none.Estado -eq 'Recibido' -and $none.Cola -eq 0) $db
$emls=@(Get-ChildItem (Join-Path $dir 'outbox') -Filter *.eml -ErrorAction SilentlyContinue); $all=($emls|ForEach-Object{Get-Content -Raw $_.FullName}) -join "`n"; C 'EML estado asunto/anterior/nuevo/total/detalle' ($all -match "Pedido #${pedido}: Recibido" -and $all -match 'Pendiente.*Recibido' -and $all -match 'En proceso' -and $all -match 'Listo.*Entregado' -and $all -match 'Total' -and $all -match 'Detalle') "eml=$($emls.Count)"; C 'HTML escapado' ($all -match '&lt;script&gt;alert\(1\)&lt;/script&gt;' -and $all -notmatch '<dd>Lavado <script>alert\(1\)</script>') "eml=$($emls.Count)"
$checks|ConvertTo-Json -Depth 5|Set-Content (Join-Path $dir 'endpoint-result.json'); $checks|Format-Table -AutoSize
if($checks|Where-Object estado -eq 'FAIL'){exit 1}
