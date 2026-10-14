'use strict';
const $ = (selector, root = document) => root.querySelector(selector);
const app = $('#app');
const state = { token: '', user: null, configured: false, needsAccount: false, connection: null, offline: false, clients: [], profile: null, change: '', routeVersion: 0 };
const escapeHtml = value => String(value ?? '').replace(/[&<>"']/g, ch => ({ '&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&#39;' })[ch]);
const currency = value => new Intl.NumberFormat('es-CR', { style:'currency', currency:'CRC', maximumFractionDigits:0 }).format(value);
const isStaff = () => ['Empleado', 'Administrador'].includes(state.user?.role);
function notify(message) { $('#toast').textContent = message; $('#toast').hidden = false; clearTimeout(notify.timer); notify.timer = setTimeout(() => $('#toast').hidden = true, 5500); }
async function request(path, body) {
  const response = await fetch('/api/' + path, { method: body === undefined ? 'GET' : 'POST', credentials:'same-origin', headers: body === undefined ? {} : { 'Content-Type':'application/json', 'X-CSRF-TOKEN':state.token }, body: body === undefined ? undefined : JSON.stringify(body) });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    if (response.status === 401 && path !== 'login') { state.user = null; location.hash = 'login'; }
    throw new Error(payload.error || 'No se pudo completar la operación.');
  }
  return payload;
}
function recordConnection(result) {
  if (!result.server) return;
  const previous = state.connection?.server;
  state.change = previous && previous !== result.server ? `Conexión restablecida. Esta operación fue atendida por ${result.server} (antes: ${previous}).` : '';
  state.connection = result;
  state.offline = false;
  updateStatus();
}
function statusCard() { return `<section class="card connection"><h2>Estado de conexión</h2><div class="connection-details"></div><button class="button light check-connection" type="button">Comprobar conexión</button></section>`; }
function updateStatus() {
  const result = state.connection;
  document.querySelectorAll('.connection-details').forEach(el => {
    el.innerHTML = `<p><span class="dot ${state.offline ? 'offline' : ''}"></span>${state.offline ? 'No disponible' : result ? 'Conectado' : 'Sin comprobar'}</p><p>${state.offline ? 'Último servidor confirmado' : 'Servidor conectado'}: <strong>${escapeHtml(result?.server || '—')}</strong></p><p>Base de datos: <strong>${escapeHtml(result?.databaseName || '—')}</strong></p><small>${result ? 'Última operación correcta: ' + escapeHtml(new Date(result.checkedAt).toLocaleString('es-CR')) : 'Pendiente de consultar SQL Server.'}</small>`;
  });
  document.querySelectorAll('.footer-status').forEach(el => { el.textContent = state.offline ? 'Conexión no disponible · los datos visibles corresponden a la última consulta correcta.' : result ? `Datos consultados en ${result.server} · ${result.databaseName}` : 'Conexión pendiente'; });
  const available = $('#available');
  if (available) { available.textContent = state.offline ? 'Sin conexión' : result ? 'Disponible' : 'Pendiente'; available.style.color = state.offline ? '#c07938' : ''; }
  const change = $('#connection-change');
  if (change) { change.textContent = state.change; change.hidden = !state.change; }
}
function displayError(message, container = $('#page-error')) { if (container) { container.textContent = message; container.hidden = false; } else notify(message); }
function failConnection(error) { state.offline = true; updateStatus(); displayError(error.message); }
function setHeader() {
  $('#header').hidden = !state.user;
  if (!state.user) return;
  $('#account-name').textContent = state.profile ? state.profile.Nombre : state.user.name;
  $('#account-role').textContent = state.user.role;
  $('#avatar').textContent = (state.profile?.Nombre || state.user.name).slice(0, 2).toUpperCase();
  $('#clients-nav').hidden = !isStaff();
  document.querySelectorAll('nav a').forEach(a => a.classList.toggle('active', a.dataset.route === location.hash.slice(1)));
}
function page(title, subtitle, action, content) {
  app.innerHTML = `<div class="page"><div class="page-heading"><div><h1>${title}</h1><p class="subtitle">${subtitle}</p></div>${action || ''}</div><div id="page-error" class="notice error" role="alert" hidden></div><div id="connection-change" class="notice" role="status" hidden></div>${content}</div>`;
  updateStatus();
  document.querySelectorAll('.check-connection').forEach(button => button.addEventListener('click', async () => {
    button.disabled = true;
    try { recordConnection(await request('home')); $('#page-error').hidden = true; notify('Conexión comprobada con ' + state.connection.server); }
    catch (error) { failConnection(error); } finally { button.disabled = false; }
  }));
}
function bindPassword() { document.querySelectorAll('.eye').forEach(button => button.addEventListener('click', () => {
  const input = button.previousElementSibling;
  const showing = input.type === 'password'; input.type = showing ? 'text' : 'password';
  button.setAttribute('aria-label', showing ? 'Ocultar contraseña' : 'Mostrar contraseña'); button.setAttribute('aria-pressed', String(showing));
})); }
function bindForm(form, handler) {
  form.addEventListener('submit', async event => {
    event.preventDefault(); const button = $('[type=submit]', form); const original = button.textContent;
    const errorBox = $('.form-error', form); errorBox.hidden = true; button.disabled = true; button.textContent = 'Procesando…';
    try { await handler(Object.fromEntries(new FormData(form))); }
    catch (error) { displayError(error.message, errorBox); }
    finally { button.disabled = false; button.textContent = original; }
  });
}
function showSetup() {
  app.replaceChildren($('#setup-template').content.cloneNode(true)); bindPassword();
  bindForm($('#setup-form'), async values => { await request('setup', values); state.configured = true; await refreshToken(); notify('Conexión configurada correctamente'); location.hash = 'login'; });
}
function showFirstAccount() {
  app.innerHTML = `<div class="setup-shell"><section class="card setup-card"><div class="brand auth-brand"><img src="/logo.svg" alt=""><span>Lava<span>Fácil</span></span></div><h1>Crea tu cuenta de administrador</h1><p class="muted">La base de datos está conectada y todavía no tiene cuentas. Estos datos serán los de tu perfil real.</p><form id="first-account-form" class="form-grid">${contactFields({}, true).replace('<label>Dirección (opcional)<input name="address" maxlength="250" placeholder="Dirección detallada"></label>', '')}<label>Nombre de usuario<input name="username" maxlength="50" autocomplete="username" placeholder="Ej: ramses" required></label><label>Contraseña de LavaFácil<span class="password-field"><input name="password" type="password" minlength="8" maxlength="255" autocomplete="new-password" required><button type="button" class="eye" aria-label="Mostrar contraseña" aria-pressed="false">◉</button></span><small>Al menos 8 caracteres. Es la clave para entrar a la app.</small></label><div class="form-error full" role="alert" hidden></div><div class="form-actions full"><button class="button primary" type="submit">Crear mi cuenta</button></div></form><p class="auth-foot">Esta pantalla solo está disponible mientras no exista ningún usuario.</p></section></div>`;
  bindPassword();
  bindForm($('#first-account-form'), async values => { await request('first-account', values); state.needsAccount = false; notify('Cuenta creada. Ahora inicia sesión con tu usuario y contraseña.'); showLogin(); });
}
function showLogin() {
  app.replaceChildren($('#login-template').content.cloneNode(true)); bindPassword();
  bindForm($('#login-form'), async values => {
    const result = await request('login', values); state.user = result.user; state.profile = null;
    recordConnection(result); await refreshToken(); location.hash = 'home';
  });
}
async function showHome(version) {
  page('Panel de inicio', 'Gestión de servicios de lavandería', '', `<div class="stats"><section class="card stat"><p class="stat-label">Servicios disponibles</p><div class="stat-line"><strong id="service-count" class="stat-value">—</strong><span class="stat-icon" aria-hidden="true">♧</span></div></section>${isStaff() ? '<section class="card stat"><p class="stat-label">Clientes registrados</p><div class="stat-line"><strong id="client-count" class="stat-value">—</strong><span class="stat-icon" aria-hidden="true">♙</span></div></section>' : '<section class="card stat"><p class="stat-label">Tu cuenta</p><div class="stat-line"><strong class="status-text">Cliente</strong><span class="stat-icon" aria-hidden="true">♙</span></div></section>'}<section class="card stat"><p class="stat-label">Conexión disponible</p><div class="stat-line"><strong id="available" class="status-text">Pendiente</strong><span class="stat-icon" aria-hidden="true">⌁</span></div></section></div><div class="home-bottom"><section class="card actions-card"><a href="#services" class="button primary"><span class="action-icon" aria-hidden="true">⌕</span> Consultar servicios</a><a href="${isStaff() ? '#register' : '#profile'}" class="button mint"><span class="action-icon" aria-hidden="true">♙</span> ${isStaff() ? 'Registrar cliente' : 'Mi perfil'}</a></section>${statusCard()}</div>`);
  try {
    const result = await request('home'); if (version !== state.routeVersion) return;
    recordConnection(result); $('#service-count').textContent = result.rows[0].ServiciosActivos;
    if (isStaff()) $('#client-count').textContent = result.rows[0].ClientesActivos;
    if (!state.profile) { const profile = await request('profile'); if (version !== state.routeVersion) return; recordConnection(profile); state.profile = profile.rows[0]; setHeader(); }
  } catch (error) { if (version === state.routeVersion) failConnection(error); }
}
async function showServices(version) {
  page('Servicios de lavandería', 'Consulta nuestros servicios y tarifas', '<button class="button primary" id="refresh-services">↻ Actualizar</button>', `<div class="services-layout"><section class="card table-card"><table><thead><tr><th>Servicio</th><th>Descripción</th><th>Tipo de cobro</th><th>Precio base</th><th>Cantidad incluida</th><th>Estado</th></tr></thead><tbody id="services-body"><tr><td colspan="6" class="table-empty">Consultando servicios…</td></tr></tbody></table></section>${statusCard()}</div><p class="footer-status"></p>`);
  async function refresh() {
    const button = $('#refresh-services'); button.disabled = true;
    try {
      const result = await request('services'); if (version !== state.routeVersion) return;
      recordConnection(result); $('#page-error').hidden = true;
      $('#services-body').innerHTML = result.rows.length ? result.rows.map(row => `<tr><td class="name-cell">${escapeHtml(row.NombreServicio)}</td><td>${escapeHtml(row.Descripcion || '—')}</td><td>${escapeHtml(({Kilogramo:'Por kilo', Uniforme:'Por uniforme', Unidad:'Por unidad'})[row.TipoCobro] || row.TipoCobro)}</td><td class="price">${currency(row.PrecioBase)}</td><td>${escapeHtml(row.CantidadIncluida)} ${row.TipoCobro === 'Kilogramo' ? 'kg' : 'unidad(es)'}</td><td><span class="badge">Activo</span></td></tr>`).join('') : '<tr><td colspan="6" class="table-empty">Aún no hay servicios activos registrados en la base de datos.</td></tr>';
    } catch (error) { if (version === state.routeVersion) { failConnection(error); if ($('#services-body').textContent.includes('Consultando')) $('#services-body').innerHTML = '<tr><td colspan="6" class="table-empty">No se pudo cargar la información. Usa Actualizar para volver a consultar.</td></tr>'; } }
    finally { if (version === state.routeVersion) button.disabled = false; }
  }
  $('#refresh-services').addEventListener('click', refresh); await refresh();
}
function contactFields(values = {}, client = false) {
  const field = (label, name, dbName, max, type = 'text', placeholder = '') => `<label>${label}<input name="${name}" type="${type}" maxlength="${max}" value="${escapeHtml(values[dbName])}" placeholder="${placeholder}" required ${type === 'email' ? 'autocomplete="email"' : ''}></label>`;
  return (client ? field('Cédula', 'identity', 'Cedula', 20, 'text', 'Ej: 1-1234-5678') : '') + field('Nombre', 'name', 'Nombre', 50, 'text', 'Ingrese el nombre') + field('Apellidos', 'lastName', 'Apellidos', 100, 'text', 'Ingrese los apellidos') + field('Teléfono', 'phone', 'Telefono', 20, 'tel', 'Ej: 8888-8888') + field('Correo electrónico', 'email', 'Email', 150, 'email', 'ejemplo@correo.com') + (client ? '<label>Dirección (opcional)<input name="address" maxlength="250" placeholder="Dirección detallada"></label>' : '');
}
function showRegister() {
  page('Registrar cliente', 'Completa los datos del nuevo cliente', '', `<section class="card form-card"><form id="client-form" class="form-grid">${contactFields({}, true)}<div class="form-error full" role="alert" hidden></div><div class="form-actions full"><button class="button primary" type="submit">✓ Guardar cliente</button><a href="#clients" class="button light">Cancelar</a></div></form></section><p class="footer-status"></p>`);
  bindForm($('#client-form'), async values => { const result = await request('clients', values); recordConnection(result); notify('Cliente registrado correctamente · ID ' + result.rows[0].IdCliente); location.hash = 'clients'; });
}
async function showClients(version) {
  page('Clientes', 'Consulta y registra los clientes de LavaFácil', '<a href="#register" class="button primary">+ Registrar cliente</a>', `<div class="list-toolbar"><input id="client-search" class="search" type="search" placeholder="Buscar por nombre, cédula o correo" aria-label="Buscar clientes"><div><button class="button light small" id="refresh-clients">↻ Actualizar</button></div></div><section class="card table-card"><table><thead><tr><th>Cliente</th><th>Cédula</th><th>Teléfono</th><th>Correo electrónico</th><th>Estado</th></tr></thead><tbody id="clients-body"><tr><td colspan="5" class="table-empty">Consultando clientes…</td></tr></tbody></table></section><p class="footer-status"></p>`);
  function draw() {
    const term = $('#client-search').value.trim().toLocaleLowerCase('es');
    const rows = state.clients.filter(row => `${row.Nombre} ${row.Apellidos} ${row.Cedula} ${row.Email}`.toLocaleLowerCase('es').includes(term));
    $('#clients-body').innerHTML = rows.length ? rows.map(row => `<tr><td class="name-cell">${escapeHtml(row.Nombre)} ${escapeHtml(row.Apellidos)}</td><td>${escapeHtml(row.Cedula)}</td><td>${escapeHtml(row.Telefono)}</td><td>${escapeHtml(row.Email)}</td><td><span class="badge ${row.Activo ? '' : 'inactive'}">${row.Activo ? 'Activo' : 'Inactivo'}</span></td></tr>`).join('') : '<tr><td colspan="5" class="table-empty">No hay clientes que mostrar.</td></tr>';
  }
  async function refresh() {
    const button = $('#refresh-clients'); button.disabled = true;
    try { const result = await request('clients'); if (version !== state.routeVersion) return; state.clients = result.rows; recordConnection(result); $('#page-error').hidden = true; draw(); }
    catch (error) { if (version === state.routeVersion) { failConnection(error); $('#clients-body').innerHTML = '<tr><td colspan="5" class="table-empty">No se pudo consultar. Vuelve a intentar con Actualizar.</td></tr>'; } }
    finally { if (version === state.routeVersion) button.disabled = false; }
  }
  $('#client-search').addEventListener('input', draw); $('#refresh-clients').addEventListener('click', refresh); await refresh();
}
async function showProfile(version) {
  page('Mi perfil', 'Tu información, vinculada a tu cuenta real', '', '<section class="card form-card" id="profile-content">Consultando tu perfil…</section>');
  try {
    const result = await request('profile'); if (version !== state.routeVersion) return;
    recordConnection(result); state.profile = result.rows[0]; const p = state.profile; setHeader();
    $('#profile-content').outerHTML = `<div class="profile-layout"><section class="card profile-summary"><span class="avatar">${escapeHtml(p.Nombre.slice(0, 2).toUpperCase())}</span><h2>${escapeHtml(p.Nombre)} ${escapeHtml(p.Apellidos)}</h2><span class="badge">${escapeHtml(p.TipoUsuario)}</span><p>Usuario: <strong>${escapeHtml(p.NombreUsuario)}</strong></p><p>Cédula: ${escapeHtml(p.Cedula)}</p><p class="muted">El rol y la cédula no se modifican desde esta pantalla.</p></section><section class="card form-card"><h2>Información personal</h2><form id="profile-form" class="form-grid">${contactFields(p)}<div class="form-error full" role="alert" hidden></div><div class="form-actions full"><button type="submit" class="button primary">Guardar cambios</button><a href="#home" class="button light">Volver</a></div></form></section></div><p class="footer-status"></p>`;
    updateStatus();
    bindForm($('#profile-form'), async values => { const updated = await request('profile', values); recordConnection(updated); state.profile = updated.rows[0]; setHeader(); notify('Tu perfil se actualizó correctamente'); await showProfile(++state.routeVersion); });
  } catch (error) { if (version === state.routeVersion) failConnection(error); }
}
async function route() {
  const version = ++state.routeVersion; const routeName = location.hash.slice(1) || (state.user ? 'home' : 'login');
  if (!state.configured) { state.user = null; setHeader(); showSetup(); return; }
  if (!state.user) { setHeader(); if(state.needsAccount) showFirstAccount(); else showLogin(); return; }
  setHeader();
  if ((routeName === 'clients' || routeName === 'register') && !isStaff()) { location.hash = 'home'; notify('Esta función está disponible para empleados y administradores.'); return; }
  switch (routeName) {
    case 'services': await showServices(version); break;
    case 'clients': await showClients(version); break;
    case 'register': showRegister(); break;
    case 'profile': await showProfile(version); break;
    default: await showHome(version);
  }
}
async function refreshToken() { const result = await request('bootstrap'); state.token = result.token; state.needsAccount = result.needsAccount; }
$('#logout').addEventListener('click', async () => {
  try { await request('logout', {}); state.user = null; state.profile = null; state.connection = null; state.change = ''; await refreshToken(); location.hash = 'login'; await route(); }
  catch (error) { notify(error.message); }
});
window.addEventListener('hashchange', route);
(async () => {
  try { const data = await request('bootstrap'); Object.assign(state, { token:data.token, user:data.user, configured:data.configured, needsAccount:data.needsAccount }); $('#loading').hidden = true; app.hidden = false; await route(); }
  catch (error) { $('#loading').textContent = 'No se pudo iniciar LavaFácil. ' + error.message; }
})();
