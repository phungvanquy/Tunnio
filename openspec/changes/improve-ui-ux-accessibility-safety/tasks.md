# Tasks

## 1. Localization

- [x] 1.1 Add `vpnNotReady`, `closeConnectionsTip`, `pauseAutoScroll`, `resumeAutoScroll`, `connectionFailed`, `restoreConfirmTip` to all four ARBs and regenerate; verify generation succeeds.

## 2. Destructive confirmations

- [x] 2.1 Confirm WebDAV binding delete; test cancel keeps the binding and confirm clears it.
- [x] 2.2 Confirm local and WebDAV restore before picking/downloading; test cancel performs no restore.
- [x] 2.3 Confirm close all connections; test cancel sends no close request.
- [x] 2.4 Confirm bulk delete in `ListInputPage` and `MapInputPage`; update existing tests and test cancel keeps entries.

## 3. Home power button

- [x] 3.1 Distinct disabled appearance and `vpnNotReady` label when not ready and idle; test disabled vs ready appearance and semantics label.

## 4. Accessible names and theming

- [x] 4.1 Logs auto-scroll FAB tooltip in both states; Access cancel-select-all tooltip; WebDAV status semantics; test each.
- [x] 4.2 Theme-derived search app bar colors; test colors match the scheme.

## 5. Verification

- [ ] 5.1 `dart format`, `flutter analyze --no-fatal-infos`, affected `flutter test` suites, `openspec validate`.
