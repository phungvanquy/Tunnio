# Proposal

## Why

A UI/UX review found actions that discard user data or live traffic with a single tap, controls whose purpose or state is not exposed to assistive technology, a power button that looks tappable while it cannot act, and a search bar whose colors ignore the active theme. These are defects against the existing accessibility requirement in `simplified-vpn-interface` and against ordinary destructive-action practice.

## What Changes

- Require confirmation before deleting the WebDAV binding, restoring a backup (local or WebDAV), closing all active connections, and bulk-deleting entries in list/map editors. Cancelling leaves state untouched.
- Give the unavailable Home power button a distinct disabled appearance and an accessible explanation, without changing the in-progress (connecting/disconnecting/checking) treatment the existing spec defines.
- Provide accessible names for the Logs auto-scroll FAB in both states, the Access "cancel select all" FAB, and the WebDAV connection indicator.
- Derive the search app bar colors from the active color scheme instead of fixed grey/white.

Review findings deliberately excluded because they conflict with current requirements or need a product decision: theme-derived connection/latency palettes (the spec fixes green, gray and the 100/250 ms thresholds), file import on first-run Home (`single-profile-import` restricts intake to URL, paste and QR), removing the dormant dashboard code, regrouping Application Settings, resizing shared dialogs/sheets, and translating protocol names such as DNS, IPv6, PreferH3, Geoip and Geosite.

## Capabilities

### New Capabilities

- `ui-safety-accessibility`: confirmation of destructive settings actions, disabled-state affordance for the power button, accessible names for icon-only and color-only status controls, and theme-derived search chrome.

### Modified Capabilities

None. The new requirements refine behavior already constrained by `simplified-vpn-interface`'s accessibility and connection-control requirements without changing them.

## Impact

- `lib/pages/home.dart`, `lib/views/backup_and_restore.dart`, `lib/views/connection/connections.dart`, `lib/widgets/input_pages.dart`, `lib/views/logs.dart`, `lib/views/access.dart`, `lib/widgets/scaffold.dart`.
- New ARB keys in all four locales; regenerated `lib/l10n/`.
- Widget tests for each confirmation, the disabled button, and the added semantics.
