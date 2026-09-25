# unified-server-selection Specification

## Purpose

Provide one understandable server selection that consistently controls the default VPN route, including automatic speed-based and failover choices.

## Requirements

### Requirement: Explicit non-disruptive node latency testing

Home SHALL show each individual node's measured latency in milliseconds or an explicit Not tested, Testing, Timed out, Unreachable, or Test failed state. A Test latency icon button beside the Servers heading SHALL test the committed inventory with bounded concurrency. It SHALL have a localized tooltip and accessible name, a touch target of at least 48 logical pixels, and an in-place progress indicator with a Testing accessible label while running. One batch SHALL run at a time, with progress and repeated submissions disabled. Queue/channel/Core failures SHALL be distinguished from a contacted node's timeout or unreachable result. Results SHALL be scoped to the configuration generation and test URL; completion after replacement, Core loss, or disposal MUST NOT overwrite newer results.

Manual tests SHALL NOT write the selected server/mode, restart listeners, close active traffic connections, or connect a disconnected VPN. Auto/Fallback SHALL remain modes, not be relabeled as individual measurements; existing health-check-based behavior remains in effect. The fastest measured node SHALL be highlighted without reordering the user's list or changing selection. Latency is a probe result, not a guarantee of internet access or throughput.

#### Scenario: Normal and slow results

- **WHEN** available nodes respond with different delays
- **THEN** each delay is displayed in a compact milliseconds badge: green below 100 ms, yellow from 100 through 250 ms inclusive, and red above 250 ms
- **AND** the fastest successful result has a subtle accent border without a Fastest text label, reordering, or changing selection

#### Scenario: Offline, timeout, or infrastructure failure

- **WHEN** a probe cannot connect, exceeds its probe deadline, or receives no usable Core response
- **THEN** it respectively displays Unreachable, Timed out, or Test failed with neutral styling; progress always ends and retry is available

#### Scenario: Repeated tests and replacement

- **WHEN** a second test is requested during a batch or a profile is replaced while tests are in flight
- **THEN** the duplicate batch is not started and old-generation results cannot appear in the replacement list

#### Scenario: Test during an active VPN session

- **WHEN** a user tests latency with a manually selected server and active VPN
- **THEN** that selection, running intent, and active traffic sessions remain unchanged

### Requirement: Provider content refresh follows application lifetime
The application SHALL coordinate subscription and provider-content refreshes as new committed configuration generations. Automatic content refresh SHALL pause while the Flutter application is closed. The native VPN SHALL continue using its committed configuration, including reachability health checks and Auto/Fallback failover. When the application returns, due refreshes SHALL resume through the same failure-preserving coordinator. Native provider timers, file watchers, and direct update/side-load operations SHALL NOT rewrite committed generation resources.

#### Scenario: Flutter closes while the VPN remains connected
- **WHEN** the Flutter application closes while a committed VPN configuration is active
- **THEN** automatic server/provider-list content refresh pauses
- **AND** traffic and health-check-based failover continue using that configuration
- **AND** its persisted generation and catalog revision remain unchanged

#### Scenario: Flutter resumes with a refresh due
- **WHEN** Flutter returns and subscription or provider content is due for refresh
- **THEN** the application stages and validates a new generation before replacing the committed snapshot
- **AND** a failed refresh leaves the current configuration and selection unchanged

### Requirement: One server inventory

After a successful import the application SHALL show one list containing `Auto`, `Fallback`, and all eligible individual proxy servers from the committed configuration and its resolved proxy providers. The list MUST NOT require choosing a proxy group first. Built-in direct/reject targets, subscription group containers, and internal generated names SHALL NOT appear as ordinary servers. Entries SHALL have stable identities; equal display names MUST remain distinguishable and cannot be used to select the wrong target.

#### Scenario: Configuration contains nested groups and provider servers

- **WHEN** a configuration with individual proxies, nested policy groups, and resolved provider-backed proxies is imported
- **THEN** Home displays the individual eligible servers alongside Auto and Fallback without duplicating the same server merely because several groups reference it

#### Scenario: Subscription uses an automatic-mode label as a server name

- **WHEN** a real server is named Auto or Fallback
- **THEN** it remains distinguishable from the app's automatic choice and selecting either targets the correct entity

### Requirement: Compact and recognizable server rows

Individual server rows SHALL display the original node name verbatim, including any icons or flags supplied by the subscription. The application SHALL NOT infer countries, add a separate flag or location icon, or strip characters from the name. Auto and Fallback SHALL retain their mode icons. Selection SHALL retain its accessible selected state and selected surface independently of latency color.

Server names and the current-node label SHALL use the platform's normal text-font fallback. An emoji font SHALL NOT be applied as a fallback for the entire name: digits and keycap-base punctuation must retain visible text glyphs.

Node names SHALL use the compact title-small typography and protocol/provider labels the secondary body-small typography used before the header refresh. Names and protocol/provider text SHALL wrap without line limits or ellipsis; the row SHALL grow to contain the entire text at the configured text scale. Latency SHALL remain beside or below the metadata without narrowing the name. Rows SHALL retain at least 64 logical pixels of height, eight logical pixels of vertical content padding, and one logical pixel of inter-row spacing. Each row SHALL own its Material ink surface so selected backgrounds and tap feedback remain clipped by the scrolling viewport.

#### Scenario: Subscription includes its own icons

- **WHEN** a node name includes a prefix and an embedded flag, such as `[9] > 🇫🇮 Example region`
- **THEN** the complete name and supplied flag appear exactly once, without a generated country icon or name rewriting
- **AND** selecting the row still uses its original catalog identity

#### Scenario: Numeric node identifiers on Android

- **WHEN** Android displays `[1] > Gemini` or `[1] > 🇩🇪 Germany 2`
- **THEN** the `1` and `2` have visible glyphs in ordinary and selected rows and in the connected current-node label
- **AND** all digits from `0` through `9`, plus literal `#` and `*`, remain visible rather than becoming blank emoji components

#### Scenario: Long names and provider labels on Android

- **WHEN** a node name requires more than two lines or its protocol/provider label requires more than one line at the selected Android text size
- **THEN** the row expands to display all text without ellipsis, overlap, or clipping within the row
- **AND** latency and selection feedback remain visible without replacing the name or metadata

#### Scenario: Android density, text scaling, and scrolling

- **WHEN** Android Home renders at 320–393 logical pixels wide with device-pixel ratio 3, system-bar insets, and text sizes from 80% to 140%
- **THEN** complete server names and protocol/provider text remain visible within their rows
- **AND** selected-row backgrounds and touch feedback cannot paint over the list heading or into the bottom system-bar inset when the row scrolls out of view

#### Scenario: Latency test action in the list header

- **WHEN** a user starts testing from the named icon beside Servers
- **THEN** the icon becomes progress, announces Testing, and prevents repeated submission until the batch ends
- **AND** untested, unavailable, and pending results keep neutral badges rather than implying a measured delay category

### Requirement: Automatic modes have defined behavior

The application SHALL provide functional Auto and Fallback choices even when the subscription omits such groups. Auto SHALL use latency and availability checks to choose an available server using the Core's URL-test behavior. Fallback SHALL select the first available server in a stable configuration/provider order and move to the next available server when required. Both SHALL use the same eligible server set as manual selection and SHALL NOT silently substitute direct routing when that set is unavailable.

#### Scenario: Imported configuration has no automatic groups

- **WHEN** a usable configuration contains only individual proxies or provider definitions
- **THEN** Auto and Fallback are both selectable and backed by functioning automatic groups

#### Scenario: Automatic mode changes its underlying server

- **WHEN** the Core changes the chosen server for Auto or Fallback
- **THEN** the corresponding automatic entry remains selected and any displayed underlying server updates without changing the user's mode selection

#### Scenario: No server responds to health checks

- **WHEN** none of the eligible servers currently passes a health check
- **THEN** the list remains available, the app does not claim internet reachability from that result, and neither automatic mode switches to direct routing

### Requirement: Connected Home identifies the current node

While the VPN is confirmed connected in simple routing, Home SHALL display the Core-observed node and its automatic mode/provider when applicable. It MUST resolve GLOBAL through the managed selector and automatic/nested targets, distinguish duplicate display names through catalog identity, and never substitute the saved selection for an unavailable observation. This describes the current outbound for new traffic, not a claim that every pre-existing connection has migrated.

#### Scenario: Auto or Fallback changes its node

- **WHEN** the active automatic group changes its underlying node
- **THEN** foreground Home refreshes its read-only observation every five seconds after the previous query completes and updates Current node without changing the selected mode, probing nodes, resetting connections, or changing VPN intent

#### Scenario: Observation is unavailable or stale

- **WHEN** a current-node query fails, remains pending for five seconds, refers to a different Core session/generation/configuration revision, has an unresolved or cyclic target, or completes after disconnect/profile replacement
- **THEN** Home shows an unavailable/checking label instead of claiming a saved or stale node is active
- **AND** slow queries do not overlap within an observation scope, timers/listeners are disposed, and polling pauses outside foreground Home and resumes with a fresh observation

#### Scenario: Custom routing uses different nodes

- **WHEN** the VPN is connected with custom routing enabled
- **THEN** Home explains that nodes depend on routing rules instead of presenting a single server as governing all traffic

### Requirement: Default routing follows the home selection

Newly imported profiles SHALL default to Auto and simple routing. In simple routing, all proxy traffic captured by the configured VPN/TUN/system-proxy mechanism SHALL use the selected server, Auto, or Fallback, regardless of the subscription's custom policy groups. Transport endpoints, DNS bootstrap, and operating-system exclusions required to establish the VPN SHALL continue to use their necessary underlying routes. The original configuration routing data MUST remain available in Settings.

#### Scenario: Subscription contains a different default outbound

- **WHEN** the user selects a server on Home while simple routing is active
- **THEN** captured proxy traffic uses that server rather than a different outbound chosen by subscription rules

#### Scenario: New profile is imported

- **WHEN** a new profile replaces the current profile successfully
- **THEN** Auto is selected and simple routing is active without inheriting stale group selections from the previous profile

### Requirement: Custom routing is an explicit advanced choice

Settings SHALL provide access to configuration/custom routing and its advanced group controls. Home SHALL indicate when custom routing is active so its saved simple-mode selection is not presented as governing every connection. Selecting a server or automatic entry on Home SHALL return the app to simple routing and apply that selection. Switching routing modes MUST preserve the imported source configuration and saved advanced settings.

#### Scenario: User enables configuration routing

- **WHEN** the user enables custom routing in Settings
- **THEN** the configuration's effective rules/groups govern routing and Home displays a clear custom-routing indicator

#### Scenario: User returns to simple selection

- **WHEN** the user selects Fallback on Home while custom routing is active
- **THEN** simple routing becomes active, Fallback is selected, and advanced routing settings remain available for later reuse

### Requirement: Selection persists and follows the current profile

The application SHALL persist the selected target and restore it when reopening the same profile. Selection while disconnected SHALL set the next connection target without starting the VPN. Selection while connected SHALL update the active route. Failed or superseded selection requests MUST NOT leave a stale target displayed as applied.

#### Scenario: Select before connecting

- **WHEN** the user selects a server while disconnected and then connects
- **THEN** the VPN connects using that server without another selection step

#### Scenario: Selection fails while connected

- **WHEN** the Core rejects a server selection
- **THEN** the previous applied selection remains visible and the application shows a recoverable error

#### Scenario: Rapid selections overlap

- **WHEN** selection A is followed by selection B before A completes
- **THEN** A's late result cannot overwrite or roll back B's current selection

### Requirement: Refresh and offline behavior retain a useful list

The application SHALL retain the last committed server inventory while offline or fetching a refresh. A successful refresh SHALL retain the selection when its target still exists; if it disappears, selection SHALL change to Auto and the user SHALL be informed. A failed refresh, including a refresh that produces no eligible servers, MUST retain the previous inventory and selection.

#### Scenario: Open without network access

- **WHEN** the app opens offline with a previously imported profile
- **THEN** its saved server list and selection are shown without requiring a fresh subscription download

#### Scenario: Selected server is removed by a successful refresh

- **WHEN** a committed refresh removes the manually selected server
- **THEN** Auto becomes selected and the interface reports that the previous server is no longer available
