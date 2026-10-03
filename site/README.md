# Subscription tools

This static page creates links for Tunnio (the default), Happ, and INCY. It needs HTTPS
or localhost and uses no analytics, external scripts, or persistent browser storage.
It never fetches the subscription itself or converts the subscription's contents.

| App | Format | Where generation happens |
| --- | --- | --- |
| Tunnio | `tunnio-rsa:`; RSA-OAEP/SHA-256, SHA-256 MGF1, empty label, unpadded Base64URL | Browser, using `public.pem` |
| Happ | `happ://crypt5/` | Happ's official encryption API, on explicit submission |
| INCY | `incy://crypt1/`; AES-256-GCM | Browser, using the official INCY encoder |

Every result includes a locally generated QR code of the exact link and a copy button.
Happ and INCY also have an app-opening link. Editing the input, switching apps, or
clearing removes the result, QR, and app-opening link and cancels pending requests.
Leaving the page clears the input; late completions cannot restore an old result.
Cancellation cannot recall a URL already received by Happ.

The deployed page lives at https://phungvanquy.github.io/Tunnio/. GitHub Pages serves
the page; it does not perform encryption. The Tunnio public key is intentionally
downloadable. Its private key belongs only in the app build configuration, never in
this directory or the Pages workflow.

## Happ API

The form discloses that the full original URL, including subscription tokens, is sent
to Happ. Selecting Happ or typing never sends it; **Send to Happ & encrypt** submits
one request to `https://crypto.happ.su/api-v2.php`. The request has no cookies or
referrer, refuses redirects, and times out after 15 seconds. Failures never fall back
to an unencrypted URL. Only a bounded `happ://crypt5/` result is accepted.

Happ's endpoint accepts the JSON body with `Content-Type: text/plain;charset=UTF-8`.
This is intentional: its JSON-content-type preflight returns HTTP 405. A simple POST
returns `Access-Control-Allow-Origin: *`; the browser integration was verified with
an `example.com` URL. Recheck this behavior when updating the integration. Do not use
`no-cors`, a third-party CORS proxy, or automatic fallback to a different endpoint.
The page links to Happ's official generator if its API becomes unavailable.
Treat the returned payload as opaque: current `crypt5` links can append a marker
after Base64 padding, such as `=ff`. Do not trim, re-encode, or remove that suffix.

The CSP permits only this API path in addition to the page's own origin. All scripts,
styles, keys, and QR generation remain local assets. See
[Happ's official documentation](https://www.happ.su/main/dev-docs/crypto-link).

## INCY and subscription compatibility

INCY's encoder is designed for URL obfuscation. Its shared key is public, and the
official package includes a decoder. `crypt1` alone does not prevent forwarding or
recovering the URL. To disable normal URL sharing, QR display, and subscription
backups inside INCY, configure the subscription server to return `hide-url: 1`
(or the documented `#hide-url: 1` body marker). This page cannot set response headers
on your subscription server. See [INCY deep links](https://docs.incy.cc/en/deep-links/)
and [URL hiding](https://docs.incy.cc/en/app-management/#hiding-the-subscription-url-from-the-user).

Use an updated INCY client with `crypt1` support. Both Happ and INCY need a compatible
subscription response; wrapping a Clash/Mihomo YAML URL does not convert it into
server links or Xray JSON. Configure the provider's appropriate endpoint before
generating the link and verify import and refresh on the intended devices. The page
limits Happ and INCY inputs to 8192 UTF-8 bytes; this is a page limit, not a guarantee
that Happ or every QR scanner accepts that size. Links too large for a QR remain
available to copy. Subscription expiry and access limits belong on the server.

## Development and verification

Requires Node.js 24; no npm dependencies or frontend build tools are needed.

```bash
node --test test/site/*.test.mjs
node tool/build_pages.mjs
python3 -m http.server 8080 --directory build/pages
```

Open http://localhost:8080. Tests generate temporary RSA key pairs and verify that
browser ciphertext decrypts with OpenSSL through Node's crypto API. They also cover
INCY's official reference vector, Happ request policy, cancellation and timeout,
malformed responses, UTF-8 length limits, UI state, workflow path filters, and the
deployment file allowlist. CI tests mock Happ and never send subscription URLs.

The page icon is generated from `assets/images/icon.png` alongside the app icons.
After replacing that square source image, run `dart run tool/generate_status_icons.dart`
and commit all generated assets, including `site/encrypt/icon.png`.

## Deployment

In **Settings → Pages → Build and deployment → Source**, select **GitHub Actions**.
Restrict the `github-pages` environment to `main` in **Settings → Environments**.
The workflow independently guards deployment to `refs/heads/main`, including manual
runs. Other branches and pull requests run verification only. Pages uses its built-in
workflow token and needs no private-key secret or token for another repository.

Changes to `site/**`, `test/site/**`, `tool/build_pages.mjs`, or either the Pages or
app build workflow trigger page validation. Pushes to `main` also deploy after
validation passes; manual runs on `main` can redeploy. Ordinary app changes do not
deploy Pages. Page-only commits
skip the application packaging workflow; mixed changes and release tags still run it.
The upload contains only explicitly selected public files staged in `build/pages/`.
The Pages workflow uses only Node.js and GitHub's Pages actions; it does not install
Flutter, Go, Java, or the app's dependencies. Its path-filter tests ensure page-only
changes are excluded from `build.yaml` while mixed changes, release tags, and manual
app builds retain their normal behavior.

## INCY library

`site/encrypt/vendor/incy/` contains unmodified `dist/web.mjs`,
`dist/chunk-BY42UVC3.mjs`, and `LICENSE` from the MIT-licensed
[`@incy/link-encoder` 1.3.0](https://github.com/INCY-DEV/incy-link-encoder).
The browser entry uses Web Crypto with no runtime dependencies or network requests.
The npm tarball's verified integrity is:

```text
sha512-Fa/We3cDwKaS/LhfMP3LWq8rZ6p2APiSc5v08I7XLJXvM3uZPDdg1J5x038VGgojrB89pevyF2uozKC7y1NezA==
```

When upgrading, review the upstream browser module and its shared chunk, preserve
the license, and update the deployment allowlist and integrity assertions together.
The official deterministic vector is pinned in `test/site/clients.test.mjs`.

## QR library

The page bundles `qrcode-generator` 2.0.4 under its MIT license, with no CDN requests.
`site/encrypt/vendor/qrcode.mjs` and its license are unmodified copies from
[upstream commit 83b7e8f](https://github.com/kazuhikoarase/qrcode-generator/tree/83b7e8fe3fddd3b0368dbafd6ce56995bd25e3c8).
QR codes use byte mode, medium error correction, and a four-module white border.

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
