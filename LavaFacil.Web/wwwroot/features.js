'use strict';
const isAdmin = () => state.user?.role === 'Administrador';
const orderStates = ['Pendiente','Recibido','En proceso','Listo','Entregado','Cancelado'];
const avatarSymbols = {Burbuja:'◉',Gota:'💧',Camisa:'👕',Flor:'🌸'};
const dateText = value => value ? new Date(value).toLocaleString('es-CR') : '—';
const opts = (items, current='', first='') => (first ? `<option value="">${escapeHtml(first)}</option>` : '') + items.map(x=>`<option value="${escapeHtml(x)}" ${x===current?'selected':''}>${escapeHtml(x)}</option>`).join('');
function applyPreferences(p) {
  document.documentElement.dataset.theme = ['Oceano','Bosque','Violeta'].includes(p.Tema) ? p.Tema : 'Oceano';
  const avatar = avatarSymbols[p.Avatar] || (state.profile?.Nombre || state.user?.name || '').slice(0,2).toUpperCase();
  document.querySelectorAll('.avatar').forEach(el=>el.textContent=avatar);
}
async function showCatalog(version) {
  page('Servicios de lavandería',isAdmin()?'Administra el catálogo y consulta sus tarifas':'Elige los servicios para tu próximo pedido',
    isAdmin()?'<button id="new-service" class="button primary">+ Agregar servicio</button>':'<a href="#new-order" class="button primary">Solicitar servicios</a>',
    `<form id="catalog-filter" class="card filters"><label>Buscar servicio<input name="search" maxlength="100" placeholder="Nombre o descripción"></label>${isAdmin()?'<label class="check-label"><input type="checkbox" name="inactive"> Incluir inactivos</label>':''}<button type="submit" class="button light">Consultar</button></form><div id="service-editor"></div><div class="notice subtle">La tarifa base cubre la cantidad incluida. El excedente se cobra por cada unidad adicional. Los kilogramos admiten decimales.</div><section class="card table-card"><table><thead><tr><th>Servicio</th><th>Cobro</th><th>Tarifa base</th><th>Incluye</th><th>Adicional</th><th>Estado</th>${isAdmin()?'<th>Acciones</th>':''}</tr></thead><tbody id="catalog-body"></tbody></table></section><p class="footer-status"></p>`);
  let rows=[];
  function editor(row={}) {
    $('#service-editor').innerHTML=`<section class="card form-card editor"><h2>${row.IdServicio?'Editar servicio':'Nuevo servicio'}</h2><form id="service-form" class="form-grid"><label>Nombre<input name="name" required maxlength="100" value="${escapeHtml(row.NombreServicio)}"></label><label>Tipo de cobro<select name="chargeType">${opts(['Kilogramo','Unidad','Uniforme'],row.TipoCobro||'Unidad')}</select></label><label class="full">Descripción<textarea name="description" maxlength="250">${escapeHtml(row.Descripcion)}</textarea></label><label>Precio base (₡)<input type="number" name="basePrice" min="0" max="99999999.99" step="0.01" required value="${row.PrecioBase??0}"></label><label>Cantidad incluida<input type="number" name="includedQuantity" min="0.01" step="0.01" max="99999999.99" required value="${row.CantidadIncluida??1}"></label><label>Precio por cantidad adicional (₡)<input type="number" name="additionalPrice" min="0" max="99999999.99" step="0.01" required value="${row.PrecioAdicional??0}"></label><label>Disponibilidad<select name="active"><option value="true" ${row.Activo!==false?'selected':''}>Activo</option><option value="false" ${row.Activo===false?'selected':''}>Inactivo</option></select><small>Desactivar conserva los pedidos anteriores.</small></label><div class="form-error full" role="alert" hidden></div><div class="form-actions full"><button type="submit" class="button primary">Guardar servicio</button><button type="button" id="cancel-service" class="button light">Cancelar</button></div></form></section>`;
    $('#cancel-service').onclick=()=>$('#service-editor').replaceChildren();
    bindForm($('#service-form'),async v=>{
      const result=await request('catalog',{id:row.IdServicio||null,name:v.name,description:v.description,chargeType:v.chargeType,basePrice:Number(v.basePrice),includedQuantity:Number(v.includedQuantity),additionalPrice:Number(v.additionalPrice),active:v.active==='true'});
      if(version!==state.routeVersion)return;
      recordConnection(result);$('#service-editor').replaceChildren();notify('Servicio guardado correctamente');await refresh();
    });
    $('#service-form input').focus();
  }
  async function refresh() {
    const form=$('#catalog-filter'), button=$('button',form);button.disabled=true;
    try {
      const values=new FormData(form);const result=await request('catalog?'+new URLSearchParams({search:values.get('search')||'',inactive:String(values.has('inactive'))}));
      if(version!==state.routeVersion)return;recordConnection(result);rows=result.rows;$('#page-error').hidden=true;
      $('#catalog-body').innerHTML=rows.length?rows.map(r=>`<tr><td class="name-cell">${escapeHtml(r.NombreServicio)}<p class="subtle">${escapeHtml(r.Descripcion)}</p></td><td>${escapeHtml(r.TipoCobro)}</td><td class="price">${currency(r.PrecioBase)}</td><td>${r.CantidadIncluida}</td><td class="price">${currency(r.PrecioAdicional||0)}</td><td><span class="badge ${r.Activo?'':'inactive'}">${r.Activo?'Activo':'Inactivo'}</span></td>${isAdmin()?`<td><button class="button light small edit-service" data-id="${r.IdServicio}">Editar</button></td>`:''}</tr>`).join(''):'<tr><td colspan="7" class="table-empty">No hay servicios para esta consulta.</td></tr>';
      document.querySelectorAll('.edit-service').forEach(b=>b.onclick=()=>editor(rows.find(r=>r.IdServicio===Number(b.dataset.id))));
    }catch(e){if(version===state.routeVersion)displayError(e.message);}finally{button.disabled=false;}
  }
  $('#catalog-filter').onsubmit=e=>{e.preventDefault();refresh();};if(isAdmin())$('#new-service').onclick=()=>editor();await refresh();
}
async function showOrders(version) {
  page(isStaff()?'Consulta de pedidos':'Mis pedidos',isStaff()?'Busca por cliente, fecha, servicio y estado':'Consulta el avance y el detalle de tus solicitudes','<a href="#new-order" class="button primary">+ Nuevo pedido</a>',
    `<form id="order-filter" class="card filters"><label>${isStaff()?'Cliente, cédula o pedido':'Número de pedido'}<input name="search" maxlength="100" placeholder="Buscar"></label><label>Desde<input type="date" name="from"></label><label>Hasta<input type="date" name="to"></label><label>Estado<select name="status">${opts(orderStates,'','Todos')}</select></label><label>Servicio<select name="serviceId" id="filter-service"><option value="">Todos</option></select></label><button class="button primary" type="submit">Consultar</button><button class="button light" type="reset">Limpiar</button></form><p id="order-summary" class="order-list-note"></p><section class="card table-card"><table><thead><tr><th>Pedido</th><th>Cliente</th><th>Fecha</th><th>Estado</th><th>Total</th><th>Detalle</th></tr></thead><tbody id="orders-body"></tbody></table></section><div id="order-detail"></div><p class="footer-status"></p>`);
  try{const catalog=await request('catalog?inactive='+isAdmin());if(version!==state.routeVersion)return;$('#filter-service').insertAdjacentHTML('beforeend',catalog.rows.map(r=>`<option value="${r.IdServicio}">${escapeHtml(r.NombreServicio)}</option>`).join(''));}catch(e){if(version===state.routeVersion)displayError(e.message);}
  async function detail(id) {
    try{
      const result=await request('orders/'+id);if(version!==state.routeVersion)return;recordConnection(result);
      const r=result.rows[0];if(!r)throw new Error('Este pedido no tiene líneas para mostrar.');
      $('#order-detail').innerHTML=`<section class="card order-detail"><div class="detail-heading"><div><h2>Pedido #${r.IdPedido}</h2><p>${escapeHtml(r.Cliente)} · ${escapeHtml(r.Estado)}</p></div><button id="close-detail" class="button light small">Cerrar detalle</button></div><p>${escapeHtml(r.Observaciones||'Sin observaciones')}</p><table><thead><tr><th>Servicio</th><th>Cantidad</th><th>Base</th><th>Adicional</th><th>Subtotal</th></tr></thead><tbody>${result.rows.map(d=>`<tr><td>${escapeHtml(d.NombreServicio)}</td><td>${d.Cantidad} ${escapeHtml(d.TipoCobro)}</td><td>${currency(d.PrecioBase)}</td><td>${currency(d.MontoAdicional)}</td><td>${currency(d.Subtotal)}</td></tr>`).join('')}</tbody></table><p class="order-total">Total: ${currency(r.Total)}</p>${isStaff()?`<form id="status-form" class="form-grid"><label>Estado del pedido<select name="status">${opts(orderStates,r.Estado)}</select></label><div class="form-actions"><button class="button primary" type="submit">Guardar estado</button></div><div class="form-error full" role="alert" hidden></div></form>`:''}</section>`;
      $('#close-detail').onclick=()=>$('#order-detail').replaceChildren();$('#order-detail').scrollIntoView({behavior:'smooth',block:'start'});
      if(isStaff())bindForm($('#status-form'),async v=>{recordConnection(await request('orders/'+id+'/status',v));notify('Estado actualizado');await refresh();await detail(id);});
    }catch(e){if(version===state.routeVersion)displayError(e.message);}
  }
  async function refresh(){
    const f=$('#order-filter'),button=$('[type=submit]',f);button.disabled=true;
    try{
      const values=Object.fromEntries(new FormData(f));if(values.from&&values.to&&values.from>values.to)throw new Error('La fecha inicial no puede ser posterior a la final.');
      const query=new URLSearchParams(Object.entries(values).filter(([,v])=>v!==''));const result=await request('orders?'+query);
      if(version!==state.routeVersion)return;recordConnection(result);$('#page-error').hidden=true;
      $('#order-summary').textContent=`${result.rows.length} pedidos · Total de los resultados: ${currency(result.rows.reduce((sum,r)=>sum+Number(r.Total),0))}. Se muestran hasta 500 pedidos; usa los filtros para acotar.`;
      $('#orders-body').innerHTML=result.rows.length?result.rows.map(r=>`<tr><td>#${r.IdPedido}</td><td>${escapeHtml(r.Cliente)}</td><td>${escapeHtml(dateText(r.FechaPedido))}</td><td><span class="badge ${escapeHtml(r.Estado)}">${escapeHtml(r.Estado)}</span></td><td class="price">${currency(r.Total)}</td><td><button class="button light small view-order" data-id="${r.IdPedido}">Ver servicios</button></td></tr>`).join(''):'<tr><td colspan="6" class="table-empty">No hay pedidos que coincidan con los filtros.</td></tr>';
      document.querySelectorAll('.view-order').forEach(b=>b.onclick=()=>detail(Number(b.dataset.id)));
    }catch(e){if(version===state.routeVersion)displayError(e.message);}finally{button.disabled=false;}
  }
  $('#order-filter').onsubmit=e=>{e.preventDefault();refresh();};$('#order-filter').onreset=()=>{queueMicrotask(refresh);};await refresh();
}
async function showNewOrder(version){
  page('Nuevo pedido','Agrega uno o varios servicios en una sola solicitud','<a href="#orders" class="button light">Volver a pedidos</a>','<section class="card form-card" id="new-order-content">Cargando catálogo…</section>');
  try{
    const catalog=await request('catalog');let clients=[];
    if(isStaff()){clients=(await request('clients')).rows.filter(c=>c.Activo);}
    if(version!==state.routeVersion)return;recordConnection(catalog);
    if(!catalog.rows.length){$('#new-order-content').textContent='No hay servicios activos. Un administrador debe agregar o activar servicios.';return;}
    $('#new-order-content').innerHTML=`<form id="order-form">${isStaff()?`<label>Cliente<select name="clientId" required><option value="">Seleccionar cliente</option>${clients.map(c=>`<option value="${c.IdCliente}">${escapeHtml(c.Nombre+' '+c.Apellidos+' · '+c.Cedula)}</option>`).join('')}</select></label>`:'<p>El pedido se registrará a nombre de tu cuenta de cliente.</p>'}<div id="order-lines"></div><button type="button" class="button light section-gap" id="add-line">+ Agregar otro servicio</button><p class="subtle">Cada tarifa base cubre su cantidad incluida; se suma el precio adicional por el excedente. El total definitivo se calcula con las tarifas vigentes al guardar.</p><label class="section-gap">Observaciones<textarea name="notes" maxlength="300" placeholder="Indicaciones para la lavandería"></textarea></label><p class="order-total" id="order-total">Total estimado: ₡0</p><div class="form-error" role="alert" hidden></div><div class="form-actions"><button class="button primary" type="submit">Registrar pedido</button><a class="button light" href="#orders">Cancelar</a></div></form>`;
    function total(){
      let amount=0;document.querySelectorAll('.order-line').forEach(el=>{
        const s=catalog.rows.find(r=>r.IdServicio===Number($('select',el).value));const qty=Number($('input',el).value);
        $('input',el).step=s?.TipoCobro==='Kilogramo'?'0.01':'1';
        $('input',el).min=s?.TipoCobro==='Kilogramo'?'0.01':'1';
        const subtotal=s?s.PrecioBase+Math.max(0,qty-s.CantidadIncluida)*(s.PrecioAdicional||0):0;
        amount+=subtotal;$('.line-price',el).textContent=currency(subtotal);
      });$('#order-total').textContent='Total estimado: '+currency(amount);
    }
    function add(){
      if(document.querySelectorAll('.order-line').length>=30){notify('Máximo 30 servicios por pedido');return;}
      const el=document.createElement('div');el.className='order-line';el.innerHTML=`<label>Servicio<select required><option value="">Seleccionar servicio</option>${catalog.rows.map(s=>`<option value="${s.IdServicio}">${escapeHtml(s.NombreServicio)} · ${currency(s.PrecioBase)}</option>`).join('')}</select></label><label>Cantidad<input type="number" min="0.01" max="10000" step="0.01" value="1" required></label><p class="line-price">₡0</p><button class="button light small" type="button">Quitar</button>`;
      $('button',el).onclick=()=>{el.remove();total();};$('select',el).onchange=total;$('input',el).oninput=total;$('#order-lines').append(el);total();
    }
    $('#add-line').onclick=add;add();
    bindForm($('#order-form'),async v=>{
      const lines=Array.from(document.querySelectorAll('.order-line')).map(el=>({serviceId:Number($('select',el).value),quantity:Number($('input',el).value)}));
      if(!lines.length)throw new Error('Agrega al menos un servicio.');
      if(new Set(lines.map(l=>l.serviceId)).size!==lines.length)throw new Error('Un servicio está repetido. Déjalo en una sola línea y ajusta la cantidad.');
      const result=await request('orders',{clientId:isStaff()?Number(v.clientId):null,notes:v.notes,lines});
      recordConnection(result);notify(`Pedido #${result.rows[0].IdPedido} registrado · ${currency(result.rows[0].Total)}`);location.hash='orders';
    });
  }catch(e){if(version===state.routeVersion)displayError(e.message);}
}
async function showClientAccount(version){
  page('Cuenta de cliente','Habilita el acceso de un cliente a sus pedidos y perfil','<a href="#clients" class="button light">Volver a clientes</a>','<section id="account-form-content" class="card form-card">Cargando clientes…</section>');
  try{
    const result=await request('clients');if(version!==state.routeVersion)return;
    $('#account-form-content').innerHTML=`<form id="client-account-form" class="form-grid"><label class="full">Cliente<select name="clientId" required><option value="">Seleccionar</option>${result.rows.filter(c=>c.Activo).map(c=>`<option value="${c.IdCliente}">${escapeHtml(c.Nombre+' '+c.Apellidos+' · '+c.Cedula)}</option>`).join('')}</select></label><label>Nombre de usuario<input name="username" maxlength="50" required autocomplete="off"></label><label>Contraseña inicial<input name="password" type="password" minlength="10" maxlength="255" required autocomplete="new-password"></label><p class="subtle full">Esta cuenta tendrá únicamente el rol Cliente. Entrega las credenciales al cliente por un canal privado; podrá cambiar su contraseña desde su perfil.</p><div class="form-error full" role="alert" hidden></div><div class="form-actions full"><button class="button primary" type="submit">Crear cuenta de cliente</button></div></form>`;
    bindForm($('#client-account-form'),async v=>{await request('client-account',{...v,clientId:Number(v.clientId)});$('#client-account-form').reset();notify('Cuenta de cliente creada');});
  }catch(e){if(version===state.routeVersion)displayError(e.message);}
}
async function extendProfile(version){
  const result=await request('preferences');if(version!==state.routeVersion)return;
  state.preferences=result.rows[0];const p=state.preferences;applyPreferences(p);
  $('.profile-summary').insertAdjacentHTML('beforeend',`<p class="bio">${escapeHtml(p.Biografia)}</p>`);
  $('.page').insertAdjacentHTML('beforeend',`<section class="card form-card profile-extra"><h2>Personaliza tu perfil</h2><form id="preferences-form" class="form-grid"><label>Avatar<select name="avatar">${opts(['Iniciales','Burbuja','Gota','Camisa','Flor'],p.Avatar)}</select></label><label>Colores del aplicativo<select name="theme">${opts(['Oceano','Bosque','Violeta'],p.Tema)}</select></label><label class="full">Acerca de mí<textarea name="bio" maxlength="200">${escapeHtml(p.Biografia)}</textarea></label>${!isStaff()?`<label class="full">Dirección<textarea name="address" maxlength="250">${escapeHtml(p.Direccion)}</textarea></label>`:''}<div class="form-error full" role="alert" hidden></div><div class="form-actions full"><button class="button primary" type="submit">Guardar personalización</button></div></form></section><section class="card form-card profile-extra"><h2>Cambiar contraseña</h2><form id="password-form" class="form-grid"><label>Contraseña actual<input type="password" name="currentPassword" required maxlength="255" autocomplete="current-password"></label><label>Nueva contraseña<input type="password" name="newPassword" required minlength="10" maxlength="255" autocomplete="new-password"></label><label>Confirmar nueva contraseña<input type="password" name="confirmPassword" required minlength="10" maxlength="255" autocomplete="new-password"></label><p class="subtle">Al menos 10 caracteres. Al guardar, tendrás que iniciar sesión nuevamente en este navegador.</p><div class="form-error full" role="alert" hidden></div><div class="form-actions full"><button class="button primary" type="submit">Cambiar contraseña</button></div></form></section>`);
  bindForm($('#preferences-form'),async v=>{const saved=await request('preferences',v);if(version!==state.routeVersion)return;state.preferences=saved.rows[0];applyPreferences(state.preferences);$('.bio').textContent=state.preferences.Biografia;notify('Personalización guardada');});
  bindForm($('#password-form'),async v=>{
    if(v.newPassword!==v.confirmPassword)throw new Error('Las contraseñas nuevas no coinciden.');
    await request('password',{currentPassword:v.currentPassword,newPassword:v.newPassword});state.user=null;state.profile=null;state.preferences=null;document.documentElement.removeAttribute('data-theme');await refreshToken();location.hash='login';notify('Contraseña actualizada. Inicia sesión nuevamente.');
  });
}
// Añadir la acción al listado existente sin duplicar su lógica de consulta.
const originalShowClients=showClients;
showClients=async function(version){await originalShowClients(version);if(version===state.routeVersion&&isAdmin()&&state.featuresReady)$('.page-heading').insertAdjacentHTML('beforeend','<a href="#client-account" class="button light">Crear cuenta de cliente</a>');};
