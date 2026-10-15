# Building Tunnio

[← Back to the README](../README.md)

Use `setup.dart` to compile the native components, build Flutter, and package the result. Build desktop packages on the
matching operating system. Android needs an Android development toolchain on the build host.

## Toolchains

The [build workflow](../.github/workflows/build.yaml) is the source of truth for release toolchain versions.

| Tool | Version used by the workflow | Purpose |
| --- | --- | --- |
| Flutter | 3.47.1 | Application UI and the bundled Dart SDK |
| Go | 1.26.4 | Tunnio Core; the core modules require Go 1.25 or newer |
| Rust / Cargo | Available on the build host | Native library and desktop helper components |
| JDK | 17 | Android Gradle builds |
| Android NDK | r28c | Android native compilation |

Install Git and the platform's Flutter development prerequisites, then run `flutter doctor` to check the host.
Keep the Flutter, Go, Rust, and platform tools available on `PATH`.

### Platform prerequisites

| Target | Additional requirements |
| --- | --- |
| Android | Android SDK, SDK licenses, JDK 17, and NDK installed in the SDK |
| Windows | Windows Flutter desktop toolchain, GCC for native components, and Inno Setup for the installer |
| macOS | Xcode and Flutter macOS prerequisites; Node.js/npm for `appdmg` packaging |
| Linux | Linux Flutter desktop toolchain, GTK, Ayatana AppIndicator, libsecret, and package-building tools |

For Android, the build hook obtains the NDK compiler from Flutter. An `ANDROID_NDK` environment variable is not required.
The workflow installs r28c into the SDK; follow that setup when reproducing CI builds.

On Debian/Ubuntu, `setup.dart linux` checks and installs missing packages with `apt-get`, including `ninja-build`,
`libgtk-3-dev`, `libayatana-appindicator3-dev`, `libsecret-1-dev`, `locate`, `rpm`, `patchelf`, and `libfuse2` (or its
`libfuse2t64` alias). It also downloads `appimagetool` into `/usr/local/bin`. This requires appropriate permissions.
The automatic Linux dependency setup targets Debian/Ubuntu; other distributions require adapting that setup or using a
compatible build environment.

On macOS, the script installs `appdmg` using `npm install -g appdmg` if it is missing.

## Get the source

```bash
git clone --recurse-submodules https://github.com/phungvanquy/Tunnio.git
cd Tunnio
flutter pub get
```

For an existing checkout, initialize or update the core submodule before building:

```bash
git submodule update --init --recursive
```

## Package the app

Run the command for your target:

| Target | Command | Package formats |
| --- | --- | --- |
| Android | `dart setup.dart android` | APK |
| Windows | `dart setup.dart windows` | EXE installer and ZIP |
| macOS | `dart setup.dart macos` | DMG |
| Linux | `dart setup.dart linux` | DEB, AppImage, and RPM |

Packages are written under `dist/` with Tunnio branding. Package support in the script does not imply that every platform
is included in every Actions run; check the workflow matrix and release assets.

Useful variations:

```bash
dart setup.dart android --arch arm64
dart setup.dart windows --targets exe
dart setup.dart linux --env stable
```

`--env` accepts `dev`, `pre`, and `stable`, and defaults to `pre`. `--targets` limits the package formats for the selected
platform. Run `dart setup.dart --help` for the full options.

The script activates the pinned `flutter_distributor` fork and generates `env.json`. If you need encrypted subscriptions,
configure the key before packaging as described in [Encrypted subscription links](ENCRYPTED_LINKS.md).

## Run during development

```bash
flutter run
```

The native build hooks run automatically during Flutter builds. The setup hook builds the Go core and helper components;
the Rust API hook builds the native library. You do not need a separate manual core-copy step.

Core artifacts are staged under `libclash/`. The setup hook caches native build fingerprints in
`.dart_tool/setup_build_cache/`; its `hook.log` records build decisions and output. If a native input changed but a rebuild
is needed, remove that cache directory and build again.

## Android signing

APK builds do not require a Play Store account. For consistently signed GitHub Actions packages, configure these
repository secrets:

| Secret | Value |
| --- | --- |
| `KEYSTORE` | Base64-encoded Android keystore |
| `KEY_ALIAS` | Signing-key alias |
| `STORE_PASSWORD` | Keystore password |
| `KEY_PASSWORD` | Signing-key password |

Without `KEYSTORE`, CI uses debug signing and the `com.follow.clash.dev` application ID, including tagged builds. It can
install alongside a release-signed app. Debug keys can differ between runs, so an APK from another run may require
reinstallation. Use the same signing key for upgrades that preserve the existing installation.

Android signing credentials are separate from `VPN_RSA_PRIVATE_KEY_B64`, which is used for subscription-link decryption.

## Verification

Run the checks relevant to the change. The main Flutter checks are:

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test tool plugins setup.dart
flutter analyze --no-fatal-infos
flutter test --reporter expanded
```

Use `flutter test`, not `dart test`, for root-package tests because the models depend on Flutter types. A focused run can
target a file or directory, such as `flutter test test/pages/home_test.dart`.

### Tests without native compilation

Build hooks also run during `flutter test` and root-package `dart run` commands. For widget/provider tests that do not
load the native libraries, temporarily set both native-hook flags in the root `pubspec.yaml` to `false`:

```yaml
hooks:
  user_defines:
    setup:
      build_assets: false
    rust_api:
      build_assets: false
```

Restore both to `true` immediately after the test or code-generation run. **Do not commit `false` or use it to package
the app.** `setup.dart` rejects packaging with these flags disabled. CI uses the same temporary test configuration.

### Generated code

After changing models, providers, or database schema:

```bash
dart run build_runner build --delete-conflicting-outputs
```

After updating all four locale files under `arb/`:

```bash
dart run intl_utils:generate
```

Do not edit generated files by hand. For native checks, plugin tests, lifecycle constraints, and commit conventions,
see [repository commands](../.agents/commands.md) and [rules](../.agents/rules.md).

Documentation captures have their own [snapshot-generation instructions](../snapshots/README.md#regenerate).
