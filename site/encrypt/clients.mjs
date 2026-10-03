import { encryptSubscription, subscriptionBytes } from './crypto.mjs';
import { encryptLink } from './vendor/incy/web.mjs';

export const happEndpoint = 'https://crypto.happ.su/api-v2.php';
export const maxExternalUrlBytes = 8192;

const linkPatterns = {
  tunnio: /^tunnio-rsa:[A-Za-z0-9_-]+$/,
  // Happ's crypt5 payload can include a marker after Base64 padding.
  happ: /^happ:\/\/crypt5\/[A-Za-z0-9+/_-][A-Za-z0-9+/_=-]*$/,
  incy: /^incy:\/\/crypt1\/[A-Za-z0-9_-]+$/,
};

export function isEncryptedLink(link, target) {
  return typeof link === 'string' && link.length <= 32768 &&
    (target ? linkPatterns[target]?.test(link) === true :
      Object.values(linkPatterns).some((pattern) => pattern.test(link)));
}

async function encryptHapp(url, signal) {
  const controller = new AbortController();
  const cancel = () => controller.abort();
  signal?.addEventListener('abort', cancel, { once: true });
  if (signal?.aborted) cancel();
  const timeout = setTimeout(cancel, 15000);
  try {
    // Happ accepts JSON as text/plain; application/json requires a preflight its API rejects.
    const response = await fetch(happEndpoint, {
      method: 'POST', mode: 'cors', credentials: 'omit', cache: 'no-store',
      redirect: 'error', referrerPolicy: 'no-referrer', signal: controller.signal,
      headers: { 'Content-Type': 'text/plain;charset=UTF-8' },
      body: JSON.stringify({ url }),
    });
    if (!response.ok) throw new Error('Happ request failed.');
    const data = await response.json();
    if (!isEncryptedLink(data?.encrypted_link, 'happ')) throw new Error('Invalid Happ response.');
    return data.encrypted_link;
  } catch {
    throw new Error('Happ could not encrypt this URL. The request failed or timed out. Try again or use the official Happ generator below.');
  } finally {
    clearTimeout(timeout);
    signal?.removeEventListener('abort', cancel);
  }
}

export async function encryptForApp(input, target, keyInfo, signal) {
  if (!Object.hasOwn(linkPatterns, target)) throw new Error('Choose a supported app.');
  if (target === 'tunnio') {
    if (!keyInfo) throw new Error('Tunnio public key unavailable.');
    return encryptSubscription(input, keyInfo.key);
  }
  const bytes = subscriptionBytes(input, maxExternalUrlBytes);
  const url = new TextDecoder().decode(bytes);
  if (signal?.aborted) throw new Error('Encryption cancelled.');
  return target === 'incy' ? encryptLink(url) : encryptHapp(url, signal);
}
