export const encryptedPrefix = 'tunnio-rsa:';

export async function importPublicKey(pem) {
  const match = pem.trim().match(
    /^-----BEGIN PUBLIC KEY-----\s+([A-Za-z0-9+/=\s]+)\s+-----END PUBLIC KEY-----$/,
  );
  if (!match) throw new Error('Invalid RSA public key.');
  const der = Uint8Array.from(atob(match[1].replace(/\s/g, '')), (char) => char.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    'spki', der, { name: 'RSA-OAEP', hash: 'SHA-256' }, false, ['encrypt'],
  );
  if (key.algorithm.modulusLength < 2048) throw new Error('RSA key is too small.');
  const digest = new Uint8Array(await crypto.subtle.digest('SHA-256', der));
  const fingerprint = Array.from(digest, (byte) => byte.toString(16).padStart(2, '0')).join('');
  return {
    key,
    maxBytes: key.algorithm.modulusLength / 8 - 66,
    fingerprint,
  };
}

export function subscriptionBytes(input, maxBytes) {
  const url = input.trim();
  if (!url) throw new Error('Enter a subscription URL.');
  if (!/^https?:\/\/[^/?#]/i.test(url) || /[\s\x00-\x1f\x7f\\]/.test(url) || /%(?![0-9a-f]{2})/i.test(url)) {
    throw new Error('Enter one valid HTTP or HTTPS subscription URL.');
  }
  let parsed;
  try {
    parsed = new URL(url);
  } catch {
    throw new Error('Enter one valid HTTP or HTTPS subscription URL.');
  }
  if (!parsed.hostname || parsed.hostname.includes(',') || parsed.port === '0') {
    throw new Error('Enter one valid HTTP or HTTPS subscription URL.');
  }
  const bytes = new TextEncoder().encode(url);
  if (bytes.length > maxBytes) {
    throw new Error(`This URL is ${bytes.length} bytes. Use a shorter URL of ${maxBytes} bytes or fewer.`);
  }
  return bytes;
}

export async function encryptSubscription(input, key) {
  const bytes = subscriptionBytes(input, key.algorithm.modulusLength / 8 - 66);
  const ciphertext = await crypto.subtle.encrypt({ name: 'RSA-OAEP' }, key, bytes);
  const encoded = btoa(String.fromCharCode(...new Uint8Array(ciphertext)))
    .replaceAll('+', '-').replaceAll('/', '_').replace(/=+$/, '');
  return encryptedPrefix + encoded;
}
