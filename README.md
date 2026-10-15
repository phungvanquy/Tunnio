<p align="center">
  <img src="assets/images/icon.png" width="96" alt="Tunnio icon">
</p>

<h1 align="center">Tunnio</h1>

<p align="center">A simple, open-source proxy client for Android, Windows, macOS, and Linux.</p>

<p align="center">
  <a href="https://github.com/phungvanquy/Tunnio/releases"><img src="https://img.shields.io/github/v/release/phungvanquy/Tunnio?style=flat-square" alt="Latest release"></a>
  <a href="https://github.com/phungvanquy/Tunnio/actions/workflows/build.yaml"><img src="https://github.com/phungvanquy/Tunnio/actions/workflows/build.yaml/badge.svg" alt="Build status"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-blue?style=flat-square" alt="GPL-3.0 license"></a>
</p>

<p align="center">
  <a href="https://github.com/phungvanquy/Tunnio/releases">Download</a> ·
  <a href="#quick-start">Quick start</a> ·
  <a href="VPN_GUIDE.md">User guide</a> ·
  <a href="README_zh_CN.md">简体中文</a>
</p>

Tunnio brings subscription import, server selection, and connection controls into one focused interface.
It is ad-free, built with Flutter, and powered by a mihomo-based [Tunnio Core](https://github.com/phungvanquy/Tunnio-core).
Bring your own compatible subscription; the app does not provide a VPN service or servers.

<p align="center">
  <img src="snapshots/desktop-dark.png" width="1080" alt="Tunnio in dark mode, showing a demo TUN connection, Auto selection, and server latency results">
</p>

*Demo UI rendered from the current source. Server names, connection states, and latency values are illustrative;
released versions may differ. [View all snapshots and capture instructions](snapshots/README.md).*

## Why Tunnio

- **A focused connection flow.** Import one subscription, choose Auto, Fallback, or a server, then connect.
- **Clear connection states.** Distinguish an active VPN/TUN connection from system-proxy or local-proxy operation.
- **Latency at a glance.** Test servers without changing your selection; compare results directly in the server list.
- **Safer configuration replacement.** Validate new content before committing it and retain the saved setup when an import fails.
- **An adaptable interface.** Material You styling, light and dark themes, adjustable text size, and layouts for phones and desktops.
- **Flexible import.** Paste a subscription link, enter it manually, or import a QR code. Builds configured with a matching key also accept encrypted links.

## Download

Get packaged builds from **[GitHub Releases](https://github.com/phungvanquy/Tunnio/releases)**.
For development builds, open a successful run in **[GitHub Actions](https://github.com/phungvanquy/Tunnio/actions/workflows/build.yaml)**
and download its artifacts. Choose the package matching your operating system and CPU architecture.

Download names begin with `Tunnio-`. Existing application identities and data locations are retained for upgrades.
Android upgrades also require the same signing key; see the [Android signing notes](docs/BUILDING.md#android-signing).
For platform prerequisites and packages you want to build locally, see [Building Tunnio](docs/BUILDING.md).

## Quick start

1. **Import your subscription.** Use **Paste from clipboard**, manual entry, or a QR code. Android supports camera scanning
   and QR images; desktop supports QR image files.
2. **Choose a server.** **Auto** chooses a responsive server. **Fallback** uses the first healthy server in source order.
   Selecting a named server pins that choice.
3. **Check the connection mode.** New Windows installations start with **System proxy**. For apps and games that ignore
   system proxy settings, choose **Settings → Connection mode → VPN (TUN)**. New macOS/Linux installations default to TUN;
   Android uses its VPN service. Existing installations keep their saved preferences.
4. **Connect.** Press the circular connection button and grant any requested platform permission. Read the status beneath
   it to confirm the active mode. Press the button again to disconnect.

**Connected · system proxy only** is an expected working state in system proxy mode; only applications that use those settings are
routed through Tunnio. **Connected** means the VPN/TUN path is active, but does not guarantee that every server or website
is reachable. See the [connection-mode comparison](VPN_GUIDE.md#choose-a-connection-mode) and
[troubleshooting guide](VPN_GUIDE.md#troubleshooting).

### Encrypted subscription links

Plain HTTP(S) subscriptions work without a custom key. The optional `tunnio-rsa:` format conceals the subscription URL
during normal app use and requires a matching key in the app build. See [Encrypted subscription links](docs/ENCRYPTED_LINKS.md)
for key setup, link generation, and its security limitations.

## Interface preview

<table>
  <tr>
    <th>Compact layout · light theme</th>
    <th>Desktop connection modes</th>
  </tr>
  <tr>
    <td align="center"><img src="snapshots/mobile-light.png" width="280" alt="Compact Tunnio Home layout with a demo connection and server list"></td>
    <td align="center"><img src="snapshots/connection-mode.png" width="680" alt="Connection mode dialog explaining System proxy and VPN (TUN), with System proxy selected"></td>
  </tr>
</table>

These captures use the same demonstration data as the main preview. A [light desktop preview](snapshots/desktop-light.png)
also shows the **Connected · system proxy only** state.

## Documentation

| Guide | What you will find |
| --- | --- |
| [Using Tunnio](VPN_GUIDE.md) | Import, connection modes, latency tests, updates, troubleshooting, and recovery |
| [Building Tunnio](docs/BUILDING.md) | Toolchains, platform prerequisites, packaging, signing, and verification |
| [Encrypted subscription links](docs/ENCRYPTED_LINKS.md) | RSA key setup, app configuration, link generation, and rotation |
| [Demo snapshots](snapshots/README.md) | Full-size previews and a reproducible capture command |
| [Changelog](CHANGELOG.md) | Release history |

## Build

Install the [required toolchains](docs/BUILDING.md#toolchains), then get the source:

```bash
git clone --recurse-submodules https://github.com/phungvanquy/Tunnio.git
cd Tunnio
flutter pub get
```

Use `dart setup.dart <platform>` to build a package.
Supported platform arguments are `android`, `windows`, `macos`, and `linux`; desktop packages must be built on their
matching operating system. The build hooks compile the native components automatically.

## Support and contributions

Report reproducible problems through [GitHub Issues](https://github.com/phungvanquy/Tunnio/issues).
Include your Tunnio version, operating system, connection mode, steps to reproduce, and the displayed error.
Remove subscription URLs, tokens, and server credentials from logs and screenshots before sharing them.

For code contributions, follow the [repository guidance](AGENTS.md) and run the
[relevant checks](docs/BUILDING.md#verification). Documentation improvements and reproducible bug reports are welcome too.

## Credits and license

Tunnio builds on [FlClash](https://github.com/chen08209/FlClash),
[mihomo](https://github.com/MetaCubeX/mihomo), and [Flutter](https://github.com/flutter/flutter).
The interface follows Material You conventions, with inspiration from [Surfboard](https://github.com/getsurfboard/surfboard).

Licensed under the [GNU General Public License v3.0](LICENSE).
