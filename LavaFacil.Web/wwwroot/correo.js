'use strict';
/* Verificación de correo y recuperación de contraseña.
   Reutiliza state, request(), bindForm(), bindPassword(), notify(), escapeHtml(), $() y app de app.js. */

let mailStatusPromise = null;
let verifyResendButton = null;

const mailById = id => document.getElementById(id);

function maskEmail(value) {
  const email = String(value || '');
  const at = email.indexOf('@');
  if (at < 1) return email || 'tu correo';
  const local = email.slice(0, at);
  const domain = email.slice(at + 1);
  const parts = domain.split('.');
  const tld = parts.length > 1 ? '.' + parts[parts.length - 1] : '';
  return `${local.slice(0, 1)}***@${(parts[0] || '').slice(0, 1)}***${tld}`;
}

function stopVerifyCountdown() {
  if (!verifyResendButton) return;
  clearInterval(verifyResendButton._mailTimer);
  verifyResendButton._mailTimer = null;
  verifyResendButton = null;
}

function runCountdown(button, seconds, idleText, activeText) {
  if (!button) return;
  if (button._mailTimer) clearInterval(button._mailTimer);
  let left = Math.max(0, Math.round(Number(seconds) || 0));
  const paint = () => {
    if (!button.isConnected) {
      clearInterval(button._mailTimer); button._mailTimer = null; return;
    }
    if (left <= 0) {
      clearInterval(button._mailTimer); button._mailTimer = null;
      button.disabled = false; button.textContent = idleText; return;
    }
    button.disabled = true;
    button.textContent = activeText.replace('{n}', String(left));
    left -= 1;
  };
  paint();
  if (Number(seconds) > 0) button._mailTimer = setInterval(paint, 1000);
}

function expiryText(value) {
  const date = new Date(value);
  return value && !Number.isNaN(date.getTime())
    ? `Código enviado. Vence el ${date.toLocaleString('es-CR')}.`
    : 'Código enviado. Revisa tu correo.';
}

function remainingSeconds(mail) {
  const base = Math.max(0, Math.round(Number(mail?.segundosEspera) || 0));
  if (!base) return 0;
  const since = Number(mail?.esperaMarcadaEn) || 0;
  if (!since) return base;
  return Math.max(0, Math.ceil(base - (Date.now() - since) / 1000));
}

function setBannerStatus(text) {
  const status = mailById('mail-banner-status');
  if (status) status.textContent = text || '';
}

function syncForgotLink() {
  const link = mailById('forgot-link');
  if (link) link.hidden = !(state.mailReady && state.correoConfigurado);
}

function renderMailBanner() {
  const banner = mailById('mail-banner');
  if (!banner) return;
  const mail = state.mail;
  const visible = Boolean(state.user && state.mailReady && state.correoConfigurado && mail && mail.email && !mail.verificado);
  if (!visible) {
    banner.hidden = true;
    banner.classList.remove('error');
    banner.replaceChildren();
    return;
  }
  banner.hidden = false;
  banner.classList.toggle('error', Boolean(mail.errorEnvio));
  const extra = mail.errorEnvio ? ' ' + mail.errorEnvio : '';
  banner.innerHTML = `<p>Tu correo <strong>${escapeHtml(mail.email)}</strong> no está verificado.${escapeHtml(extra)}</p><a href="#verificar" class="button light small">Verificar</a><button type="button" class="button mint small" id="mail-banner-resend">${mail.errorEnvio ? 'Reintentar' : 'Reenviar'}</button><span id="mail-banner-status" class="mail-help" role="status" aria-live="polite"></span>`;
  const resend = mailById('mail-banner-resend');
  if (!resend) return;
  resend.addEventListener('click', async () => {
    resend.disabled = true;
    resend.textContent = 'Enviando…';
    try {
      await enviarVerificacion(true);
      setBannerStatus('Código reenviado. Revisa tu correo.');
    } catch (error) {
      setBannerStatus(error.message);
    }
  });
  if (!mail.errorEnvio && remainingSeconds(mail) > 0) {
    runCountdown(resend, remainingSeconds(mail), 'Reenviar', 'Reenviar ({n} s)');
  }
}

async function enviarVerificacion(silencioso) {
  const current = state.mail || {};
  try {
    const result = await request('email/verificacion/enviar', {});
    if (result && result.enviado === false) {
      throw new Error(result.message || 'No pudimos enviar el código. Reintenta en un momento.');
    }
    state.mail = Object.assign({}, current, {
      enviado: true,
      tieneCodigoPendiente: true,
      expiraEn: result.expiraEn || current.expiraEn,
      segundosEspera: Number(result.segundosEspera) || 0,
      esperaMarcadaEn: Date.now(),
      autoEnviado: true,
      errorEnvio: ''
    });
    renderMailBanner();
    if (!silencioso) notify(result.message || 'Código de verificación enviado.');
    return result;
  } catch (error) {
    const retry = Number(error.payload?.retryAfterSegundos);
    const limited = Number.isFinite(retry) && retry > 0;
    state.mail = Object.assign({}, current, {
      autoEnviado: true,
      segundosEspera: limited ? retry : current.segundosEspera,
      esperaMarcadaEn: limited ? Date.now() : current.esperaMarcadaEn,
      errorEnvio: limited ? '' : error.message
    });
    renderMailBanner();
    if (!silencioso) notify(error.message);
    throw error;
  }
}

async function maybeAutoSend() {
  const mail = state.mail;
  if (!mail || mail.autoEnviado || mail.verificado || mail.tieneCodigoPendiente) return;
  if (!mail.email || state.user?.role !== 'Cliente' || !state.correoConfigurado) return;
  mail.autoEnviado = true;
  try { await enviarVerificacion(true); }
  catch (error) { /* El banner muestra el error y ofrece Reintentar. */ }
}

async function ensureMailStatus() {
  renderMailBanner();
  if (!state.user || !state.mailReady) return;
  if (state.mail) { await maybeAutoSend(); renderMailBanner(); return; }
  if (!mailStatusPromise) {
    mailStatusPromise = (async () => {
      try {
        const mail = await request('email/estado');
        if (!state.user) return;
        state.mail = Object.assign({}, mail, { esperaMarcadaEn: Date.now() });
        await maybeAutoSend();
      } catch (error) {
        /* Las pantallas y el banner muestran el estado disponible. */
      }
      renderMailBanner();
    })();
  }
  try { await mailStatusPromise; }
  finally { mailStatusPromise = null; }
}

function startVerifyCountdown(button) {
  if (!button) return;
  verifyResendButton = button;
  runCountdown(button, remainingSeconds(state.mail), 'Reenviar código', 'Reenviar en {n} s');
}

async function showVerify() {
  if (!state.user) { location.hash = 'login'; return; }
  if (!state.mailReady) { location.hash = 'home'; notify('La verificación por correo no está disponible en esta instalación.'); return; }
  stopVerifyCountdown();
  app.replaceChildren($('#verify-template').content.cloneNode(true));
  const form = $('#verify-form');
  const code = $('#verify-code');
  const errorBox = $('.form-error', form);
  const resend = $('#verify-resend');
  const status = $('#verify-status');
  if (!state.mail) await ensureMailStatus();
  if (!state.mail) {
    $('#verify-email').textContent = 'tu correo';
    status.textContent = 'No se pudo consultar el estado de tu correo. Revisa la conexión y vuelve a intentarlo.';
    form.querySelectorAll('input, button').forEach(el => { el.disabled = true; });
    return;
  }
  const mail = state.mail;
  $('#verify-email').textContent = mail.email ? maskEmail(mail.email) : 'sin correo registrado';
  code.addEventListener('input', () => { code.value = code.value.replace(/\D/g, '').slice(0, 6); });

  if (!mail.email) {
    status.textContent = 'Tu cuenta no tiene un correo electrónico registrado. Actualízalo desde Mi perfil o pide apoyo a un administrador.';
    form.querySelectorAll('input, button').forEach(el => { el.disabled = true; });
    return;
  }
  if (mail.verificado) {
    status.textContent = 'Este correo ya está verificado. No necesitas hacer nada más.';
    form.querySelectorAll('input, button').forEach(el => { el.disabled = true; });
    return;
  }
  if (mail.tieneCodigoPendiente) {
    status.textContent = expiryText(mail.expiraEn);
    startVerifyCountdown(resend);
  } else if (mail.errorEnvio) {
    status.textContent = mail.errorEnvio;
  } else {
    status.textContent = 'Solicita un código para verificar tu correo.';
  }
  code.focus();

  bindForm(form, async values => {
    const codigo = String(values.codigo || '').trim();
    if (!/^\d{6}$/.test(codigo)) throw new Error('Escribe el código de 6 dígitos que enviamos a tu correo.');
    const result = await request('email/verificacion/confirmar', { codigo });
    if (result && result.verificado === false) throw new Error('El código no es válido o ya venció. Solicita uno nuevo.');
    notify('Correo verificado.');
    state.mail = null;
    location.hash = 'home';
  });

  resend.addEventListener('click', async () => {
    errorBox.hidden = true;
    const original = resend.textContent;
    resend.disabled = true;
    resend.textContent = 'Enviando…';
    try {
      await enviarVerificacion(true);
      status.textContent = 'Código reenviado. Revisa tu correo.';
      startVerifyCountdown(resend);
      code.focus();
    } catch (error) {
      const retry = Number(error.payload?.retryAfterSegundos);
      if (retry > 0) startVerifyCountdown(resend);
      else { resend.disabled = false; resend.textContent = original; }
      errorBox.textContent = error.message;
      errorBox.hidden = false;
      code.focus();
    }
  });
}

function showRecover() {
  stopVerifyCountdown();
  app.replaceChildren($('#recover-template').content.cloneNode(true));
  bindPassword();
  const form = $('#recover-form');
  const step1 = $('#recover-step1');
  const step2 = $('#recover-step2');
  const sendButton = $('#recover-send');
  const message = $('#recover-message');
  const code = $('#recover-code');
  let identifier = '';
  let step = 1;

  step2.querySelectorAll('input, button').forEach(el => { el.disabled = true; });
  code.addEventListener('input', () => { code.value = code.value.replace(/\D/g, '').slice(0, 6); });
  $('#recover-id').focus();

  bindForm(form, async values => {
    if (step === 1) {
      identifier = String(values.identificador || '').trim();
      if (!identifier) throw new Error('Escribe tu usuario o correo electrónico.');
      const result = await request('email/recuperacion/solicitar', { identificador: identifier });
      step = 2;
      step1.hidden = true;
      step2.hidden = false;
      step1.querySelectorAll('input, button').forEach(el => { el.disabled = true; });
      step2.querySelectorAll('input, button').forEach(el => { el.disabled = false; });
      sendButton.type = 'button';
      message.textContent = result.message || 'Si la cuenta existe, enviamos un código a su correo registrado.';
      code.focus();
      return;
    }
    const codigo = String(values.codigo || '').trim();
    const password = String(values.nuevaClave || '');
    const confirm = String(values.confirmarClave || '');
    if (!/^\d{6}$/.test(codigo)) throw new Error('Escribe el código de 6 dígitos que recibiste en el correo.');
    if (password.length < 10) throw new Error('La nueva contraseña debe tener al menos 10 caracteres.');
    if (password !== confirm) throw new Error('Las contraseñas no coinciden.');
    await request('email/recuperacion/restablecer', { identificador: identifier, codigo, nuevaClave: password });
    form.reset();
    notify('Contraseña actualizada. Inicia sesión.');
    location.hash = 'login';
  });
}

window.addEventListener('hashchange', () => { renderMailBanner(); syncForgotLink(); });
