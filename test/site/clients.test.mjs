import assert from 'node:assert/strict';
import { createDecipheriv, createHash } from 'node:crypto';
import { test } from 'node:test';
import { readFile } from 'node:fs/promises';
import { encryptForApp, happEndpoint, isEncryptedLink, maxExternalUrlBytes } from '../../site/encrypt/clients.mjs';
import { encryptLinkDeterministic } from '../../site/encrypt/vendor/incy/web.mjs';
import { keySeed } from '../../site/encrypt/vendor/incy/chunk-BY42UVC3.mjs';

const url = 'https://example.test/sub?token=a%2Fb&name=café';
const happLink = 'happ://crypt5/' + 'a'.repeat(128) + '+/=ff';

function decodeIncy(link) {
  const wire = Buffer.from(link.slice('incy://crypt1/'.length), 'base64url');
  const key = createHash('sha256').update(keySeed()).digest();
  const decipher = createDecipheriv('aes-256-gcm', key, wire.subarray(0, 12));
  decipher.setAuthTag(wire.subarray(-16));
  return JSON.parse(Buffer.concat([decipher.update(wire.subarray(12, -16)), decipher.final()]).toString());
}

test('INCY matches the official cross-platform reference vector', async () => {
  const link = await encryptLinkDeterministic('https://sub.example.com/test-vector', {
    iv: Buffer.from('000102030405060708090a0b', 'hex'),
  });
  assert.equal(link, 'incy://crypt1/AAECAwQFBgcICQoLNyIQL3rDwRZqnyoD8pGKSLXP6o8NdSXQVSSALNbbUyIr__tWGFUexdIfKvvmDnuDGbmBvuppfNef6aKNZUwOm4c-Sg');
});

test('INCY output decrypts independently with OpenSSL and uses fresh random IVs', async (context) => {
  context.mock.method(globalThis, 'fetch', () => assert.fail('INCY must stay local'));
  const first = await encryptForApp(` ${url}\n`, 'incy');
  const second = await encryptForApp(url, 'incy');
  assert.equal(isEncryptedLink(first, 'incy'), true);
  assert.deepEqual(decodeIncy(first), { url, v: 1 });
  assert.deepEqual(decodeIncy(second), { url, v: 1 });
  assert.notEqual(first, second);
});

test('Happ sends only the original URL to the fixed API without cookies, redirects, or preflight', async (context) => {
  const request = context.mock.method(globalThis, 'fetch', async (endpoint, options) => {
    assert.equal(endpoint, happEndpoint);
    assert.equal(options.method, 'POST');
    assert.equal(options.mode, 'cors');
    assert.equal(options.credentials, 'omit');
    assert.equal(options.cache, 'no-store');
    assert.equal(options.redirect, 'error');
    assert.equal(options.referrerPolicy, 'no-referrer');
    assert.deepEqual(options.headers, { 'Content-Type': 'text/plain;charset=UTF-8' });
    assert.deepEqual(JSON.parse(options.body), { url });
    return { ok: true, json: async () => ({ encrypted_link: happLink }) };
  });
  assert.equal(await encryptForApp(` ${url}\n`, 'happ'), happLink);
  assert.equal(request.mock.callCount(), 1);
});

test('invalid, oversized, encrypted, and cancelled input never reaches Happ', async (context) => {
  context.mock.method(globalThis, 'fetch', () => assert.fail('Unexpected upload'));
  for (const input of ['', 'file:///private', 'https://example.test/a b', happLink,
    'https://example.test/' + 'é'.repeat(maxExternalUrlBytes / 2)]) {
    await assert.rejects(encryptForApp(input, 'happ'));
  }
  await assert.rejects(encryptForApp(url, 'happ', undefined, AbortSignal.abort()), /cancelled/);
  await assert.rejects(encryptForApp(url, 'unknown'), /supported app/);
});

test('Happ rejects error responses, raw URLs, wrong schemes, and malformed links without reflecting response data', async (context) => {
  const responses = [
    { ok: false },
    { ok: true, json: async () => { throw new Error(url); } },
    ...[null, {}, { encrypted_link: url }, { encrypted_link: 'javascript:alert(1)' },
      { encrypted_link: 'incy://crypt1/abc' }, { encrypted_link: 'happ://crypt4/abc' },
      { encrypted_link: happLink + '\n' }, { encrypted_link: happLink + '?url=' + url },
      { encrypted_link: 'happ://crypt5/' }, { encrypted_link: happLink.repeat(1000) },
    ].map((data) => ({ ok: true, json: async () => data })),
  ];
  const request = context.mock.method(globalThis, 'fetch');
  for (const response of responses) {
    request.mock.mockImplementation(async () => response);
    await assert.rejects(encryptForApp(url, 'happ'), (error) => {
      assert.match(error.message, /Happ could not encrypt/);
      assert.ok(!error.message.includes(url));
      return true;
    });
  }
});

for (const reason of ['cancel', 'timeout']) {
  test(`Happ ${reason} aborts the request`, async (context) => {
    context.mock.timers.enable({ apis: ['setTimeout'] });
    let requestSignal;
    context.mock.method(globalThis, 'fetch', (_endpoint, { signal }) => {
      requestSignal = signal;
      return new Promise((_resolve, reject) => {
        signal.addEventListener('abort', () => reject(new Error('aborted')), { once: true });
      });
    });
    const controller = new AbortController();
    const pending = encryptForApp(url, 'happ', undefined, controller.signal);
    const rejected = assert.rejects(pending, /Happ could not encrypt/);
    if (reason === 'cancel') controller.abort();
    else context.mock.timers.tick(15000);
    await rejected;
    assert.equal(requestSignal.aborted, true);
  });
}

test('vendored INCY browser entry has no network, storage, or external imports', async () => {
  for (const file of ['web.mjs', 'chunk-BY42UVC3.mjs']) {
    const source = await readFile(new URL(`../../site/encrypt/vendor/incy/${file}`, import.meta.url), 'utf8');
    assert.doesNotMatch(source, /\b(?:fetch|XMLHttpRequest|localStorage|sessionStorage|indexedDB)\b/);
    for (const match of source.matchAll(/from "([^"]+)"/g)) assert.ok(match[1].startsWith('./'));
  }
});

test('INCY assets match the reviewed 1.3.0 package', async () => {
  const hashes = {
    'web.mjs': 'ccb155f8f20d09ecfe53ac971020d23818662a789bb309519ec045716df5e2ca',
    'chunk-BY42UVC3.mjs': 'e105df5efc5dec1db4514bea0f4666da728feec66b37b52dbf5d3f3c3677222c',
    LICENSE: '385b2f1f8944fee3e59c768307fe213dd305b457c194514316e28a8af91d35f5',
  };
  for (const [file, expected] of Object.entries(hashes)) {
    const bytes = await readFile(new URL(`../../site/encrypt/vendor/incy/${file}`, import.meta.url));
    assert.equal(createHash('sha256').update(bytes).digest('hex'), expected, file);
  }
});
