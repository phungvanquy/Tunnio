import assert from 'node:assert/strict';
import { generateKeyPairSync, privateDecrypt } from 'node:crypto';
import { test } from 'node:test';
import { setTimeout as delay } from 'node:timers/promises';
import { Canvas } from './canvas.mjs';

const nativeCrypto = globalThis.crypto;
const pair = generateKeyPairSync('rsa', { modulusLength: 2048 });
const pem = pair.publicKey.export({ type: 'spki', format: 'pem' });
let instance = 0;

class Element {
  value = '';
  textContent = '';
  disabled = false;
  hidden = false;
  attributes = new Map();
  listeners = new Map();
  classes = new Set();
  classList = {
    add: (name) => this.classes.add(name),
    toggle: (name, enabled) => enabled ? this.classes.add(name) : this.classes.delete(name),
  };
  addEventListener(name, listener) { this.listeners.set(name, listener); }
  emit(name, event = {}) { return this.listeners.get(name)?.({ preventDefault() {}, ...event }); }
  setAttribute(name, value) { this.attributes.set(name, value); }
  removeAttribute(name) { this.attributes.delete(name); }
  focus() { this.focused = true; }
  select() { this.selected = true; }
}

async function page(context, { encrypt, clipboard, keyAvailable = true, secure = true, canvasAvailable = true } = {}) {
  const names = ['document', 'window', 'fetch', 'navigator', 'crypto', 'isSecureContext'];
  const previous = new Map(names.map((name) => [name, Object.getOwnPropertyDescriptor(globalThis, name)]));
  context.after(() => {
    for (const [name, descriptor] of previous) {
      if (descriptor) Object.defineProperty(globalThis, name, descriptor);
      else delete globalThis[name];
    }
  });
  const ids = [
    'encrypt-form', 'subscription', 'encrypt', 'clear', 'byte-count', 'input-error',
    'result', 'encrypted-link', 'copy', 'status', 'key-status', 'key-size',
    'key-fingerprint', 'max-bytes', 'qr-result', 'qr-error',
  ];
  const elements = Object.fromEntries(ids.map((id) => [id, new Element()]));
  elements['qr-code'] = new Canvas();
  if (!canvasAvailable) elements['qr-code'].getContext = () => null;
  const requests = [];
  const copied = [];
  const window = new Element();
  elements.encrypt.disabled = true;
  elements.result.hidden = true;
  elements['qr-result'].hidden = true;
  elements['key-status'].textContent = 'Loading public key…';
  elements['encrypt-form'].reset = () => {
    elements.subscription.value = '';
    elements['encrypted-link'].value = '';
  };
  const globals = {
    document: { querySelector: (selector) => elements[selector.slice(1)] },
    window,
    isSecureContext: secure,
    navigator: { clipboard: { writeText: clipboard ?? (async (value) => copied.push(value)) } },
    fetch: async (url, options) => {
      requests.push({ url, options });
      assert.ok(url.pathname.endsWith('/public.pem'));
      return { ok: keyAvailable, text: async () => pem };
    },
    crypto: {
      subtle: {
        importKey: (...args) => nativeCrypto.subtle.importKey(...args),
        digest: (...args) => nativeCrypto.subtle.digest(...args),
        encrypt: encrypt ?? ((...args) => nativeCrypto.subtle.encrypt(...args)),
      },
    },
  };
  for (const [name, value] of Object.entries(globals)) {
    Object.defineProperty(globalThis, name, { value, configurable: true });
  }
  await import(`../../site/encrypt/app.mjs?test=${instance++}`);
  for (let attempt = 0; attempt < 100 && elements['key-status'].textContent.startsWith('Loading'); attempt += 1) {
    await delay(10);
  }
  assert.notEqual(elements['key-status'].textContent, 'Loading public key…');
  return { elements, requests, copied, window };
}

test('encrypts, copies, and clears without requesting or storing the input URL', async (context) => {
  const { elements: ui, requests, copied, window } = await page(context);
  ui.subscription.value = 'https://example.test/private?token=secret';
  ui.subscription.emit('input');
  await ui['encrypt-form'].emit('submit');
  assert.equal(ui.result.hidden, false);
  assert.equal(ui['qr-result'].hidden, false);
  assert.ok(ui['qr-code'].rectangles.length > 100);
  const token = ui['encrypted-link'].value;
  const decoded = privateDecrypt({ key: pair.privateKey, oaepHash: 'sha256' }, Buffer.from(token.slice(11), 'base64url'));
  assert.equal(decoded.toString(), ui.subscription.value);
  await ui.copy.emit('click');
  assert.deepEqual(copied, [token]);
  assert.match(ui.status.textContent, /copied/);
  assert.equal(requests.length, 1);
  assert.equal(requests[0].options.credentials, 'omit');
  assert.equal(requests[0].options.cache, 'no-store');
  window.emit('pagehide');
  assert.equal(ui.subscription.value, '');
  assert.equal(ui['encrypted-link'].value, '');
  assert.equal(ui.result.hidden, true);
  assert.equal(ui['qr-result'].hidden, true);
  assert.equal(ui['qr-code'].width, 0);
  assert.equal(ui['qr-code'].height, 0);
  assert.deepEqual(ui['qr-code'].rectangles, []);
});

test('rejects invalid input and clears an earlier encrypted result on editing', async (context) => {
  const { elements: ui } = await page(context);
  ui.subscription.value = 'https://example.test/sub';
  await ui['encrypt-form'].emit('submit');
  ui.subscription.value = 'file:///private';
  ui.subscription.emit('input');
  assert.equal(ui.result.hidden, true);
  assert.equal(ui.copy.disabled, true);
  assert.equal(ui['qr-result'].hidden, true);
  assert.deepEqual(ui['qr-code'].rectangles, []);
  await ui['encrypt-form'].emit('submit');
  assert.match(ui['input-error'].textContent, /HTTP or HTTPS/);
  assert.equal(ui.subscription.attributes.get('aria-invalid'), 'true');
});

for (const action of ['edit', 'clear']) {
  test(`${action} during encryption discards the stale result`, async (context) => {
    let finish;
    const encryption = new Promise((resolve) => { finish = resolve; });
    const { elements: ui } = await page(context, { encrypt: () => encryption });
    ui.subscription.value = 'https://example.test/first';
    const pending = ui['encrypt-form'].emit('submit');
    assert.equal(ui.encrypt.disabled, true);
    if (action === 'clear') ui.clear.emit('click');
    else {
      ui.subscription.value = 'https://example.test/second';
      ui.subscription.emit('input');
    }
    finish(new Uint8Array(256).buffer);
    await pending;
    assert.equal(ui.result.hidden, true);
    assert.equal(ui['encrypted-link'].value, '');
    assert.equal(ui['qr-result'].hidden, true);
    assert.deepEqual(ui['qr-code'].rectangles, []);
    assert.equal(ui.encrypt.disabled, false);
  });
}

test('clipboard denial selects the encrypted link for manual copying', async (context) => {
  const { elements: ui } = await page(context, { clipboard: async () => { throw new Error('denied'); } });
  ui.subscription.value = 'https://example.test/sub';
  await ui['encrypt-form'].emit('submit');
  await ui.copy.emit('click');
  assert.equal(ui['encrypted-link'].selected, true);
  assert.match(ui.status.textContent, /manually/);
});

test('QR rendering failure keeps the encrypted link available to copy', async (context) => {
  const { elements: ui, copied } = await page(context, { canvasAvailable: false });
  ui.subscription.value = 'https://example.test/sub';
  await ui['encrypt-form'].emit('submit');
  assert.equal(ui.result.hidden, false);
  assert.equal(ui['qr-result'].hidden, true);
  assert.match(ui['qr-error'].textContent, /still copy/);
  await ui.copy.emit('click');
  assert.deepEqual(copied, [ui['encrypted-link'].value]);
  ui.clear.emit('click');
  assert.equal(ui['qr-error'].textContent, '');
  assert.equal(ui['qr-code'].width, 0);
});

test('missing public key disables encryption and gives a recoverable error', async (context) => {
  const { elements: ui } = await page(context, { keyAvailable: false });
  assert.equal(ui.encrypt.disabled, true);
  assert.match(ui['input-error'].textContent, /reload/);
  assert.equal(ui.result.hidden, true);
});

test('insecure contexts fail before requesting the key', async (context) => {
  const { elements: ui, requests } = await page(context, { secure: false });
  assert.equal(ui.encrypt.disabled, true);
  assert.equal(requests.length, 0);
  assert.match(ui['input-error'].textContent, /HTTPS/);
});
