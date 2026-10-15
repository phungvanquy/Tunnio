# Using Tunnio

[← Back to the README](README.md)

Tunnio uses a subscription supplied by your provider. The everyday flow is **import → select → connect**.
This guide describes the current source; older releases may have different controls or defaults.

- [Import and select a server](#import-and-select-a-server)
- [Choose a connection mode](#choose-a-connection-mode)
- [Understand connection status](#understand-connection-status)
- [Test server latency](#test-server-latency)
- [Update or replace a subscription](#update-or-replace-a-subscription)
- [Troubleshooting](#troubleshooting)
- [Android connection lifecycle](#android-connection-lifecycle)
- [Settings and routing](#settings-and-routing)
- [Upgrades and recovery](#upgrades-and-recovery)

## Import and select a server

On Home, import a plain HTTP(S) subscription URL or a `tunnio-rsa:` encrypted link using **Paste from clipboard**, manual
entry, or a QR code. Android supports camera scanning and QR images; desktop uses a QR image file. If camera access is
unavailable, use an image or paste the link. Supported QR images are PNG/JPEG, up to 16 MB, 16 megapixels, and 8192 pixels
per side.

Encrypted links require a matching key in the app build. See [Encrypted subscription links](docs/ENCRYPTED_LINKS.md).
Keep subscription links and downloaded configurations private: they may contain account tokens or server credentials.

After import, Home lists **Auto**, **Fallback**, and the usable servers from the configuration and its providers.

| Selection | Behavior |
| --- | --- |
| Auto | Chooses a responsive server using periodic latency checks |
| Fallback | Uses the first healthy server in source order |
| A named server | Pins your selection to that server |

Your selection is remembered and can be made before connecting. Importing alone does not connect a disconnected VPN or
request VPN permission. Press the circular connection button when you are ready.

Auto and Fallback do not silently select DIRECT when no eligible server is available. If a successful refresh removes
your selected server, Tunnio returns to Auto and notifies you. A failed refresh keeps the saved catalog and selection.

## Choose a connection mode

On desktop, open **Settings → Connection mode**. For a predictable mode change, disconnect, choose the mode, then connect
again. Android uses the operating system's VPN service and does not show this desktop selector.

| Mode | Traffic coverage | When to use it |
| --- | --- | --- |
| System proxy | Applications that follow the operating system's proxy settings | A straightforward starting point on Windows, especially for browsers |
| VPN (TUN) | Traffic captured by a virtual network interface, including apps that ignore system proxy settings | Games and other applications that need broader traffic capture; platform authorization may be required |

**Fresh-install defaults:** Windows uses System proxy; macOS and Linux use TUN; Android uses its VPN service.
Defaults are applied when you explicitly connect. Existing installations keep their saved preferences, including a
previously saved combined or manual-proxy setup. Selecting one of the two modes replaces that saved combination.

TUN has broader reach, but its operation also depends on virtual-interface setup, routing, and platform permissions.
System proxy is useful for establishing that the subscription works before adding those requirements. Neither mode
makes an unavailable server reachable.

<p align="center">
  <img src="snapshots/connection-mode.png" width="720" alt="Desktop connection mode dialog with System proxy selected and an explanation of VPN (TUN)">
</p>

*Demo capture from the current UI. [All snapshots](snapshots/README.md).*

## Understand connection status

Status follows native service and listener observations. A successful startup command alone is not treated as an active
VPN. Read the label beneath the connection button; color is a secondary cue.

| Status | Meaning and next action |
| --- | --- |
| Disconnected | The connection is stopped. Choose a server and connect when ready. |
| Checking connection | The app is waiting for native state, particularly after reopening on Android. |
| Connecting | Startup or platform authorization is in progress. Use **Cancel** to stop the attempt. |
| Connected | The observed VPN/TUN path is active. This does not verify every server or destination. |
| Connected · system proxy only | The proxy is active through the system proxy settings, without TUN. This is expected in System proxy mode. |
| Local proxy only · VPN is not active | A local proxy listener is active, without TUN or confirmed system proxy installation. Applications need their own proxy configuration to use it. |
| Disconnecting | Cleanup is in progress; wait for confirmation. |
| Suspended / Connection needs attention | Read the accompanying message and use the offered retry, disconnect, or recovery action. |

Connected uses a green button and badge. Transitions prevent repeated submissions. If disconnection cannot be confirmed,
retry **Disconnect**; the app does not turn that retry into a reconnect request.

When TUN was requested but is unavailable, Home can offer **Use system proxy**. This saves system proxy mode and starts
that connection path. Apps that ignore system proxy settings will still need TUN or their own proxy configuration.

While VPN/TUN is Connected, **Current node** shows the server reported by Core, including the node selected by Auto or
Fallback. It stays above the scrolling server list. Existing sessions may remain on an earlier node; custom routing can
send different connections through different nodes. If the node cannot be confirmed, the card says so. It disappears
when the connection leaves the Connected state.

## Test server latency

Use the speedometer button above the server list, labeled **Test latency** in its tooltip. Results appear beside each
server; the fastest successful result receives a subtle accent border. Testing neither changes your selected server
nor connects a disconnected VPN. Normal Auto/Fallback health checks can still change their chosen outbound.

| Result | Meaning |
| --- | --- |
| A value in milliseconds | The probe completed. Lower is faster for this test, not a download-speed guarantee. |
| Not tested | There is no result for the current configuration and test URL. |
| Timed out | The probe exceeded its deadline. |
| Unreachable | The probe could not connect or complete. |
| Test failed | The test infrastructure did not return a usable result. |

The button shows progress while a batch runs and prevents duplicate tests. Results are kept only for the current app
session and are cleared when the configuration generation or test URL changes.

## Update or replace a subscription

Tunnio keeps one active profile. Use **Settings → Update now** to refresh it or **Replace configuration** on Home or in
Settings to import another subscription.

The app downloads and validates the candidate and its required resources before committing it. Failed download,
validation, preparation, or storage preserves the previous saved configuration and selection. If activation fails,
Tunnio attempts to restore the previous configuration; if restoration also fails, use the recovery action in Settings.

During a connected replacement, existing sessions may reconnect when the new configuration activates. Disconnecting
while an import is pending wins: completing that import does not reconnect you. Cancelling or submitting a newer import
prevents an older attempt from replacing it.

Progress labels identify the current stage, such as downloading, preparing lists or geographic databases, checking,
saving, and applying. Resource counts describe completed resources, not an overall percentage. Cancellation remains
busy until cleanup finishes. Once applying starts, wait for completion.

### Refresh behavior

- Subscription and provider-content refresh pauses while the Flutter app is closed. If the native VPN continues running,
  it uses the last committed configuration, and health checks, Auto, and Fallback continue. Due refreshes resume when the
  app returns.
- The first import can use bundled default geographic databases. Custom database sources may require larger downloads.
- Later updates reuse verified geographic data from the same source until its refresh interval expires, normally
  24 hours. A failed geographic-data refresh can retain a verified same-source copy. Bundled defaults never replace a
  custom source.
- Subscription and provider-list downloads still need to succeed for an update; they do not silently fall back to stale
  content. Each download has a 90-second total deadline, with validation and activation taking additional time.

An unrecoverable timeout leaves the saved configuration unchanged and offers a retry. Avoid deleting app data to fix
an interrupted update; the saved configuration and recovery journal may be needed to recover it.

## Troubleshooting

### The subscription imports, but most latency tests fail

A successful import proves that Tunnio could obtain and prepare the configuration. It does not prove that the listed
servers are reachable.

1. Confirm that ordinary internet access works with the proxy/VPN disconnected.
2. Fully exit other proxy and VPN clients, including their tray applications, to avoid overlapping traffic capture.
3. On Windows, disconnect Tunnio, choose **Settings → Connection mode → System proxy**, reconnect, and run **Test latency**.
4. If tests now work, investigate the TUN path: platform authorization, virtual-interface startup, routing, and conflicts
   with another VPN. Use system proxy for applications that support it while checking TUN.
5. If tests still fail, compare the same named server and an equally fresh subscription in the other client. Different
   test URLs, DNS behavior, routing settings, and core versions can produce different results. Record the exact error
   before changing settings further.

If another client works, that is useful evidence for a report; it does not by itself identify a TUN, DNS, or protocol bug.
Include the versions of both clients and whether they were using TUN or system proxy. Remove all subscription tokens and
node credentials from shared logs.

### Latency tests work, but an application has no internet

Check the displayed connection mode. In **Connected · system proxy only**, an application that ignores system proxy settings will
not use Tunnio automatically. Try VPN (TUN) and confirm that the status becomes **Connected**, or configure that
application's proxy support. If only one destination fails, compare another server and check any saved custom routing.

### TUN permission or startup fails

Approve the platform authorization prompt when connecting in TUN mode. On Windows, the helper/service path may need
administrator permission. If TUN still cannot start, use **Use system proxy** when offered, or select System proxy in
Settings and reconnect. Include the error message and operating-system version in a report.

### An encrypted link reports a missing key or cannot be decrypted

Use an app build containing the private key that matches the link's public key, or obtain a plain compatible subscription
URL from your provider. Updating or replacing the subscription cannot repair a mismatched build key.
See the [encrypted-link guide](docs/ENCRYPTED_LINKS.md#rotate-keys).

### An update or recovery is stuck

Allow cancellation or activation cleanup to finish. Retry a failed download when the network is available. If Settings
offers recovery, use it before deleting or reimporting data. When reporting the problem, include the last progress stage,
error text, app version, and whether you were connected.

## Android connection lifecycle

Tap **Disconnect** and wait for **Disconnected**. A successful stop removes Tunnio's foreground connection notification
and releases the tunnel. Closing the app or removing it from Recents is not a reliable way to disconnect: the native VPN
may continue running.

When reopening, **Checking connection** means Tunnio is waiting for native state. If that fails or takes more than five
seconds, use **Try again** to recheck or **Disconnect** to request a safe stop. An unknown state does not cause a second
connection to start. A failed cleanup stays visible and retryable; a new start is blocked until cleanup succeeds.

### Always-on VPN

Android's **Always-on VPN** is independent of Tunnio's auto-connect preference and can start the service again.
To leave it off, open Android **Settings → Network & Internet** (or **Connections**) **→ VPN → Tunnio**, then disable
Always-on VPN. **Block connections without VPN** can keep internet access blocked after disconnection. Menu wording
varies by device; see [Android's VPN lifecycle guidance](https://developer.android.com/develop/connectivity/vpn).

If the VPN key remains after Tunnio reports Disconnected, check whether another VPN or Always-on VPN is active. The key
icon belongs to Android. If Android still lists Tunnio as connected, disconnect it there and report the app version,
Android version, displayed state, and which notification or icon remained.

### Automation actions

The Android action identifiers remain compatible with earlier versions:

```text
com.follow.clash.action.START
com.follow.clash.action.STOP
com.follow.clash.action.TOGGLE
```

## Settings and routing

The gear opens configuration replacement and refresh, recovery, desktop connection mode, language, theme, and essential
application preferences. The simplified interface keeps the original subscription URL, configuration editing, export,
backup, resource lists, and advanced diagnostics out of view.

Fresh appearance settings use dark mode, a muted teal accent, the Tonal Spot palette, and 80% text size. Existing choices
are preserved on upgrade. **Settings → Theme** changes colors, theme mode, and text size. Disabling the text-size override
follows system scaling within the supported 80–140% range. Resetting the palette does not reset text size or theme mode.

In simple routing, the selected server, Auto, or Fallback handles captured traffic. Existing custom routing from earlier
versions remains in saved profiles; choosing a Home node switches back to simple routing. VPN/TUN coverage also depends
on platform routing and any exclusions.

## Upgrades and recovery

Installers and desktop executables use Tunnio names while retaining application IDs, data locations, installer identity,
and other upgrade identifiers. Upgrade with the same signing identity to preserve application data. The
`tunnio://install-config` scheme is supported alongside legacy schemes, and the existing WebDAV backup folder remains
compatible.

Before consolidating an older multi-profile installation, Tunnio creates and verifies an app-private recovery archive.
Migration tries the selected usable profile first, then the first usable profile in saved order. If none is usable, Home
returns to import while the archive preserves the old data. If the archive cannot be written, old records are not pruned.

Routine cleanup does not remove these migration archives. Older backup files remain compatible with migration and
recovery code, although simplified Settings does not expose archive export, backup, or restore controls.

After an interrupted commit, startup or Settings recovery can use the saved database record and commit journal to
finish publication. Keep application data intact while recovery is pending. The archive and journal cannot protect
against every instance of filesystem corruption or device failure.
