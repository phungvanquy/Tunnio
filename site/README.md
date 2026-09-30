# Subscription encryption page

This static page uses Web Crypto to create `tunnio-rsa:` links with RSA-OAEP/SHA-256,
SHA-256 MGF1, an empty label, and unpadded Base64URL ciphertext. URLs remain in browser
memory; the page makes no request to the subscription provider and uses no analytics,
external scripts, or persistent browser storage. It needs HTTPS or localhost.

The deployed page lives at https://phungvanquy.github.io/Tunnio/ after Pages is enabled
and the workflow reaches `main`. GitHub Pages serves the page; it does not perform
encryption. The public key is intentionally downloadable. The private key belongs only
in the app build configuration, never in this directory or the Pages workflow.

## Development and verification

Requires Node.js 24; no npm dependencies or frontend build tools are needed.

```bash
node --test test/site/*.test.mjs
node tool/build_pages.mjs
python3 -m http.server 8080 --directory build/pages
```

Open http://localhost:8080. Tests generate temporary RSA key pairs and verify that
browser ciphertext decrypts with OpenSSL through Node's crypto API. They also cover
UTF-8 length limits, malformed inputs, UI state, and the deployment file allowlist.

## Deployment

In **Settings → Pages → Build and deployment → Source**, select **GitHub Actions**.
Restrict the `github-pages` environment to `main` in **Settings → Environments**.
The workflow independently guards deployment to `refs/heads/main`, including manual
runs. Other branches and pull requests run verification only. Pages uses its built-in
workflow token and needs no private-key secret or token for another repository.

Changes to `site/**`, `test/site/**`, `tool/build_pages.mjs`, or the Pages workflow
trigger validation. Pushes to `main` also deploy after validation passes; manual runs
on `main` can redeploy. Ordinary app changes do not deploy Pages. Page-only commits
skip the application packaging workflow; mixed changes and release tags still run it.
The upload contains only six explicitly selected files staged in `build/pages/`.

## Public key updates

The initial public key was copied from `/root/tunnio-keys/public.pem`. GitHub cannot
watch that local path. To update it, copy and commit the public file:

```bash
cp /root/tunnio-keys/public.pem site/encrypt/public.pem
node --test test/site/*.test.mjs
```

Use the key paired with the private key in the intended Tunnio builds. Coordinate
rotation with app releases: the current `tunnio-rsa:` format has no key identifier,
and old app builds cannot decrypt links made with a replacement key. The page displays
the SHA-256 fingerprint of the SPKI DER public key so maintainers can compare keys.
With the initial 3072-bit key, the URL limit is 318 UTF-8 bytes.
