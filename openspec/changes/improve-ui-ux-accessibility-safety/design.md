# Design

## Confirmations

All confirmations reuse `dialogs.showMessage`, which returns `true` only on confirm, so dismissal and Cancel share the no-op path. Existing ARB keys cover most copy (`deleteTip`, `deleteMultipTip`, `confirmOverwriteTip`); only close-connections needs a new sentence.

Restore asks after the strategy dialog and before `picker.pickerFile()` / the WebDAV download, so a cancelled restore touches neither the file system nor the network. The confirmation text states the chosen strategy.

The editors' `_handleDelete` becomes async and re-reads the selection after the dialog, so a selection changed while the dialog was open is not deleted by stale state.

## Power button

`_ConnectionButton` already receives `onPressed: null` for both "busy" and "not ready". Only "not ready" gets the new treatment: a new `unavailable` flag (`onPressed == null && !working`) drives `disabledBackgroundColor`/`disabledForegroundColor` at 38% alpha of the enabled colors (Material's disabled opacity), keeping the spec's gray/green palette while making the state visible. Busy states keep full-strength colors plus the progress ring, as today. The label passed to `Semantics`/`Tooltip` becomes `vpnNotReady` when unavailable. No provider or intent logic changes, so lifecycle ownership in `ServiceState` and latest-intent convergence are untouched.

## Semantics

- Logs FAB: `tooltip` with `pauseAutoScroll` / `resumeAutoScroll`.
- Access FAB: add the missing `tooltip: cancelSelectAll`.
- WebDAV dot: `Semantics(label:)` with existing `connecting`/`connected` keys and a new `connectionFailed` key, plus `liveRegion`.

## Search bar

Replace fixed greys with `colorScheme.surfaceContainerHigh`, `onSurface` foreground, and `onSurfaceVariant` icons.

## Testing

Widget tests per scenario in the spec, placed with the existing tests for each screen (`test/views/backup_and_restore_test.dart`, `test/widgets/input_test.dart`, `test/views/connections_test.dart`, `test/pages/home_test.dart`, logs/access tests). Existing tests that tapped delete/close directly are updated to confirm first.
