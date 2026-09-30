<div>

[**English**](README.md)

</div>

## Tunnio

Tunnio 是基于 ClashMeta 的开源无广告代理客户端。Core 在 [Tunnio-core](https://github.com/phungvanquy/Tunnio-core) 维护。

[![Downloads](https://img.shields.io/github/downloads/phungvanquy/Tunnio/total?style=flat-square&logo=github)](https://github.com/phungvanquy/Tunnio/releases/)[![Last Version](https://img.shields.io/github/release/phungvanquy/Tunnio/all.svg?style=flat-square)](https://github.com/phungvanquy/Tunnio/releases/)[![License](https://img.shields.io/github/license/phungvanquy/Tunnio?style=flat-square)](LICENSE)

支持 Android、Windows、macOS 和 Linux，简单易用。

<p align="center">
    <img alt="Tunnio" src="assets/images/icon.png" width="128">
</p>

## Features

✈️ 多平台: Android, Windows, macOS and Linux

💻 自适应多个屏幕尺寸,多种颜色主题可供选择

💡 基本 Material You 设计, 类[Surfboard](https://github.com/getsurfboard/surfboard)用户界面

🔒 简化设置，不显示订阅链接和配置导出入口

✨ 支持普通及 RSA 加密订阅链接、深色模式

## Use

### 快速开始

1. 扫描二维码、点击 **从剪贴板粘贴**，或手动输入普通 HTTP(S) 订阅网址或 `tunnio-rsa:` 加密链接。
2. 在主页的同一列表中选择 **自动**、**故障转移** 或具体服务器。
3. 点击中央圆形按钮连接，再次点击即可断开。系统要求时，请授予 VPN／TUN 权限。

应用仅保留一个配置。导入成功后替换当前配置；导入失败时保留原配置。齿轮按钮打开简化后的设置，可替换或刷新订阅、恢复配置，并调整语言、主题和基本应用选项。Flutter 关闭后暂停订阅和提供商列表刷新，已运行的原生 VPN 配置和健康检查继续工作。

加密链接使用 RSA-OAEP，OAEP 和 MGF1 均采用 SHA-256。应用保存加密链接，仅在下载或刷新时解密。构建时通过已忽略的 `env.local.json` 提供私钥；生成密钥及链接的方法见 [英文说明](README.md#encrypted-subscription-links)。私钥会打包进应用，仅用于避免普通用户在界面中看到订阅网址，无法防止检查设备或应用文件的人提取配置。

连接状态、迁移及恢复说明见 [VPN 使用指南（英文）](VPN_GUIDE.md)。

### Linux

⚠️ 使用前请确保安装以下依赖

   ```bash
    sudo apt-get install libayatana-appindicator3-dev
   ```

### Android

支持下列操作

   ```bash
    com.follow.clash.action.START
    
    com.follow.clash.action.STOP
    
    com.follow.clash.action.TOGGLE
   ```

## Download

从 [Tunnio Releases](https://github.com/phungvanquy/Tunnio/releases) 下载正式安装包，或从 [GitHub Actions](https://github.com/phungvanquy/Tunnio/actions) 下载测试版本。

安装包文件名以 `Tunnio-` 开头。应用保留现有应用 ID 和数据目录；Android 升级还需要使用相同的签名。

## Build

1. 更新 submodules
   ```bash
   git submodule update --init --recursive
   ```

2. 安装 `Flutter` 以及 `Golang` 环境

3. 构建应用

    - android

        1. 安装  `Android SDK` ,  `Android NDK`

        2. 设置 `ANDROID_NDK` 环境变量

        3. 运行构建脚本

           ```bash
           dart setup.dart android
           ```

    - windows

        1. 你需要一个windows客户端

        2. 安装 `GCC`，`Inno Setup`

        3. 运行构建脚本

           ```bash
           dart setup.dart windows
           ```

    - linux

        1. 你需要一个linux客户端

        2. 依赖会由 setup 脚本自动安装，也可以手动安装：
           ```bash
           sudo apt-get install -y libayatana-appindicator3-dev
           ```

        3. 运行构建脚本

           ```bash
           dart setup.dart linux
           ```

    - macOS

        1. 你需要一个macOS客户端

        2. 运行构建脚本

           ```bash
           dart setup.dart macos
           ```

## Star

支持开发者的最简单方式是点击页面顶部的星标（⭐）。

<p style="text-align: center;">
    <a href="https://api.star-history.com/svg?repos=phungvanquy/Tunnio&Date">
        <img alt="start" width=50% src="https://api.star-history.com/svg?repos=phungvanquy/Tunnio&Date"/>
    </a>
</p>
