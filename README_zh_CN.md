<p align="center">
  <img src="assets/images/icon.png" width="96" alt="Tunnio 图标">
</p>

<h1 align="center">Tunnio</h1>

<p align="center">简洁、开源的代理客户端，支持 Android、Windows、macOS 和 Linux。</p>

<p align="center">
  <a href="https://github.com/phungvanquy/Tunnio/releases"><img src="https://img.shields.io/github/v/release/phungvanquy/Tunnio?style=flat-square" alt="最新版本"></a>
  <a href="https://github.com/phungvanquy/Tunnio/actions/workflows/build.yaml"><img src="https://github.com/phungvanquy/Tunnio/actions/workflows/build.yaml/badge.svg" alt="构建状态"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-blue?style=flat-square" alt="GPL-3.0 许可证"></a>
</p>

<p align="center">
  <a href="https://github.com/phungvanquy/Tunnio/releases">下载</a> ·
  <a href="#快速开始">快速开始</a> ·
  <a href="VPN_GUIDE.md">使用指南（英文）</a> ·
  <a href="README.md">English</a>
</p>

Tunnio 将订阅导入、节点选择和连接控制集中在一个清晰的界面中。应用无广告，使用 Flutter 构建，
底层采用基于 mihomo 的 [Tunnio Core](https://github.com/phungvanquy/Tunnio-core)。
你需要自行准备兼容的订阅；应用本身不提供 VPN 服务或服务器。

<p align="center">
  <img src="snapshots/desktop-dark.png" width="1080" alt="Tunnio 深色界面：演示 TUN 连接、自动选择和节点延迟结果">
</p>

*截图由当前源码中的界面组件渲染，节点名称、连接状态和延迟均为演示数据，已发布版本可能有所不同。
[查看全部截图及生成方法（英文）](snapshots/README.md)。*

## 功能特点

- **简洁的连接流程。** 导入一个订阅，选择自动、故障转移或指定节点，即可连接。
- **清晰的连接状态。** 区分 VPN/TUN 已连接、仅系统代理和仅本地代理。
- **直观的延迟测试。** 在节点列表中查看测试结果，测试不会更改当前选择。
- **可靠的配置替换。** 新配置通过验证后才会提交，导入失败时保留已保存的配置。
- **适配不同屏幕。** Material You 风格，支持深浅主题、文字大小调整和手机、桌面布局。
- **多种导入方式。** 支持粘贴链接、手动输入和二维码；内置匹配密钥的构建还支持加密订阅链接。

## 下载

正式构建请前往 **[GitHub Releases](https://github.com/phungvanquy/Tunnio/releases)**。
开发构建可在 **[GitHub Actions](https://github.com/phungvanquy/Tunnio/actions/workflows/build.yaml)**
中打开成功的运行记录并下载构建产物。请选择与你的操作系统和处理器架构匹配的文件。

下载文件名以 `Tunnio-` 开头。升级时保留原有应用标识和数据位置。
Android 覆盖安装还需要相同的签名密钥，详情见 [Android 签名说明（英文）](docs/BUILDING.md#android-signing)。
平台依赖及本地打包方法见 [构建指南（英文）](docs/BUILDING.md)。

## 快速开始

1. **导入订阅。** 使用粘贴、手动输入或二维码。Android 支持相机扫码和二维码图片，桌面端支持选择二维码图片。
2. **选择节点。** 自动模式根据延迟检查选择可用节点；故障转移模式按配置顺序使用第一个健康节点；选择具体节点则固定使用该节点。
3. **确认连接模式。** Windows 全新安装默认使用**系统代理**。需要接管不遵循系统代理设置的应用或游戏时，
   进入**设置 → 连接模式 → VPN（TUN）**。macOS/Linux 全新安装默认使用 TUN，Android 使用系统 VPN 服务。
   已有安装保留原先保存的偏好。
4. **连接。** 点击圆形连接按钮，并在需要时授予系统权限。通过按钮下方的状态确认当前模式，再次点击即可断开。

系统代理模式下显示“已连接 · 仅系统代理”属于正常工作状态，只有遵循系统代理设置的应用会使用 Tunnio。
“已连接”表示 VPN/TUN 通道处于活动状态，并不保证所有节点或网站都能访问。
详见[连接模式对比（英文）](VPN_GUIDE.md#choose-a-connection-mode)和[故障排查（英文）](VPN_GUIDE.md#troubleshooting)。

### 加密订阅链接

普通 HTTP(S) 订阅不需要自定义密钥。可选的 `tunnio-rsa:` 格式可以在日常使用中隐藏订阅原始地址，
但要求应用构建包含匹配的密钥。密钥配置、链接生成及安全限制见[加密订阅指南（英文）](docs/ENCRYPTED_LINKS.md)。

## 界面预览

<table>
  <tr>
    <th>紧凑布局 · 浅色主题</th>
    <th>桌面连接模式</th>
  </tr>
  <tr>
    <td align="center"><img src="snapshots/mobile-light.png" width="280" alt="Tunnio 紧凑布局：演示连接和节点列表"></td>
    <td align="center"><img src="snapshots/connection-mode.png" width="680" alt="连接模式对话框：说明系统代理和 VPN (TUN) 的适用范围，当前选中系统代理"></td>
  </tr>
</table>

这些截图与上方预览使用相同的演示数据。另可查看显示“已连接 · 仅系统代理”状态的[桌面浅色预览](snapshots/desktop-light.png)。

## 文档

以下详细指南目前使用英文。

| 指南 | 内容 |
| --- | --- |
| [使用 Tunnio](VPN_GUIDE.md) | 导入、连接模式、延迟测试、更新、故障排查与恢复 |
| [构建 Tunnio](docs/BUILDING.md) | 工具链、平台依赖、打包、签名与验证 |
| [加密订阅链接](docs/ENCRYPTED_LINKS.md) | RSA 密钥配置、链接生成与密钥更换 |
| [演示截图](snapshots/README.md) | 完整预览与可复现的截图生成命令 |
| [更新日志](CHANGELOG.md) | 版本历史 |

## 从源码构建

安装[所需工具链](docs/BUILDING.md#toolchains)，然后获取源码：

```bash
git clone --recurse-submodules https://github.com/phungvanquy/Tunnio.git
cd Tunnio
flutter pub get
```

运行 `dart setup.dart <platform>` 打包。
平台参数支持 `android`、`windows`、`macos` 和 `linux`；桌面包需要在对应的操作系统上构建。
原生组件由构建钩子自动编译。

## 支持与贡献

请通过 [GitHub Issues](https://github.com/phungvanquy/Tunnio/issues) 报告可复现的问题，并提供 Tunnio 版本、
操作系统、连接模式、复现步骤及错误提示。分享日志或截图前，请移除订阅地址、令牌和节点凭据。

代码贡献请遵循[仓库指南](AGENTS.md)并运行[相关检查](docs/BUILDING.md#verification)。
也欢迎改进文档或提供可复现的问题报告。

## 致谢与许可

Tunnio 基于 [FlClash](https://github.com/chen08209/FlClash)、
[mihomo](https://github.com/MetaCubeX/mihomo) 和 [Flutter](https://github.com/flutter/flutter) 构建。
界面遵循 Material You 设计，并借鉴了 [Surfboard](https://github.com/getsurfboard/surfboard) 的设计。

本项目采用 [GNU GPL v3.0 许可证](LICENSE)。
