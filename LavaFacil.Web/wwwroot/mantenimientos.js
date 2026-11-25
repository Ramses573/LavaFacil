'use strict';
/* Página pública (landing) y mantenimientos del proyecto final. */

async function showLanding() {
  state.landing = true;
  app.replaceChildren($('#landing-template').content.cloneNode(true));
  document.querySelectorAll('#header').forEach(h => h.hidden = true);
  const servicesBox = $('#landing-services');
  const about = $('#landing-about');
  const contact = $('#landing-contact');

  // La landing es pública: nunca revela el servidor ni el usuario SQL.
  const load = async () => {
    let empresa = null;
    try { empresa = (await fetch('/api/public/empresa').then(r => r.json())); } catch { empresa = null; }
    if (empresa && empresa.Nombre) {
      if (empresa.Eslogan) $('#landing-title').textContent = empresa.Eslogan;
      if (empresa.Descripcion) $('#landing-description').textContent = empresa.Descripcion;
      $('#landing-footer-name').textContent = empresa.Nombre;
      document.title = empresa.Nombre + ' · Gestión de lavandería';
    }
    const bloque = (titulo, valor) => valor ? `<div class="info-block"><h3>${escapeHtml(titulo)}</h3><p>${escapeHtml(valor)}</p></div>` : '';
    about.innerHTML = empresa
      ? bloque('Quiénes somos', empresa.Descripcion) + bloque('Horario de atención', empresa.Horario) + bloque('Dónde estamos', empresa.Direccion)
      : '<p class="muted">Información no disponible.</p>';
    contact.innerHTML = empresa
      ? bloque('Teléfono', empresa.Telefono) + bloque('Correo electrónico', empresa.Email) + bloque('Dirección', empresa.Direccion) +
        (empresa.Facebook ? bloque('Facebook', empresa.Facebook) : '') + (empresa.Instagram ? bloque('Instagram', empresa.Instagram) : '')
      : '<p class="muted">Información no disponible.</p>';
    if (!about.innerHTML.trim()) about.innerHTML = '<p class="muted">Información no disponible.</p>';
    if (!contact.innerHTML.trim()) contact.innerHTML = '<p class="muted">Información no disponible.</p>';

    try {
      const data = await fetch('/api/public/servicios').then(r => r.json());
      const rows = Array.isArray(data) ? data : (data.rows || []);
      servicesBox.innerHTML = rows.length ? rows.map(s => `
        <article class="service-card card">
          <h3>${escapeHtml(s.NombreServicio)}</h3>
          <p class="muted">${escapeHtml(s.Descripcion || '')}</p>
          <p class="price">${currency(s.PrecioBase)}</p>
          <small>Incluye ${escapeHtml(s.CantidadIncluida)} ${s.TipoCobro === 'Kilogramo' ? 'kg' : 'unidad(es)'} · adicional ${currency(s.PrecioAdicional || 0)}</small>
        </article>`).join('') : '<p class="muted">Todavía no hay servicios publicados.</p>';
    } catch {
      servicesBox.innerHTML = '<p class="muted">No se pudieron cargar los servicios.</p>';
    }
  };
  await load();

  document.querySelectorAll('[data-landing]').forEach(link => link.addEventListener('click', event => {
    event.preventDefault();
    const id = 'landing-' + link.dataset.landing;
    document.getElementById(id)?.scrollIntoView({ behavior: 'smooth', block: 'start' });
  }));
}

/* ---------------- Mantenimientos (empleados y administradores) ---------------- */

function adminShell(title, subtitle, action, body) {
  page(title, subtitle, action || '', body);
}

function tableShell(caption, headers, bodyId, extra = '') {
  return `<section class="card table-card"><table><thead><tr>${headers.map(h => `<th>${h}</th>`).join('')}</tr></thead><tbody id="${bodyId}"></tbody></table></section>${extra}`;
}

const badge = (activo, siTexto = 'Activo', noTexto = 'Inactivo') =>
  `<span class="badge ${activo ? '' : 'inactive'}">${activo ? siTexto : noTexto}</span>`;

function emptyRow(cols, message) {
  return `<tr><td colspan="${cols}" class="table-empty">${escapeHtml(message)}</td></tr>`;
}

function showAdminHub(version) {
  const cards = [
    ['employees', 'Empleados', 'Alta, edición y desactivación del personal'],
    ['users', 'Usuarios y roles', 'Cuentas de acceso, roles y contraseñas'],
    ['inventory', 'Inventario', 'Productos, existencias y mínimo'],
    ['promotions', 'Promociones', 'Descuentos por vigencia'],
    ['collections', 'Recolecciones', 'Programación de recolecciones'],
    ['payments', 'Pagos', 'Cobros y estados por pedido'],
    ['empresa', 'Empresa', 'Datos que ve el público en la página principal'],
    ['services', 'Servicios', 'Tarifas y borrado seguro']
  ];
  adminShell('Administración', 'Mantenimiento de las tablas del aplicativo',
    '',
    `<div class="admin-grid">${cards.map(([route, title, text]) => `
      <a class="card admin-card" href="#${route}"><h2>${title}</h2><p class="muted">${text}</p></a>`).join('')}</div>`);
}

async function showEmpresa(version) {
  adminShell('Datos de la empresa', 'Esta información se muestra en la página pública', '<a href="#admin" class="button light">Volver</a>',
    '<section class="card form-card"><form id="empresa-form" class="form-grid">Cargando…</form></section>');
  try {
    const result = await request('empresa');
    if (version !== state.routeVersion) return;
    const e = result.rows[0] || {};
    $('#empresa-form').innerHTML = `
      <label class="full">Nombre<input name="name" required maxlength="150" value="${escapeHtml(e.Nombre)}"></label>
      <label class="full">Eslogan<input name="slogan" maxlength="200" value="${escapeHtml(e.Eslogan)}"></label>
      <label class="full">Descripción<textarea name="description" maxlength="1000">${escapeHtml(e.Descripcion)}</textarea></label>
      <label>Teléfono<input name="phone" maxlength="20" value="${escapeHtml(e.Telefono)}"></label>
      <label>Correo<input name="email" type="email" maxlength="150" value="${escapeHtml(e.Email)}"></label>
      <label class="full">Dirección<input name="address" maxlength="250" value="${escapeHtml(e.Direccion)}"></label>
      <label class="full">Horario<input name="schedule" maxlength="200" value="${escapeHtml(e.Horario)}"></label>
      <label>Facebook<input name="facebook" maxlength="200" value="${escapeHtml(e.Facebook)}"></label>
      <label>Instagram<input name="instagram" maxlength="200" value="${escapeHtml(e.Instagram)}"></label>
      <div class="form-error full" role="alert" hidden></div>
      <div class="form-actions full"><button class="button primary" type="submit">Guardar información</button></div>`;
    bindForm($('#empresa-form'), async v => {
      await request('empresa', v);
      notify('Información de la empresa actualizada');
    });
  } catch (error) { if (version === state.routeVersion) displayError(error.message); }
}

/* Tabla genérica reutilizable: evita repetir el mismo andamiaje en cada mantenedor. */
async function crudPage(version, config) {
  adminShell(config.title, config.subtitle, config.action || '', `
    <form id="crud-filter" class="card filters">${config.search === false ? '' : `<label>${config.searchLabel || 'Buscar'}<input name="search" maxlength="100" placeholder="Buscar"></label>`}
      ${config.extraFilters || ''}<button type="submit" class="button light">Consultar</button></form>
    <div id="crud-editor"></div>
    ${tableShell(config.caption, config.headers, 'crud-body', '<p class="subtle">' + escapeHtml(config.hint || '') + '</p>')}`);

  const state2 = { rows: [], editing: null };

  function editor(row) {
    const editing = !!row;
    row = row || config.blank();
    $('#crud-editor').innerHTML = `<section class="card form-card editor"><h2>${editing ? 'Editar' : 'Nuevo'} ${escapeHtml(config.singular)}</h2>
      <form id="crud-form" class="form-grid">${config.fields(row)}
      <div class="form-error full" role="alert" hidden></div>
      <div class="form-actions full"><button type="submit" class="button primary">Guardar</button><button type="button" id="crud-cancel" class="button light">Cancelar</button></div></form></section>`;
    $('#crud-cancel').onclick = () => $('#crud-editor').replaceChildren();
    bindForm($('#crud-form'), async values => {
      const payload = config.payload(values, row);
      const result = await request(config.endpoint, payload);
      if (version !== state.routeVersion) return;
      recordConnection(result);
      $('#crud-editor').replaceChildren();
      notify(config.savedMessage || 'Registro guardado');
      await refresh();
    });
    if (config.afterRender) config.afterRender(row);
    $('#crud-form input, #crud-form select')?.focus();
    $('#crud-editor').scrollIntoView({ behavior: 'smooth', block: 'start' });
  }

  function draw() {
    $('#crud-body').innerHTML = state2.rows.length
      ? state2.rows.map((row, index) => `<tr>${config.cells(row).join('')}<td><div class="inline-actions">
          <button class="button light small crud-edit" data-idx="${index}">Editar</button>
          ${config.toggle ? `<button class="button light small crud-toggle" data-idx="${index}">${config.toggle.label(row)}</button>` : ''}
          ${config.delete ? `<button class="button danger small crud-delete" data-idx="${index}">Eliminar</button>` : ''}
          </div></td></tr>`).join('')
      : emptyRow(config.headers.length + 1, 'No hay registros para esta consulta.');
    document.querySelectorAll('.crud-edit').forEach(b => b.onclick = () => editor(state2.rows[Number(b.dataset.idx)]));
    document.querySelectorAll('.crud-toggle').forEach(b => b.onclick = () => toggle(state2.rows[Number(b.dataset.idx)]));
    document.querySelectorAll('.crud-delete').forEach(b => b.onclick = () => remove(state2.rows[Number(b.dataset.idx)]));
  }

  async function toggle(row) {
    if (!confirm(config.toggle.confirm(row))) return;
    try {
      const result = await request(`${config.toggle.path(row)}`, config.toggle.body(row));
      recordConnection(result);
      notify('Estado actualizado');
      await refresh();
    } catch (error) { displayError(error.message); }
  }

  async function remove(row) {
    if (!confirm(config.delete.confirm(row))) return;
    try {
      const result = await request(config.delete.path(row), {});
      recordConnection(result);
      notify('Registro eliminado');
      await refresh();
    } catch (error) { displayError(error.message); }
  }

  async function refresh() {
    const form = $('#crud-filter');
    const button = $('button', form);
    button.disabled = true;
    try {
      const values = new FormData(form);
      const query = new URLSearchParams();
      if (values.get('search')) query.set('search', String(values.get('search')));
      if (config.query) config.query(values, query);
      const result = await request(config.endpoint + (query.toString() ? '?' + query : ''));
      if (version !== state.routeVersion) return;
      recordConnection(result);
      state2.rows = result.rows;
      $('#page-error').hidden = true;
      draw();
    } catch (error) {
      if (version === state.routeVersion) displayError(error.message);
    } finally {
      button.disabled = false;
    }
  }

  const filterForm = $('#crud-filter');
  filterForm.onsubmit = e => { e.preventDefault(); refresh(); };
  const createButton = $('#crud-create');
  if (createButton) createButton.onclick = () => editor(null);
  await refresh();
}

/* ---------------- Empleados ---------------- */
async function showEmployees(version) {
  await crudPage(version, {
    title: 'Empleados', singular: 'empleado', caption: 'Personal',
    subtitle: 'Mantenimiento del personal y su disponibilidad',
    action: '<button class="button primary" id="crud-create">+ Agregar empleado</button>',
    endpoint: 'employees',
    headers: ['Empleado', 'Cédula', 'Teléfono', 'Cargo', 'Ingreso', 'Estado', 'Acciones'],
    hint: 'Desactivar conserva las cuentas y el historial; eliminar solo se permite sin cuenta asociada.',
    blank: () => ({ Activo: true }),
    searchLabel: 'Nombre, cédula, correo o cargo',
    extraFilters: '<label class="check-label"><input type="checkbox" name="inactive"> Incluir inactivos</label>',
    query: (values, query) => { if (values.has('inactive')) query.set('inactive', 'true'); },
    cells: r => [
      `<td class="name-cell">${escapeHtml(r.Nombre)} ${escapeHtml(r.Apellidos)}<p class="subtle">${escapeHtml(r.Email)}</p></td>`,
      `<td>${escapeHtml(r.Cedula)}</td>`, `<td>${escapeHtml(r.Telefono)}</td>`,
      `<td>${escapeHtml(r.Cargo)}</td>`, `<td>${r.FechaIngreso ? escapeHtml(String(r.FechaIngreso).slice(0, 10)) : '—'}</td>`,
      `<td>${badge(r.Activo)}</td>`
    ],
    fields: r => `
      <label>Cédula<input name="identity" required maxlength="20" value="${escapeHtml(r.Cedula)}"></label>
      <label>Nombre<input name="name" required maxlength="50" value="${escapeHtml(r.Nombre)}"></label>
      <label>Apellidos<input name="lastName" required maxlength="100" value="${escapeHtml(r.Apellidos)}"></label>
      <label>Teléfono<input name="phone" required maxlength="20" value="${escapeHtml(r.Telefono)}"></label>
      <label>Correo<input name="email" type="email" required maxlength="150" value="${escapeHtml(r.Email)}"></label>
      <label>Cargo<select name="job">${opts(['Empleado', 'Administrador'], r.Cargo || 'Empleado')}</select></label>
      <label>Fecha de ingreso<input name="startDate" type="date" value="${r.FechaIngreso ? escapeHtml(String(r.FechaIngreso).slice(0, 10)) : ''}"></label>
      <label>Estado<select name="active"><option value="true" ${r.Activo !== false ? 'selected' : ''}>Activo</option><option value="false" ${r.Activo === false ? 'selected' : ''}>Inactivo</option></select></label>`,
    payload: (v, row) => ({
      id: row.IdEmpleado || null, identity: v.identity, name: v.name, lastName: v.lastName, phone: v.phone,
      email: v.email, job: v.job, startDate: v.startDate || null, active: v.active === 'true'
    }),
    toggle: {
      label: r => r.Activo ? 'Desactivar' : 'Activar',
      confirm: r => `¿${r.Activo ? 'Desactivar' : 'Activar'} a ${r.Nombre} ${r.Apellidos}?`,
      path: r => `employees/${r.IdEmpleado}/status`,
      body: r => ({ active: !r.Activo })
    },
    delete: { confirm: r => `¿Eliminar a ${r.Nombre} ${r.Apellidos}? Solo es posible si no tiene cuenta de acceso.`, path: r => `employees/${r.IdEmpleado}/delete` }
  });
}

/* ---------------- Usuarios y roles ---------------- */
async function showUsers(version) {
  const employees = await request('employees?inactive=true');
  let clients = { rows: [] };
  try { clients = await request('clients'); } catch { /* El catálogo de clientes depende del módulo de mejoras. */ }
  if (version !== state.routeVersion) return;
  const emp = employees.rows, cli = clients.rows;

  await crudPage(version, {
    title: 'Usuarios y roles', singular: 'usuario', caption: 'Cuentas de acceso',
    subtitle: 'Crea cuentas, cambia roles y restablece contraseñas',
    action: '<button class="button primary" id="crud-create">+ Agregar usuario</button>',
    endpoint: 'users',
    headers: ['Usuario', 'Rol', 'Vínculo', 'Correo verificado', 'Activación', 'Estado', 'Acciones'],
    hint: 'La contraseña se guarda como hash PBKDF2; nunca se almacena ni se muestra en texto plano. Si un cliente no recibe el código, puedes activarlo manualmente con el botón Activar.',
    blank: () => ({ Activo: true, TipoUsuario: 'Cliente' }),
    searchLabel: 'Usuario, rol o nombre',
    extraFilters: '<label class="check-label"><input type="checkbox" name="inactive" checked> Incluir inactivos</label>',
    query: (values, query) => { if (values.has('inactive')) query.set('inactive', 'true'); },
    cells: r => [
      `<td class="name-cell">${escapeHtml(r.NombreUsuario)}<p class="subtle">${escapeHtml(r.Nombre || '')} ${escapeHtml(r.Apellidos || '')}</p></td>`,
      `<td>${escapeHtml(r.TipoUsuario)}</td>`,
      `<td>${escapeHtml(r.IdCliente ? 'Cliente #' + r.IdCliente : 'Empleado #' + r.IdEmpleado)}</td>`,
      `<td>${r.CorreoVerificado ? 'Sí' : 'Pendiente'}</td>`,
      `<td>${r.ActivacionPendiente ? 'Pendiente' : 'Activa'}</td>`,
      `<td>${badge(r.Activo)}</td>`
    ],
    fields: r => `
      <label>Usuario<input name="username" required maxlength="50" value="${escapeHtml(r.NombreUsuario)}"></label>
      <label>Rol<select name="role" id="role-select">${opts(['Cliente', 'Empleado', 'Administrador'], r.TipoUsuario || 'Cliente')}</select></label>
      <label>Cliente (si el rol es Cliente)<select name="clientId" id="client-select"><option value="">— Ninguno —</option>
        ${cli.map(c => `<option value="${c.IdCliente}" ${r.IdCliente === c.IdCliente ? 'selected' : ''}>${escapeHtml(c.Nombre + ' ' + c.Apellidos)}</option>`).join('')}</select></label>
      <label>Empleado (si el rol es Empleado o Administrador)<select name="employeeId" id="employee-select"><option value="">— Ninguno —</option>
        ${emp.map(e => `<option value="${e.IdEmpleado}" ${r.IdEmpleado === e.IdEmpleado ? 'selected' : ''}>${escapeHtml(e.Nombre + ' ' + e.Apellidos + ' · ' + e.Cargo)}</option>`).join('')}</select></label>
      <label>Contraseña ${r.IdUsuario ? '(dejar vacío para no cambiarla)' : '(obligatoria)'}
        <input name="password" type="password" minlength="10" maxlength="255" ${r.IdUsuario ? '' : 'required'} autocomplete="new-password"></label>
      <label>Estado<select name="active"><option value="true" ${r.Activo !== false ? 'selected' : ''}>Activo</option><option value="false" ${r.Activo === false ? 'selected' : ''}>Inactivo</option></select></label>`,
    payload: (v, row) => ({
      id: row.IdUsuario || null, username: v.username, role: v.role,
      clientId: v.role === 'Cliente' && v.clientId ? Number(v.clientId) : null,
      employeeId: v.role !== 'Cliente' && v.employeeId ? Number(v.employeeId) : null,
      active: v.active === 'true', password: v.password || null
    }),
    toggle: {
      label: r => r.ActivacionPendiente ? 'Activar' : (r.Activo ? 'Desactivar' : 'Activar'),
      confirm: r => r.ActivacionPendiente
        ? `¿Activar la cuenta ${r.NombreUsuario}? Se quitará la exigencia de verificar el correo.`
        : `¿${r.Activo ? 'Desactivar' : 'Activar'} la cuenta ${r.NombreUsuario}?`,
      path: r => `users/${r.IdUsuario}/status`,
      body: r => ({ active: r.ActivacionPendiente ? true : !r.Activo })
    },
    delete: { confirm: r => `¿Eliminar la cuenta ${r.NombreUsuario}? También se borran sus preferencias y tokens.`, path: r => `users/${r.IdUsuario}/delete` },
    afterRender: r => {
      // El formulario ya existe: se ajusta qué vínculo aplica según el rol seleccionado.
      const role = $('#role-select'), client = $('#client-select'), employee = $('#employee-select');
      if (!role || !client || !employee) return;
      const sync = () => {
        client.disabled = role.value !== 'Cliente';
        employee.disabled = role.value === 'Cliente';
      };
      role.addEventListener('change', sync);
      if (!r.IdUsuario) role.value = 'Cliente';
      sync();
    }
  });
}

/* ---------------- Inventario ---------------- */
async function showInventory(version) {
  await crudPage(version, {
    title: 'Inventario', singular: 'producto', caption: 'Existencias',
    subtitle: 'Productos, unidades y nivel mínimo de reposición',
    action: '<button class="button primary" id="crud-create">+ Agregar producto</button>',
    endpoint: 'inventory',
    headers: ['Producto', 'Cantidad', 'Unidad', 'Mínimo', 'Estado', 'Acciones'],
    hint: 'Marca “Solo bajo mínimo” para ver los productos que requieren reposición.',
    blank: () => ({ Activo: true, Cantidad: 0, CantidadMinima: 0, UnidadMedida: 'Unidad' }),
    searchLabel: 'Nombre o descripción',
    extraFilters: '<label class="check-label"><input type="checkbox" name="low"> Solo bajo mínimo</label>',
    query: (values, query) => { if (values.has('low')) query.set('lowOnly', 'true'); },
    cells: r => [
      `<td class="name-cell">${escapeHtml(r.NombreProducto)}<p class="subtle">${escapeHtml(r.Descripcion || '')}</p></td>`,
      `<td>${escapeHtml(r.Cantidad)} ${r.Cantidad <= r.CantidadMinima ? '⚠' : ''}</td>`,
      `<td>${escapeHtml(r.UnidadMedida)}</td>`, `<td>${escapeHtml(r.CantidadMinima)}</td>`,
      `<td>${badge(r.Activo)}</td>`
    ],
    fields: r => `
      <label>Nombre<input name="name" required maxlength="100" value="${escapeHtml(r.NombreProducto)}"></label>
      <label>Unidad<select name="unit">${opts(['Unidad', 'Gramo', 'Kilogramo', 'Mililitro', 'Litro'], r.UnidadMedida || 'Unidad')}</select></label>
      <label class="full">Descripción<input name="description" maxlength="250" value="${escapeHtml(r.Descripcion)}"></label>
      <label>Cantidad<input name="quantity" type="number" min="0" step="0.01" required value="${r.Cantidad ?? 0}"></label>
      <label>Cantidad mínima<input name="minQuantity" type="number" min="0" step="0.01" required value="${r.CantidadMinima ?? 0}"></label>
      <label>Estado<select name="active"><option value="true" ${r.Activo !== false ? 'selected' : ''}>Activo</option><option value="false" ${r.Activo === false ? 'selected' : ''}>Inactivo</option></select></label>`,
    payload: (v, row) => ({
      id: row.IdInventario || null, name: v.name, description: v.description,
      quantity: Number(v.quantity), unit: v.unit, minQuantity: Number(v.minQuantity), active: v.active === 'true'
    }),
    toggle: {
      label: r => r.Activo ? 'Desactivar' : 'Activar',
      confirm: r => `¿${r.Activo ? 'Desactivar' : 'Activar'} ${r.NombreProducto}?`,
      path: r => `inventory/${r.IdInventario}/status`,
      body: r => ({ active: !r.Activo })
    },
    delete: { confirm: r => `¿Eliminar ${r.NombreProducto} del inventario?`, path: r => `inventory/${r.IdInventario}/delete` }
  });
}

/* ---------------- Promociones ---------------- */
async function showPromotions(version) {
  let catalog = { rows: [] };
  try { catalog = await request('catalog?inactive=true'); } catch { /* El catálogo depende del módulo de mejoras. */ }
  if (version !== state.routeVersion) return;

  await crudPage(version, {
    title: 'Promociones', singular: 'promoción', caption: 'Descuentos vigentes',
    subtitle: 'Descuentos por porcentaje con vigencia y servicio opcional',
    action: '<button class="button primary" id="crud-create">+ Agregar promoción</button>',
    endpoint: 'promotions',
    headers: ['Promoción', 'Servicio', 'Descuento', 'Vigencia', 'Estado', 'Acciones'],
    hint: 'Un descuento entre 1% y 100%. La vigencia se valida contra las fechas indicadas.',
    blank: () => ({ Activa: true }),
    searchLabel: 'Nombre de la promoción',
    extraFilters: '<label class="check-label"><input type="checkbox" name="inactive"> Incluir inactivas</label>',
    query: (values, query) => { if (values.has('inactive')) query.set('inactive', 'true'); },
    cells: r => [
      `<td class="name-cell">${escapeHtml(r.NombrePromocion)}<p class="subtle">${escapeHtml(r.Descripcion || '')}</p></td>`,
      `<td>${escapeHtml(r.Servicio || 'Todos los servicios')}</td>`,
      `<td class="price">${escapeHtml(r.PorcentajeDescuento)}%</td>`,
      `<td>${escapeHtml(String(r.FechaInicio).slice(0, 10))} → ${escapeHtml(String(r.FechaFin).slice(0, 10))}</td>`,
      `<td>${badge(r.Activa, 'Activa', 'Inactiva')}</td>`
    ],
    fields: r => `
      <label>Nombre<input name="name" required maxlength="100" value="${escapeHtml(r.NombrePromocion)}"></label>
      <label>Servicio (opcional)<select name="serviceId"><option value="">Todos los servicios</option>
        ${catalog.rows.map(s => `<option value="${s.IdServicio}" ${r.IdServicio === s.IdServicio ? 'selected' : ''}>${escapeHtml(s.NombreServicio)}</option>`).join('')}</select></label>
      <label class="full">Descripción<input name="description" maxlength="250" value="${escapeHtml(r.Descripcion)}"></label>
      <label>Descuento (%)<input name="percent" type="number" min="1" max="100" step="0.01" required value="${r.PorcentajeDescuento ?? 10}"></label>
      <label>Vigencia<select name="active"><option value="true" ${r.Activa !== false ? 'selected' : ''}>Activa</option><option value="false" ${r.Activa === false ? 'selected' : ''}>Inactiva</option></select></label>
      <label>Desde<input name="start" type="date" required value="${r.FechaInicio ? escapeHtml(String(r.FechaInicio).slice(0, 10)) : ''}"></label>
      <label>Hasta<input name="end" type="date" required value="${r.FechaFin ? escapeHtml(String(r.FechaFin).slice(0, 10)) : ''}"></label>`,
    payload: (v, row) => ({
      id: row.IdPromocion || null, serviceId: v.serviceId ? Number(v.serviceId) : null, name: v.name,
      description: v.description, percent: Number(v.percent), start: v.start, end: v.end, active: v.active === 'true'
    }),
    toggle: {
      label: r => r.Activa ? 'Desactivar' : 'Activar',
      confirm: r => `¿${r.Activa ? 'Desactivar' : 'Activar'} ${r.NombrePromocion}?`,
      path: r => `promotions/${r.IdPromocion}/status`,
      body: r => ({ active: !r.Activa })
    },
    delete: { confirm: r => `¿Eliminar la promoción ${r.NombrePromocion}?`, path: r => `promotions/${r.IdPromocion}/delete` }
  });
}

/* ---------------- Recolecciones ---------------- */
async function showCollections(version) {
  let orderRows = [];
  try { orderRows = (await request('orders')).rows; } catch { /* Los pedidos dependen del módulo de mejoras. */ }
  if (version !== state.routeVersion) return;
  await crudPage(version, {
    title: 'Recolecciones', singular: 'recolección', caption: 'Recolecciones programadas',
    subtitle: 'Programación de recolecciones asociadas a un pedido',
    action: '<button class="button primary" id="crud-create">+ Agregar recolección</button>',
    endpoint: 'collections',
    headers: ['Pedido', 'Cliente', 'Dirección', 'Programada', 'Estado', 'Acciones'],
    hint: 'Estados: Pendiente, Programada, Recolectada y Cancelada.',
    blank: () => ({ Estado: 'Pendiente' }),
    searchLabel: 'Pedido, cliente o dirección',
    extraFilters: `<label>Estado<select name="status">${opts(['Pendiente', 'Programada', 'Recolectada', 'Cancelada'], '', 'Todos')}</select></label>`,
    query: (values, query) => { const status = values.get('status'); if (status) query.set('status', String(status)); },
    cells: r => [
      `<td>#${r.IdPedido}</td>`,
      `<td class="name-cell">${escapeHtml(r.Cliente)}<p class="subtle">${escapeHtml(r.Telefono)}</p></td>`,
      `<td>${escapeHtml(r.Direccion)}</td>`,
      `<td>${escapeHtml(r.FechaProgramada ? String(r.FechaProgramada).slice(0, 16).replace('T', ' ') : '—')}</td>`,
      `<td><span class="badge">${escapeHtml(r.Estado)}</span></td>`
    ],
    fields: r => `
      <label class="full">Pedido<select name="orderId" required>
        <option value="">Selecciona un pedido…</option>
        ${orderRows.map(o => `<option value="${o.IdPedido}" ${r.IdPedido === o.IdPedido ? 'selected' : ''}>#${o.IdPedido} · ${escapeHtml(o.Cliente)} · ${escapeHtml(o.Estado)} · ${currency(o.Total)}</option>`).join('')}</select></label>
      <label>Estado<select name="status">${opts(['Pendiente', 'Programada', 'Recolectada', 'Cancelada'], r.Estado || 'Pendiente')}</select></label>
      <label class="full">Dirección<input name="address" required maxlength="250" value="${escapeHtml(r.Direccion)}"></label>
      <label class="full">Fecha programada<input name="scheduled" type="datetime-local" required value="${r.FechaProgramada ? escapeHtml(String(r.FechaProgramada).slice(0, 16)) : ''}"></label>
      <label class="full">Observaciones<textarea name="notes" maxlength="300">${escapeHtml(r.Observaciones || '')}</textarea></label>`,
    payload: (v, row) => ({
      id: row.IdRecoleccion || null, orderId: Number(v.orderId), address: v.address,
      scheduled: v.scheduled ? new Date(v.scheduled).toISOString() : null, status: v.status, notes: v.notes || null
    }),
    delete: { confirm: r => `¿Eliminar la recolección #${r.IdRecoleccion}?`, path: r => `collections/${r.IdRecoleccion}/delete` }
  });
}

/* ---------------- Pagos ---------------- */
async function showPayments(version) {
  let orderRows = [];
  try { orderRows = (await request('orders')).rows; } catch { /* Los pedidos dependen del módulo de mejoras. */ }
  if (version !== state.routeVersion) return;
  await crudPage(version, {
    title: 'Pagos', singular: 'pago', caption: 'Cobros registrados',
    subtitle: 'Registro y control de pagos por pedido',
    action: '<button class="button primary" id="crud-create">+ Registrar pago</button>',
    endpoint: 'payments',
    headers: ['Pago', 'Pedido', 'Cliente', 'Monto', 'Método', 'Estado', 'Acciones'],
    hint: 'Un pago no puede superar el total del pedido. Los pagos con comprobante no se eliminan.',
    blank: () => ({ EstadoPago: 'Pendiente', MetodoPago: 'Efectivo' }),
    searchLabel: 'Pago, pedido, cliente o referencia',
    extraFilters: `<label>Estado<select name="status">${opts(['Pendiente', 'Pagado', 'Anulado'], '', 'Todos')}</select></label>`,
    query: (values, query) => { const status = values.get('status'); if (status) query.set('status', String(status)); },
    cells: r => [
      `<td>#${r.IdPago}</td>`,
      `<td>#${r.IdPedido}<p class="subtle">Total ${currency(r.TotalPedido)}</p></td>`,
      `<td class="name-cell">${escapeHtml(r.Cliente)}<p class="subtle">${escapeHtml(r.Email)}</p></td>`,
      `<td class="price">${currency(r.Monto)}</td>`,
      `<td>${escapeHtml(r.MetodoPago)}</td>`,
      `<td><span class="badge">${escapeHtml(r.EstadoPago)}</span></td>`
    ],
    fields: r => `
      <label class="full">Pedido<select name="orderId" required>
        <option value="">Selecciona un pedido…</option>
        ${orderRows.map(o => `<option value="${o.IdPedido}" ${r.IdPedido === o.IdPedido ? 'selected' : ''}>#${o.IdPedido} · ${escapeHtml(o.Cliente)} · ${escapeHtml(o.Estado)} · ${currency(o.Total)}</option>`).join('')}</select></label>
      <label>Monto (₡)<input name="amount" type="number" min="0.01" step="0.01" required value="${r.Monto ?? ''}"></label>
      <label>Método<select name="method">${opts(['Efectivo', 'SINPE Movil'], r.MetodoPago || 'Efectivo')}</select></label>
      <label>Estado<select name="status">${opts(['Pendiente', 'Pagado', 'Anulado'], r.EstadoPago || 'Pendiente')}</select></label>
      <label class="full">Referencia<input name="reference" maxlength="100" value="${escapeHtml(r.Referencia)}"></label>`,
    payload: (v, row) => ({
      id: row.IdPago || null, orderId: Number(v.orderId), amount: Number(v.amount),
      method: v.method, status: v.status, reference: v.reference || null
    }),
    delete: { confirm: r => `¿Eliminar el pago #${r.IdPago}?`, path: r => `payments/${r.IdPago}/delete` }
  });
}