import { encryptSubscription, importPublicKey, subscriptionBytes } from './crypto.mjs';

const form = document.querySelector('#encrypt-form');
const input = document.querySelector('#subscription');
const submit = document.querySelector('#encrypt');
const clear = document.querySelector('#clear');
const count = document.querySelector('#byte-count');
const error = document.querySelector('#input-error');
const result = document.querySelector('#result');
const output = document.querySelector('#encrypted-link');
const copy = document.querySelector('#copy');
const status = document.querySelector('#status');
const keyStatus = document.querySelector('#key-status');
let keyInfo;
let revision = 0;
let busy = false;

function invalidate() {
  revision += 1;
  output.value = '';
  result.hidden = true;
  copy.disabled = true;
  error.textContent = '';
  status.textContent = '';
  input.removeAttribute('aria-invalid');
  const bytes = new TextEncoder().encode(input.value.trim()).length;
  count.textContent = keyInfo ? `${bytes} / ${keyInfo.maxBytes} bytes` : `${bytes} bytes`;
  count.classList.toggle('over-limit', Boolean(keyInfo && bytes > keyInfo.maxBytes));
  submit.disabled = !keyInfo || busy;
}

function reset() {
  form.reset();
  invalidate();
}

input.addEventListener('input', invalidate);
clear.addEventListener('click', () => {
  reset();
  input.focus();
});
window.addEventListener('pagehide', reset);
window.addEventListener('pageshow', (event) => {
  if (event.persisted) reset();
});

form.addEventListener('submit', async (event) => {
  event.preventDefault();
  if (!keyInfo || busy) return;
  invalidate();
  const current = revision;
  try {
    subscriptionBytes(input.value, keyInfo.maxBytes);
  } catch (failure) {
    error.textContent = failure.message;
    input.setAttribute('aria-invalid', 'true');
    input.focus();
    return;
  }
  busy = true;
  submit.disabled = true;
  submit.textContent = 'Encrypting…';
  form.setAttribute('aria-busy', 'true');
  try {
    const encrypted = await encryptSubscription(input.value, keyInfo.key);
    if (current !== revision) return;
    output.value = encrypted;
    result.hidden = false;
    copy.disabled = false;
    status.textContent = 'Your encrypted link is ready.';
    output.focus();
  } catch {
    if (current === revision) error.textContent = 'Encryption failed. Please try again.';
  } finally {
    busy = false;
    submit.disabled = !keyInfo;
    submit.textContent = 'Encrypt URL';
    form.removeAttribute('aria-busy');
  }
});

copy.addEventListener('click', async () => {
  const encrypted = output.value;
  if (!encrypted) return;
  const current = revision;
  try {
    await navigator.clipboard.writeText(encrypted);
    if (current === revision) status.textContent = 'Encrypted link copied.';
  } catch {
    if (current !== revision) return;
    output.focus();
    output.select();
    status.textContent = 'Automatic copying is unavailable. Copy the selected link manually.';
  }
});

async function initialize() {
  try {
    if (!globalThis.isSecureContext || !crypto.subtle) throw new Error('Secure context required.');
    const response = await fetch(new URL('./public.pem', import.meta.url), {
      cache: 'no-store', credentials: 'omit', redirect: 'error', mode: 'same-origin',
    });
    if (!response.ok) throw new Error('Public key unavailable.');
    keyInfo = await importPublicKey(await response.text());
    document.querySelector('#key-fingerprint').textContent = keyInfo.fingerprint;
    document.querySelector('#key-size').textContent = `${keyInfo.key.algorithm.modulusLength}-bit RSA`;
    document.querySelector('#max-bytes').textContent = `${keyInfo.maxBytes} UTF-8 bytes`;
    keyStatus.textContent = 'Ready to encrypt';
    keyStatus.classList.add('ready');
    invalidate();
  } catch {
    keyStatus.textContent = 'Encryption unavailable';
    error.textContent = 'Could not load encryption. Open this page over HTTPS in a current browser, then reload.';
    submit.disabled = true;
  }
}

initialize();
