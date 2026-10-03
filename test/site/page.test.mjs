import assert from 'node:assert/strict';
import { generateKeyPairSync, privateDecrypt } from 'node:crypto';
import { test } from 'node:test';
import { setTimeout as delay } from 'node:timers/promises';
import { Canvas } from './canvas.mjs';
import { decryptLink } from '../../site/encrypt/vendor/incy/web.mjs';
import { happEndpoint } from '../../site/encrypt/clients.mjs';

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

async function page(context, { encrypt, clipboard, happResponse, keyAvailable = true, secure = true, canvasAvailable = true } = {}) {
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
    'target-app', 'app-hint', 'privacy-note', 'result-title', 'result-hint',
    'open-app', 'tunnio-details', 'happ-details', 'incy-details',
  ];
  const elements = Object.fromEntries(ids.map((id) => [id, new Element()]));
  elements['qr-code'] = new Canvas();
  if (!canvasAvailable) elements['qr-code'].getContext = () => null;
  const requests = [];
  const copied = [];
  const window = new Element();
  elements.encrypt.disabled = true;
  elements['target-app'].value = 'tunnio';
  elements['open-app'].hidden = true;
  elements.result.hidden = true;
  elements['qr-result'].hidden = true;
  elements['key-status'].textContent = 'Loading public key…';
  elements['encrypt-form'].reset = () => {
    elements.subscription.value = '';
    elements['encrypted-link'].value = '';
    elements['target-app'].value = 'tunnio';
  };
  const globals = {
    document: { querySelector: (selector) => elements[selector.slice(1)] },
    window,
    isSecureContext: secure,
    navigator: { clipboard: { writeText: clipboard ?? (async (value) => copied.push(value)) } },
    fetch: async (url, options) => {
      requests.push({ url, options });
      if (url === happEndpoint) {
        return happResponse ? happResponse(url, options) : {
          ok: true, json: async () => ({ encrypted_link: 'happ://crypt5/' + 'a'.repeat(128) }),
        };
      }
      assert.ok(url.pathname.endsWith('/public.pem'));
      return { ok: keyAvailable, text: async () => pem };
    },
    crypto: {
      getRandomValues: (bytes) => nativeCrypto.getRandomValues(bytes),
      subtle: {
        importKey: (...args) => nativeCrypto.subtle.importKey(...args),
        digest: (...args) => nativeCrypto.subtle.digest(...args),
        encrypt: encrypt ?? ((...args) => nativeCrypto.subtle.encrypt(...args)),
        decrypt: (...args) => nativeCrypto.subtle.decrypt(...args),
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

function selectApp(ui, app) {
  ui['target-app'].value = app;
  ui['target-app'].emit('change');
}

test('INCY works without a Tunnio key, stays local, and updates import and QR controls', async (context) => {
  const { elements: ui, requests, copied } = await page(context, { keyAvailable: false });
  selectApp(ui, 'incy');
  assert.equal(ui.encrypt.disabled, false);
  assert.equal(ui['input-error'].textContent, '');
  assert.match(ui['app-hint'].textContent, /public encoder/);
  assert.equal(ui['incy-details'].hidden, false);
  assert.equal(ui['tunnio-details'].hidden, true);
  ui.subscription.value = 'https://example.test/sub';
  await ui['encrypt-form'].emit('submit');
  const link = ui['encrypted-link'].value;
  assert.equal((await decryptLink(link)).url, ui.subscription.value);
  assert.equal(ui['qr-result'].hidden, false);
  assert.equal(ui['open-app'].attributes.get('href'), link);
  assert.match(ui['result-hint'].textContent, /INCY/);
  await ui.copy.emit('click');
  assert.deepEqual(copied, [link]);
  assert.equal(requests.length, 1);
  selectApp(ui, 'tunnio');
  assert.equal(ui.result.hidden, true);
  assert.equal(ui['qr-result'].hidden, true);
  assert.equal(ui['open-app'].hidden, true);
  assert.equal(ui['open-app'].attributes.has('href'), false);
  assert.equal(ui.encrypt.disabled, true);
});

test('Happ uploads only on explicit submit with visible disclosure and produces its own link', async (context) => {
  const { elements: ui, requests } = await page(context);
  selectApp(ui, 'happ');
  assert.equal(ui.encrypt.textContent, 'Send to Happ & encrypt');
  assert.match(ui['privacy-note'].textContent, /access token.*crypto.happ.su/);
  assert.equal(ui['happ-details'].hidden, false);
  ui.subscription.value = 'https://example.test/private';
  ui.subscription.emit('input');
  assert.equal(requests.length, 1);
  await ui['encrypt-form'].emit('submit');
  assert.equal(requests.length, 2);
  assert.match(ui['encrypted-link'].value, /^happ:\/\/crypt5\//);
  assert.equal(ui['qr-result'].hidden, false);
  assert.equal(ui['open-app'].attributes.get('href'), ui['encrypted-link'].value);
  assert.equal(ui.encrypt.textContent, 'Send to Happ & encrypt');
  ui.clear.emit('click');
  assert.equal(ui.subscription.value, '');
  assert.equal(ui['target-app'].value, 'happ');
  assert.equal(ui.result.hidden, true);
  assert.equal(requests.length, 2);
});

for (const action of ['edit', 'switch', 'clear', 'leave']) {
  test(`${action} cancels Happ and discards a late response`, async (context) => {
    let finish;
    let signal;
    const { elements: ui, window } = await page(context, {
      happResponse: (_url, options) => {
        signal = options.signal;
        return new Promise((resolve) => { finish = resolve; });
      },
    });
    selectApp(ui, 'happ');
    ui.subscription.value = 'https://example.test/private';
    const pending = ui['encrypt-form'].emit('submit');
    if (action === 'switch') selectApp(ui, 'incy');
    else if (action === 'clear') ui.clear.emit('click');
    else if (action === 'leave') window.emit('pagehide');
    else {
      ui.subscription.value = 'https://example.test/second';
      ui.subscription.emit('input');
    }
    assert.equal(signal.aborted, true);
    finish({ ok: true, json: async () => ({ encrypted_link: 'happ://crypt5/' + 'a'.repeat(128) }) });
    await pending;
    assert.equal(ui.result.hidden, true);
    assert.equal(ui['open-app'].attributes.has('href'), false);
    assert.equal(ui['encrypted-link'].value, '');
    assert.equal(ui['qr-result'].hidden, true);
    assert.equal(ui.encrypt.disabled, false);
  });
}

test('late Tunnio encryption cannot replace a newer INCY result or reset its controls', async (context) => {
  let finish;
  const { elements: ui } = await page(context, {
    encrypt: (algorithm, ...args) => algorithm.name === 'RSA-OAEP' ?
      new Promise((resolve) => { finish = resolve; }) : nativeCrypto.subtle.encrypt(algorithm, ...args),
  });
  ui.subscription.value = 'https://example.test/first';
  const first = ui['encrypt-form'].emit('submit');
  selectApp(ui, 'incy');
  await ui['encrypt-form'].emit('submit');
  const link = ui['encrypted-link'].value;
  finish(new Uint8Array(256).buffer);
  await first;
  assert.equal(ui['encrypted-link'].value, link);
  assert.match(link, /^incy:\/\/crypt1\//);
  assert.equal(ui.encrypt.textContent, 'Create INCY link');
  assert.equal(ui.result.hidden, false);
});

test('failed Happ requests never fall back to a raw URL or leave stale import controls', async (context) => {
  const { elements: ui } = await page(context, {
    happResponse: async () => ({ ok: true, json: async () => ({ encrypted_link: 'https://example.test/secret' }) }),
  });
  selectApp(ui, 'happ');
  ui.subscription.value = 'https://example.test/secret';
  await ui['encrypt-form'].emit('submit');
  assert.equal(ui.result.hidden, true);
  assert.equal(ui['open-app'].hidden, true);
  assert.match(ui['input-error'].textContent, /official Happ generator/);
  assert.doesNotMatch(ui['input-error'].textContent, /secret/);
  assert.equal(ui.encrypt.disabled, false);
});
