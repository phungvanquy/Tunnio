import {
  EXPECTED_KEY_FINGERPRINT,
  KEY_FINGERPRINT,
  SCHEMES,
  SCHEME_VERSION,
  VERSION,
  assembleLink,
  buildPlaintext,
  bytesToHex,
  concatBytes,
  fingerprintMismatchError,
  keySeed,
  parseLink,
  parsePlaintext
} from "./chunk-BY42UVC3.mjs";

// src/web.ts
var IV_LEN = 12;
var TAG_LEN_BITS = 128;
function bs(u) {
  return u;
}
function subtle() {
  const s = globalThis.crypto?.subtle;
  if (!s) {
    throw new Error(
      "incy-link-encoder/web: WebCrypto (globalThis.crypto.subtle) is not available in this runtime. In Node, use the main entry (`@incy/link-encoder`) instead; in browsers, make sure the page is served over HTTPS or localhost (crypto.subtle is restricted to secure contexts)."
    );
  }
  return s;
}
var keyCache;
function deriveKey() {
  if (keyCache) return keyCache;
  const derived = (async () => {
    const s = subtle();
    const raw = new Uint8Array(await s.digest("SHA-256", bs(keySeed())));
    const fp = bytesToHex(new Uint8Array(await s.digest("SHA-256", raw)));
    if (fp !== EXPECTED_KEY_FINGERPRINT) {
      throw fingerprintMismatchError(fp);
    }
    return s.importKey("raw", raw, { name: "AES-GCM" }, false, ["encrypt", "decrypt"]);
  })();
  keyCache = derived;
  derived.catch(() => {
    keyCache = void 0;
  });
  return derived;
}
async function seal(plaintext, iv) {
  const key = await deriveKey();
  const ctAndTag = new Uint8Array(
    await subtle().encrypt({ name: "AES-GCM", iv: bs(iv), tagLength: TAG_LEN_BITS }, key, bs(plaintext))
  );
  return assembleLink(concatBytes(iv, ctAndTag));
}
async function encryptLink(url, opts = {}) {
  const plaintext = buildPlaintext(url, opts);
  const iv = new Uint8Array(IV_LEN);
  globalThis.crypto.getRandomValues(iv);
  return seal(plaintext, iv);
}
async function encryptLinkDeterministic(url, opts) {
  if (opts.iv.length !== IV_LEN) {
    throw new TypeError("encryptLinkDeterministic: iv must be 12 bytes");
  }
  const plaintext = buildPlaintext(url, opts);
  return seal(plaintext, opts.iv);
}
async function decryptLink(link) {
  const { iv, ct, tag } = parseLink(link);
  const key = await deriveKey();
  let plaintext;
  try {
    plaintext = new Uint8Array(
      await subtle().decrypt(
        { name: "AES-GCM", iv: bs(iv), tagLength: TAG_LEN_BITS },
        key,
        bs(concatBytes(ct, tag))
      )
    );
  } catch {
    throw new Error("decryptLink: authentication failed");
  }
  return parsePlaintext(plaintext);
}
export {
  KEY_FINGERPRINT,
  SCHEMES,
  SCHEME_VERSION,
  VERSION,
  decryptLink,
  encryptLink,
  encryptLinkDeterministic
};
