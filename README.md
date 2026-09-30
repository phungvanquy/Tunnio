<div>

[**简体中文**](README_zh_CN.md)

</div>

## Tunnio

Tunnio is an open-source, ad-free proxy client based on ClashMeta. Its Core is maintained in [Tunnio-core](https://github.com/phungvanquy/Tunnio-core). Test builds are available from [GitHub Actions](https://github.com/phungvanquy/Tunnio/actions).

[![Downloads](https://img.shields.io/github/downloads/phungvanquy/Tunnio/total?style=flat-square&logo=github)](https://github.com/phungvanquy/Tunnio/releases/)[![Last Version](https://img.shields.io/github/release/phungvanquy/Tunnio/all.svg?style=flat-square)](https://github.com/phungvanquy/Tunnio/releases/)[![License](https://img.shields.io/github/license/phungvanquy/Tunnio?style=flat-square)](LICENSE)

A simple proxy client for Android, Windows, macOS, and Linux.

<p align="center">
    <img alt="Tunnio" src="assets/images/icon.png" width="128">
</p>

## Features

✈️ Multi-platform: Android, Windows, macOS and Linux

💻 Adaptive multiple screen sizes, Multiple color themes available

💡 Based on Material You Design, [Surfboard](https://github.com/getsurfboard/surfboard)-like UI

🔒 Simplified settings keep subscription links and configuration exports out of view

✨ Support plain and RSA-encrypted subscription links, Dark mode

## Use

### Quick start

1. Import a plain HTTP(S) subscription URL or a `tunnio-rsa:` encrypted link by QR code, **Paste from clipboard**, or manual entry.
2. Choose **Auto**, **Fallback**, or a server from Home's single list.
3. Press the large circular button to connect; press it again to disconnect. Grant VPN/TUN permission if requested.

Connected is green; disconnected is gray. **Test latency** measures the servers and highlights the fastest without changing your selection. Connection transitions and latency tests show progress and prevent repeated submissions.

The app keeps one profile. A successful import replaces it; a failed import keeps your saved setup. Settings contains import/replace, refresh, recovery, language, theme, and essential app preferences. Subscription/provider-list refresh pauses when Flutter is closed; the current native VPN configuration and health checks continue.

### Encrypted subscription links

Tunnio accepts `tunnio-rsa:<unpadded base64url ciphertext>`. The ciphertext is an HTTP(S) URL encoded as UTF-8 and encrypted with RSA-OAEP using SHA-256 for both OAEP and MGF1. The app saves the encrypted link and decrypts it when downloading or refreshing. Plain HTTP(S) URLs remain supported.

Generate a key pair locally. Keep the private key out of version control; distribute the public key to whoever creates links.

```bash
mkdir -p .local-keys
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:3072 -out .local-keys/private.pem
openssl pkey -in .local-keys/private.pem -pubout -out .local-keys/public.pem
python3 - <<'PY'
import base64, json
from pathlib import Path

private_key = Path('.local-keys/private.pem').read_bytes()
Path('env.local.json').write_text(json.dumps({
    'VPN_RSA_PRIVATE_KEY_B64': base64.b64encode(private_key).decode('ascii'),
}))
PY
```

Run `python3 tool/encrypt_subscription_url.py --public-key .local-keys/public.pem`, enter one URL on stdin, and copy the printed link into Tunnio. The normal `dart setup.dart <platform>` build merges the ignored `env.local.json` into its generated `env.json`. For direct Flutter builds, pass `--dart-define-from-file=env.local.json`. For GitHub Actions release builds, set the repository secret `VPN_RSA_PRIVATE_KEY_B64` to the base64 encoded PEM; the build workflow passes it to every platform package. A build without a key still imports plain URLs; it reports a missing key for encrypted links.

RSA-OAEP encrypts only short URLs directly: a 3072-bit key accepts at most 318 UTF-8 bytes. Use a short subscription URL when needed. Existing encrypted links need the same private key for later refreshes; replacing the key requires reimporting links encrypted for the new public key. The bundled key and downloaded configuration can be extracted by someone with device or binary access, so this feature conceals the URL from normal app use rather than securing it against device inspection.

See [VPN setup, routing, and migration](VPN_GUIDE.md) for connection-state meanings and recovery details.

### Linux

⚠️ Make sure to install the following dependencies before using them

   ```bash
    sudo apt-get install libayatana-appindicator3-dev
   ```

### Android

APK builds do not require a Play Store account. Without the `KEYSTORE` GitHub Actions
secret, CI uses debug signing and the `com.follow.clash.dev` application ID, including
tagged builds. This installs alongside the release-signed app. APKs from different CI
runs may require reinstalling because their debug keys can differ. For consistent
upgrades, configure `KEYSTORE` (base64 keystore), `KEY_ALIAS`, `STORE_PASSWORD`, and
`KEY_PASSWORD` in Actions secrets; these are separate from the subscription RSA key.

Support the following actions

   ```bash
    com.follow.clash.action.START
    
    com.follow.clash.action.STOP
    
    com.follow.clash.action.TOGGLE
   ```

## Download

Download installers from [Tunnio Releases](https://github.com/phungvanquy/Tunnio/releases), or test builds from [GitHub Actions](https://github.com/phungvanquy/Tunnio/actions).

Download filenames start with `Tunnio-`. Existing application IDs and data locations are retained; Android upgrades also require the same signing key.

## Build

1. Update submodules
   ```bash
   git submodule update --init --recursive
   ```

2. Install `Flutter` and `Golang` environment

3. Build Application

    - android

        1. Install `Android SDK`, `Android NDK`

        2. Set `ANDROID_NDK` environment variable

        3. Run build script

           ```bash
           dart setup.dart android
           ```

    - windows

        1. Requires a Windows client

        2. Install `GCC`, `Inno Setup`

        3. Run build script

           ```bash
           dart setup.dart windows
           ```

    - linux

        1. Requires a Linux client

        2. Dependencies are auto-installed by setup script, or manually:
           ```bash
           sudo apt-get install -y libayatana-appindicator3-dev
           ```

        3. Run build script

           ```bash
           dart setup.dart linux
           ```

    - macOS

        1. Requires a macOS client

        2. Run build script

           ```bash
           dart setup.dart macos
           ```

## Star

The easiest way to support developers is to click on the star (⭐) at the top of the page.

<p style="text-align: center;">
    <a href="https://api.star-history.com/svg?repos=phungvanquy/Tunnio&Date">
        <img alt="start" width=50% src="https://api.star-history.com/svg?repos=phungvanquy/Tunnio&Date"/>
    </a>
</p>
