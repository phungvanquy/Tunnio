import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import { test } from 'node:test';
import { renderEncryptedQr } from '../../site/encrypt/qr.mjs';
import { Canvas } from './canvas.mjs';

test('QR generation refuses raw URLs', () => {
  const canvas = new Canvas();
  assert.throws(() => renderEncryptedQr(canvas, 'https://example.test/private'), /encrypted/);
  assert.deepEqual(canvas.rectangles, []);
});

test('QR fits RSA ciphertext sizes with a white quiet zone in either page theme', () => {
  for (const bits of [2048, 3072, 4096]) {
    const canvas = new Canvas();
    renderEncryptedQr(canvas, 'tunnio-rsa:' + randomBytes(bits / 8).toString('base64url'));
    assert.equal(canvas.width, canvas.height);
    assert.deepEqual(canvas.rectangles[0], {
      x: 0, y: 0, width: canvas.width, height: canvas.height, color: '#ffffff',
    });
    assert.ok(canvas.rectangles.length > 100);
    for (const square of canvas.rectangles.slice(1)) {
      assert.equal(square.color, '#000000');
      assert.ok(square.x >= 16 && square.y >= 16);
      assert.ok(square.x + square.width <= canvas.width - 16);
      assert.ok(square.y + square.height <= canvas.height - 16);
    }
  }
});
