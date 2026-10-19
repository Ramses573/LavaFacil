'use strict';
(() => {
  const panel=document.querySelector('#monitor');
  let busy=false, previous=null, generation=0;
  const when=v=>v?new Date(v).toLocaleString('es-CR'):'Sin comprobación previa';
  const role=r=>r==='PRINCIPAL'?'Principal':r==='MIRROR'?'Espejo':r;
  const esc=v=>escapeHtml(v);
  function hide(){generation++;previous=null;panel.hidden=true;panel.replaceChildren();}
  async function check(){
    if(!state.user){hide();return;}
    if(busy||document.hidden)return;
    const user=state.user.id, turn=generation;busy=true;
    const button=panel.querySelector('button');if(button)button.disabled=true;
    try {
      const response=await fetch('/api/health',{credentials:'same-origin',cache:'no-store'});
      if(response.status===401){hide();return;}
      if(!response.ok)throw new Error('No se pudo obtener el diagnóstico.');
      const data=await response.json();
      if(turn!==generation||!state.user||state.user.id!==user)return;
      const admin=state.user.role==='Administrador';
      const changed=data.activeServer&&previous&&data.activeServer!==previous;
      if(data.activeServer)previous=data.activeServer;
      panel.hidden=!admin&&data.applicationAvailable;
      if(!admin){panel.innerHTML=`<div class="notice error" role="status">${esc(data.message)}</div>`;return;}
      panel.innerHTML=`<details ${panel.querySelector('details')?.open?'open':''}><summary>Estado de servidores · ${data.applicationAvailable?'Base disponible':'Conexión no confirmada'}</summary><div class="monitor-content"><p role="status">${esc(data.message)}</p>${changed?`<p class="notice">Conexión restablecida. Servidor activo: ${esc(data.activeServer)}.</p>`:''}<p>${data.activeServer?'Conexión comprobada con':'Último servidor confirmado'}: <strong>${esc(data.activeServer||data.lastActiveServer||'Sin confirmar')}</strong>${!data.activeServer?' · '+esc(when(data.lastActiveAt)):''}</p><div class="monitor-grid">${(data.servers||[]).map(s=>`<article><h3>${esc(s.server||s.endpoint)}</h3><p>${esc(s.endpoint)}</p><p><strong>${s.reachable?'SQL responde':'Sin conexión confirmada'}</strong></p><p>${s.role?'Rol actual: '+esc(role(s.role)):'Último rol confirmado: '+esc(role(s.lastRole)||'Desconocido')}</p>${s.role?`<p>Sincronización: ${esc(s.sync||'No disponible')}</p>`:`<p>${esc(when(s.lastConfirmedAt))}</p>`}<small>${esc(s.detail)}</small></article>`).join('')}</div><p class="subtle">Comprobado: ${esc(when(data.checkedAt))}. Revisión cada 15 segundos mientras esta pestaña esté visible. “No responde” no significa necesariamente que el equipo esté apagado.</p><button class="button light small" type="button">Comprobar ahora</button></div></details>`;
      // Un problema abre el diagnóstico; no oculta un aviso de falla en el detalle cerrado.
      if(!data.applicationAvailable||(data.servers||[]).some(s=>!s.reachable||s.sync!=='SYNCHRONIZED'))panel.querySelector('details').open=true;
      panel.querySelector('button').onclick=check;
    }catch {
      if(turn===generation&&state.user?.id===user){panel.hidden=false;panel.innerHTML='<div class="notice error" role="status">No se pudo actualizar el diagnóstico. El estado de los servidores no está confirmado. Conserva tus datos antes de volver a intentar.</div>';}
    }finally{busy=false;const b=panel.querySelector('button');if(b)b.disabled=false;}
  }
  // El encabezado cambia al iniciar/cerrar sesión, incluso sin cambiar el hash.
  new MutationObserver(()=>{if(!state.user)hide();else check();}).observe(document.querySelector('#header'),{attributes:true,attributeFilter:['hidden']});
  window.addEventListener('hashchange',()=>{if(!state.user)hide();else check();});
  document.addEventListener('visibilitychange',()=>{if(!document.hidden)check();});
  setInterval(check,15000);check();
})();
