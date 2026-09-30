import assert from 'node:assert/strict';
import { constants, createHash, generateKeyPairSync, privateDecrypt } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { test } from 'node:test';
import { encryptSubscription, importPublicKey, subscriptionBytes } from '../../site/encrypt/crypto.mjs';

const { publicKey, privateKey } = generateKeyPairSync('rsa', { modulusLength: 3072 });
const pem = publicKey.export({ type: 'spki', format: 'pem' });
const info = await importPublicKey(pem);

function decrypt(token) {
  return privateDecrypt({
    key: privateKey,
    padding: constants.RSA_PKCS1_OAEP_PADDING,
    oaepHash: 'sha256',
  }, Buffer.from(token.slice('tunnio-rsa:'.length), 'base64url')).toString('utf8');
}

test('Web Crypto links decrypt with OpenSSL RSA-OAEP/SHA-256', async () => {
  const url = 'https://example.test/sub?token=a%2Fb&label=café';
  const token = await encryptSubscription(url, info.key);
  assert.match(token, /^tunnio-rsa:[A-Za-z0-9_-]{512}$/);
  assert.equal(decrypt(token), url);
  assert.equal(decrypt(await encryptSubscription(`  ${url}\n`, info.key)), url);
});

test('OAEP produces different ciphertext for the same URL', async () => {
  const first = await encryptSubscription('https://example.test/sub', info.key);
  const second = await encryptSubscription('https://example.test/sub', info.key);
  assert.notEqual(first, second);
  assert.equal(decrypt(first), decrypt(second));
});

test('URL limit uses UTF-8 bytes and permits the exact OAEP boundary', async () => {
  const prefix = 'https://example.test/';
  const url = prefix + 'a'.repeat(info.maxBytes - prefix.length);
  assert.equal(info.maxBytes, 318);
  assert.equal(decrypt(await encryptSubscription(url, info.key)), url);
  assert.throws(() => subscriptionBytes(url + 'a', info.maxBytes), /319 bytes/);
  const unicode = prefix + 'é'.repeat(150);
  assert.ok(unicode.length < 318);
  assert.throws(() => subscriptionBytes(unicode, info.maxBytes), /321 bytes/);
});

test('rejects malformed URLs and existing encrypted tokens', () => {
  for (const url of [
    '', 'tunnio-rsa:abcd', 'file:///config', 'javascript:alert(1)',
    'https:///example.test', 'https:////example.test', 'https://',
    'https://example.test/a b', 'https://example.test/%zz',
    'https://example.test\\sub', 'https://example.test:0/sub',
    'https://example.test:65536/sub', 'https://a,b.test/sub',
    'https://a.test\nhttps://b.test',
  ]) {
    assert.throws(() => subscriptionBytes(url, info.maxBytes), Error, url);
  }
});

test('preserves URL text instead of rewriting escapes or adding a slash', () => {
  for (const url of ['https://example.test', 'HTTP://example.test/a%2fb?x=+&x=%20', 'https://[::1]:443/sub']) {
    assert.equal(new TextDecoder().decode(subscriptionBytes(url, info.maxBytes)), url);
  }
});

test('rejects private PEM, damaged PEM, and undersized public keys', async () => {
  await assert.rejects(importPublicKey(privateKey.export({ type: 'pkcs8', format: 'pem' })));
  await assert.rejects(importPublicKey('-----BEGIN PUBLIC KEY-----\ninvalid\n-----END PUBLIC KEY-----'));
  const weak = generateKeyPairSync('rsa', { modulusLength: 1024 }).publicKey;
  await assert.rejects(importPublicKey(weak.export({ type: 'spki', format: 'pem' })), /too small/);
});

test('the deployed public key is valid and its fingerprint matches SPKI DER', async () => {
  const deployedPem = await readFile(new URL('../../site/encrypt/public.pem', import.meta.url), 'utf8');
  const deployed = await importPublicKey(deployedPem);
  assert.ok(deployed.key.algorithm.modulusLength >= 2048);
  assert.equal(deployed.key.extractable, false);
  const der = Buffer.from(deployedPem.split('\n').filter((line) => !line.startsWith('---')).join(''), 'base64');
  assert.equal(deployed.fingerprint, createHash('sha256').update(der).digest('hex'));
  assert.match(await encryptSubscription('https://example.test/sub', deployed.key), /^tunnio-rsa:[A-Za-z0-9_-]+$/);
});
