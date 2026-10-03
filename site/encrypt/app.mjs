import { importPublicKey, subscriptionBytes } from './crypto.mjs';
import { encryptForApp, maxExternalUrlBytes } from './clients.mjs';
import { renderEncryptedQr } from './qr.mjs';

const form = document.querySelector('#encrypt-form');
const target = document.querySelector('#target-app');
const input = document.querySelector('#subscription');
const submit = document.querySelector('#encrypt');
const clear = document.querySelector('#clear');
const count = document.querySelector('#byte-count');
const error = document.querySelector('#input-error');
const result = document.querySelector('#result');
const output = document.querySelector('#encrypted-link');
const copy = document.querySelector('#copy');
const openApp = document.querySelector('#open-app');
const status = document.querySelector('#status');
const keyStatus = document.querySelector('#key-status');
const qrResult = document.querySelector('#qr-result');
const qrCanvas = document.querySelector('#qr-code');
const qrError = document.querySelector('#qr-error');
const secure = Boolean(globalThis.isSecureContext && globalThis.crypto?.subtle);
const apps = {
  tunnio: {
    name: 'Tunnio', action: 'Encrypt URL',
    hint: 'Use a Tunnio build configured with the matching key.',
    privacy: 'Your URL stays in this browser. This page does not upload or store it.',
  },
  happ: {
    name: 'Happ', action: 'Send to Happ & encrypt',
    hint: 'Use a subscription compatible with Happ. The generated link works only in Happ.',
    privacy: 'Clicking “Send to Happ & encrypt” sends your original subscription URL, including any access token, to crypto.happ.su. This page does not store it.',
  },
  incy: {
    name: 'INCY', action: 'Create INCY link',
    hint: 'Use a subscription compatible with INCY. The link conceals the URL but can be decoded with INCY’s public encoder.',
    privacy: 'Your URL stays in this browser. This page does not upload or store it.',
  },
};
let keyInfo;
let keyFailed = false;
let revision = 0;
let pending;

function maxBytes() {
  return target.value === 'tunnio' ? keyInfo?.maxBytes : maxExternalUrlBytes;
}

function ready() {
  return secure && Object.hasOwn(apps, target.value) && (target.value !== 'tunnio' || Boolean(keyInfo));
}

function updateControls() {
  const app = apps[target.value];
  const bytes = new TextEncoder().encode(input.value.trim()).length;
  const limit = maxBytes();
  count.textContent = limit ? `${bytes} / ${limit} bytes` : `${bytes} bytes`;
  count.classList.toggle('over-limit', Boolean(limit && bytes > limit));
  submit.disabled = !ready() || Boolean(pending);
  submit.textContent = pending ? 'Encrypting…' : app.action;
  keyStatus.classList.toggle('ready', ready());
  keyStatus.textContent = !secure ? 'HTTPS required' : target.value === 'tunnio' ?
    (keyInfo ? 'Ready to encrypt' : keyFailed ? 'Public key unavailable' : 'Loading public key…') :
    target.value === 'happ' ? 'Uses Happ’s service' : 'Ready · runs in your browser';
  if (pending) form.setAttribute('aria-busy', 'true');
  else form.removeAttribute('aria-busy');
}

function showTarget() {
  const app = apps[target.value];
  document.querySelector('#app-hint').textContent = app.hint;
  document.querySelector('#privacy-note').textContent = app.privacy;
  document.querySelector('#result-hint').textContent = `Paste this link into ${app.name} to import your subscription.`;
  document.querySelector('#result-title').textContent = `Your ${app.name} link`;
  for (const name of Object.keys(apps)) {
    document.querySelector(`#${name}-details`).hidden = name !== target.value;
  }
  updateControls();
}

function invalidate() {
  revision += 1;
  pending?.abort();
  pending = undefined;
  output.value = '';
  openApp.hidden = true;
  openApp.removeAttribute('href');
  qrCanvas.width = qrCanvas.height = 0;
  qrResult.hidden = true;
  qrError.textContent = '';
  result.hidden = true;
  copy.disabled = true;
  error.textContent = !secure || (target.value === 'tunnio' && keyFailed) ?
    'Could not load encryption. Open this page over HTTPS in a current browser, then reload.' : '';
  status.textContent = '';
  input.removeAttribute('aria-invalid');
  updateControls();
}

function reset() {
  form.reset();
  invalidate();
  showTarget();
}

input.addEventListener('input', invalidate);
target.addEventListener('change', () => {
  invalidate();
  showTarget();
});
clear.addEventListener('click', () => {
  invalidate();
  input.value = '';
  updateControls();
  input.focus();
});
window.addEventListener('pagehide', reset);
window.addEventListener('pageshow', (event) => {
  if (event.persisted) reset();
});

form.addEventListener('submit', async (event) => {
  event.preventDefault();
  if (!ready() || pending) return;
  invalidate();
  const current = revision;
  const selected = target.value;
  const url = input.value;
  try {
    subscriptionBytes(url, maxBytes());
  } catch (failure) {
    error.textContent = failure.message;
    input.setAttribute('aria-invalid', 'true');
    input.focus();
    return;
  }
  const controller = new AbortController();
  pending = controller;
  updateControls();
  try {
    const encrypted = await encryptForApp(url, selected, keyInfo, controller.signal);
    if (current !== revision) return;
    output.value = encrypted;
    result.hidden = false;
    copy.disabled = false;
    if (selected !== 'tunnio') {
      openApp.setAttribute('href', encrypted);
      openApp.textContent = `Open ${apps[selected].name}`;
      openApp.hidden = false;
    }
    try {
      renderEncryptedQr(qrCanvas, encrypted);
      qrResult.hidden = false;
    } catch {
      qrError.textContent = 'QR code is unavailable. You can still copy the encrypted link.';
    }
    status.textContent = `Your ${apps[selected].name} link is ready.`;
    output.focus();
  } catch {
    if (current === revision) {
      error.textContent = selected === 'happ' ?
        'Happ could not encrypt this URL. The request failed or timed out. Try again or use the official Happ generator below.' :
        'Encryption failed. Please try again.';
    }
  } finally {
    if (current === revision) {
      pending = undefined;
      updateControls();
    }
  }
});

copy.addEventListener('click', async () => {
  const encrypted = output.value;
  if (!encrypted) return;
  const current = revision;
  try {
    await navigator.clipboard.writeText(encrypted);
    if (current === revision) status.textContent = 'Link copied.';
  } catch {
    if (current !== revision) return;
    output.focus();
    output.select();
    status.textContent = 'Automatic copying is unavailable. Copy the selected link manually.';
  }
});

async function initialize() {
  showTarget();
  if (!secure) {
    invalidate();
    return;
  }
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 10000);
  try {
    const response = await fetch(new URL('./public.pem', import.meta.url), {
      cache: 'no-store', credentials: 'omit', redirect: 'error', mode: 'same-origin',
      signal: controller.signal,
    });
    if (!response.ok) throw new Error('Public key unavailable.');
    keyInfo = await importPublicKey(await response.text());
    document.querySelector('#key-fingerprint').textContent = keyInfo.fingerprint;
    document.querySelector('#key-size').textContent = `${keyInfo.key.algorithm.modulusLength}-bit RSA`;
    document.querySelector('#max-bytes').textContent = `${keyInfo.maxBytes} UTF-8 bytes`;
  } catch {
    keyFailed = true;
    if (target.value === 'tunnio') {
      error.textContent = 'Could not load encryption. Open this page over HTTPS in a current browser, then reload.';
    }
  } finally {
    clearTimeout(timeout);
    updateControls();
  }
}

initialize();
