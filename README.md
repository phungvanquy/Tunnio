<div>

[**简体中文**](README_zh_CN.md)

</div>

## Tunnio

Tunnio is a fork of [FlClash](https://github.com/chen08209/FlClash), using the ITMOTunnio logo.
The Core is developed in [Tunnio-core](https://github.com/phungvanquy/Tunnio-core). Test builds are available from [GitHub Actions](https://github.com/phungvanquy/Tunnio/actions).

[![Downloads](https://img.shields.io/github/downloads/phungvanquy/Tunnio/total?style=flat-square&logo=github)](https://github.com/phungvanquy/Tunnio/releases/)[![Last Version](https://img.shields.io/github/release/phungvanquy/Tunnio/all.svg?style=flat-square)](https://github.com/phungvanquy/Tunnio/releases/)[![License](https://img.shields.io/github/license/phungvanquy/Tunnio?style=flat-square)](LICENSE)

A multi-platform proxy client based on ClashMeta, simple and easy to use, open-source and ad-free.

<p align="center">
    <img alt="Tunnio" src="assets/images/icon.png" width="128">
</p>

## Features

✈️ Multi-platform: Android, Windows, macOS and Linux

💻 Adaptive multiple screen sizes, Multiple color themes available

💡 Based on Material You Design, [Surfboard](https://github.com/getsurfboard/surfboard)-like UI

☁️ Supports data sync via WebDAV

✨ Support subscription link, Dark mode

## Use

### Quick start

1. Import your provider's subscription/configuration URL by QR code, **Paste from clipboard**, or manual entry. A “token” means the complete URL, including its embedded token—not a separate code.
2. Choose **Auto**, **Fallback**, or a server from Home's single list.
3. Press the large circular button to connect; press it again to disconnect. Grant VPN/TUN permission if requested.

Connected is green; disconnected is gray. **Test latency** measures the servers and highlights the fastest without changing your selection. Connection transitions and latency tests show progress and prevent repeated submissions.

The app keeps one profile. A successful import replaces it; a failed import keeps your saved setup. The gear opens Settings, including custom routing, configuration editing, backup, and recovery. Subscription/provider-list refresh pauses when Flutter is closed; the current native VPN configuration and health checks continue.

See [VPN setup, routing, and migration](VPN_GUIDE.md) for connection-state meanings and recovery details.

### Linux

⚠️ Make sure to install the following dependencies before using them

   ```bash
    sudo apt-get install libayatana-appindicator3-dev
   ```

### Android

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
