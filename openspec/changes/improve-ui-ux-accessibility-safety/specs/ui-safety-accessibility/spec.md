# Spec Delta

## Purpose

Prevent accidental loss of settings, data, or live traffic from a single tap, and expose control purpose and state to assistive technology and theming.

## ADDED Requirements

### Requirement: Confirmed destructive settings actions

Deleting the WebDAV binding, restoring from a local file or WebDAV, closing all active connections, and deleting selected entries in list or map editors SHALL each require an explicit confirmation naming the consequence. Dismissing or cancelling the confirmation MUST leave the binding, application data, connections, and editor entries unchanged. Confirmation SHALL occur before any file is picked, downloaded, copied, or applied for restore.

#### Scenario: WebDAV delete is cancelled

- **WHEN** the user taps Delete in the WebDAV form and then cancels the confirmation
- **THEN** the stored WebDAV binding remains and the form stays open

#### Scenario: WebDAV delete is confirmed

- **WHEN** the user confirms the delete
- **THEN** the binding is cleared and the form closes

#### Scenario: Restore is cancelled

- **WHEN** the user chooses a restore strategy and then cancels the overwrite confirmation
- **THEN** no file picker opens, no backup is downloaded, and no data is restored

#### Scenario: Close connections is cancelled

- **WHEN** the user taps Close connections and cancels
- **THEN** no close request is sent to Core

#### Scenario: Bulk delete is cancelled

- **WHEN** entries are selected in a list or map editor and the user cancels the delete confirmation
- **THEN** the entries and the selection remain

### Requirement: Unavailable power button affordance

When the Home power button cannot act because the profile or application is not ready and no connection is active or in progress, it SHALL render with a disabled appearance distinct from its enabled disconnected appearance and SHALL expose a localized explanation to assistive technology and its tooltip. Progress states (checking, connecting, disconnecting, or a pending submission) SHALL retain their existing appearance and busy indicator.

#### Scenario: Not ready

- **WHEN** Home shows a profile whose configuration generation is unavailable and the VPN is disconnected
- **THEN** the power button is disabled, visually differs from the ready disconnected button, and announces that the connection is not available yet

#### Scenario: Ready

- **WHEN** the same profile becomes ready
- **THEN** the button returns to its enabled disconnected appearance and Connect label

### Requirement: Accessible names for icon-only and color-only status

The Logs auto-scroll button SHALL expose a localized name describing the action it will perform in each state. The Access select-all button SHALL expose a tooltip in both its select-all and cancel-select-all states. The WebDAV connection indicator SHALL expose connecting, connected, or failed as text semantics in addition to color.

#### Scenario: Logs auto-scroll toggle

- **WHEN** auto-scroll is on or off
- **THEN** the button's tooltip and semantics name describe pausing or resuming auto-scroll respectively

#### Scenario: WebDAV status

- **WHEN** the WebDAV check fails
- **THEN** assistive technology announces the failed state, not only a red dot

### Requirement: Theme-derived search chrome

The app-bar search state SHALL take its background, foreground, and icon colors from the active color scheme, so text and icons keep scheme-defined contrast in light, dark, pure-black, and custom-color themes.

#### Scenario: Pure black theme

- **WHEN** search opens with pure black enabled
- **THEN** the search bar uses the scheme's surface colors and on-surface foreground rather than a fixed grey
