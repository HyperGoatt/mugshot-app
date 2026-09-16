---
document_type: historical
status: checkpoint
last_verified: 2026-09-16
---

# Battery, thermal, and runtime audit — 2026-09-16

Current release authority: [Current product status](../CURRENT_PRODUCT_STATUS.md).

## Verdict

Available evidence supports Mugshot as a likely major contributor to the reported
drain, with **medium-high confidence**, but it does not prove that Mugshot was the
only cause or convert its work into the reported 95 percentage-point battery loss.
The strongest finding is a confirmed location lifecycle defect shared by
TestFlight 0.5.3 (7) and current source: multiple owners can start continuous,
best-accuracy location updates, authorization changes can start them without an
active-screen owner, and most owners never stop them. During likely incident-period
device snapshots, an active Mugshot process consumed 18–26% of one CPU core while
the system `locationd` process consumed roughly 101–155% of one core. The active
development installation also had nearby reminders enabled.

The release recommendation is **hold**. Do not distribute another build until
standard location updates are explicitly owned and stopped, the nearby-reminder
path is measured separately, and a physical-device background/locked A/B run no
longer reproduces sustained Mugshot or `locationd` work. Existing TestFlight build
7 contains the same location implementation. Evidence is weaker for that specific
installation because its preferences did not show nearby reminders enabled and the
incident process UUID could not be mapped conclusively to one of the two installed
bundle identities.

The reported battery percentage, Battery Settings attribution, incident start/end,
initial power state, and incident thermal timeline were not available through
CoreDevice. Instruments could enumerate all requested templates, but the physical
phone disconnected from the developer service before Time Profiler or Power
Profiler could record. Those limits prevent a quantitative battery-causality claim.

## Scope, identity, and safety

Documentation impact is privacy/safety/operations and release state. This audit
changes no app behavior, public API, database, production data, or distribution.
Raw device logs, preferences, memgraphs, and traces remain outside tracked source
under `/tmp/mugshot-audit-2026-09-16/`; account, device, and content identifiers are
not reproduced here.

| Item | Preserved evidence |
| --- | --- |
| Physical device | iPhone 16 Pro, iOS 27.0 (24A435) |
| Installed production identity | `co.mugshot.app`, 0.5.3 (7) |
| Installed development identity | `co.mugshot.app.dev`, 0.5.3 (7) |
| Initial process state | Development bundle executable was already running; production bundle was not running |
| Exact TestFlight source | `bead2de1efef247cd6dc36bcb2a9e296a4a6db2a`, recorded by the existing build-7 release evidence |
| Current source audited | `82add40f246b1d117dd0e4c9a6e4be41f11e7d04`; six commits and 107 changed files after build 7 |
| Development-build source | Not recoverable from the installed binary; initial bundle path proved identity, not commit |
| Permission-backed preference state | Development nearby reminders enabled; production key absent, which resolves to disabled in this implementation |
| Pending local work | Zero pending visit submissions in both installs; development install had two bounded drink-analysis retry records; production had none |
| Battery, charger, thermal, brightness | Not exposed by the available CoreDevice detail command; unknown at baseline |
| Post-capture control | The development process was terminated after evidence preservation; neither Mugshot process remained afterward. This is a force-quit control, not normal suspension. Relaunch for Power Profiler was blocked because the phone was locked. |

The build-7 and current copies of `LocationManager.swift` and
`NearbyCafeReminderCoordinator.swift` have identical SHA-256 hashes. The retained
tab construction also exists in both revisions. Findings that apply only to current
source are labeled separately.

## Target, capability, and dependency inventory

| Target or dependency | Runtime relevance |
| --- | --- |
| Main app `testMugshot` | SwiftUI/UIKit app; camera, Photos, When In Use and Always location descriptions; production APNs, Sign in with Apple, associated domains, and app-group entitlements |
| `MugshotWidgets` | One WidgetKit extension; no custom entitlement; static links only and a `.never` timeline |
| `MugshotShareExtension` | Share extension for text or one web URL; app-group entitlement; cancellable Apple Maps search |
| Unit and UI test targets | Not embedded as shipping runtime services |
| PostHog iOS 3.68.4 | Analytics queue/timer and lifecycle integration; replay, surveys, autocapture, screen capture, and swizzling disabled by Mugshot |
| Supabase Swift 2.54.1 | Auth, database, functions, and Storage networking; no background `URLSession` configuration in app source |

The main `Info.plist` declares no `UIBackgroundModes`. No BG task identifier,
background URL session, audio mode, microphone, Bluetooth, motion, HealthKit, NFC,
or speech permission/service was found. The inspected current Simulator binary had
no entitlements, as expected for that build; the iPhone Debug build settings select
development APNs, associated domains, and the app group, while Release selects the
production entitlement file with production APNs, Sign in with Apple, associated
domains, and the same app group.

## Incident-period device evidence

Nine jetsam snapshots were available from 07:37 through 10:48 EDT. Jetsam logs are
system memory-pressure snapshots, not proof that Mugshot caused the jetsam event.
They are useful here because they contain cumulative per-process CPU and memory.
No Mugshot process appeared in the first three snapshots. Later snapshots contained
two Mugshot binary UUIDs, consistent with two installed identities, but the logs do
not include bundle IDs and neither historical executable UUID was recoverable from
the local build cache.

For intervals where the same PID survived across snapshots:

| Interval (EDT) | Wall time | Mugshot CPU delta | Approx. one-core utilization | `locationd` CPU delta | Approx. one-core utilization |
| --- | ---: | ---: | ---: | ---: | ---: |
| 08:51:01–08:51:34 | 33 s | 8.453 s | 25.62% | 51.152 s | 155.01% |
| 08:51:34–09:34:59 | 2,605 s | 5.912 s | 0.23% | 37.883 s | 1.45% |
| 10:08:36–10:09:52 | 76 s | 19.088 s | 25.12% | 108.047 s | 142.17% |
| 10:09:52–10:48:25 | 2,313 s | 419.501 s | 18.14% | 2,326.652 s | 100.59% |

The percentage is cumulative CPU seconds divided by wall seconds. Values above
100% mean work across more than one core. They are not an Instruments energy score
and must not be converted into battery percentage.

The active Mugshot PID at 08:51–09:34 held about 60 MiB resident and peaked near
127 MiB. The later active PID held about 164 MiB resident and had a lifetime peak
near 328 MiB. Mugshot was never the largest process in these jetsam events and was
not selected for termination. Other prominent processes included Spotify in one
snapshot and an on-device inference service in earlier snapshots.

The device diagnostic index contained no Mugshot CPU-resource, disk-write-resource,
hang, thermal-resource, or crash report from September 16. Four September 14
development-build watchdog reports were available. One scene-update timeout used
0.103 app CPU seconds during a 10-second wall timeout; three graceful-termination
timeouts used 0.004–0.052 app CPU seconds. All recorded thermal state `serious`, but
the stacks were blocked in system pasteboard/keyboard XPC and total system CPU was
much higher than app CPU. They prove that the device has reached serious thermal
state during earlier development testing; they do not attribute the September 16
drain to Mugshot CPU.

## Runtime measurements

Current source built and launched on the already-booted iPhone 17 Pro Simulator,
iOS 27.0 (24A5380i). The existing signed-in Simulator state was walked through Feed, Map, Saved, and
Journal, then returned to Feed so all four retained tabs were mounted. Focused
captures were separated to limit profiler interference.

Time Profiler records one-millisecond running samples. Approximate utilization
below is running sample count divided by wall time and describes one simulated CPU
core. It is useful for detecting runaway work, not physical energy consumption.

| Current-source scenario | Duration | Running samples | Approx. one-core CPU | Result |
| --- | ---: | ---: | ---: | --- |
| Settled Feed after launch/network warm-up | 30.832 s | 47 ms | 0.152% | Low; samples included image authorization/network and keychain work |
| Settled Map, foreground | 30.882 s | 24 ms | 0.078% | Low in static simulated location |
| Map then Simulator Home/background | 30.703 s | 13 ms | 0.042% | Low; no runaway background CPU observed |
| Feed after Map/Saved/Journal retention | 45.752 s | 79 ms | 0.173% | Low; retained animations did not produce material CPU in this condition |

A memgraph captured after the four-tab walk reported 204.9 MiB physical footprint,
219.5 MiB peak, and 46 leak candidates totaling 1,568 bytes. Forty were anonymous
32-byte zone allocations and six were SwiftUI material-observer array storage. No
candidate had an app-owned type or an ownership path into Mugshot. This does not
prove the app is leak-free, but it found no actionable app leak in the exercised
flow. The same heap contained four live `CLLocationManager` objects and three
SwiftUI boxes observing `LocationManager`, confirming multiple location owners
remain resident after navigation.

The Simulator Network template failed because Network Connections is unsupported
on that platform. The SwiftUI template failed because SwiftUI and Hitches are
unsupported on this Simulator runtime. Physical Time Profiler and sysdiagnose
attempts disconnected from the developer service; a later physical relaunch was
denied while the phone was locked. Power Profiler, System Trace, physical Network,
physical SwiftUI, Metal System Trace, wakeup counts, GPU counters, and a physical
thermal timeline therefore have no valid capture in this checkpoint.

## Scenario and coverage ledger

| Scenario | State | Evidence obtained | Remaining experiment |
| --- | --- | --- | --- |
| Initial control | Partially completed | Preserved installs, versions, initial running dev process, preferences, pending work, and process/log history; then terminated the running dev process and confirmed neither identity remained | Record battery, thermal, wakeups, and `locationd` in a normal-suspension arm and a force-quit arm |
| Cold/warm launch and normal use | Simulator completed; physical launch blocked after preservation | Current source built/launched; Feed, Map, Saved, Journal, and navigation exercised | Repeat on the installed build with physical Time Profiler and Power Profiler |
| Foreground idle | Focused short captures completed | Four low-CPU 30–46 second Time Profiler captures | Three repeated 10-minute captures per principal screen on device |
| Media lifecycle | Static lifecycle audit completed; physical workflow not run | Current source delegates camera ownership to `UIImagePickerController`; build 7 custom capture stops its `AVCaptureSession` and countdown task on disappear | Open/cancel/capture/select/process/dismiss ten times on device; compare memory and camera indicator after each dismissal |
| Upload and recovery | State and code audited; write-producing test not run | Both installs had zero pending visit submissions. Recovery is FIFO, cancellation-aware between operations, and suppresses repeated automatic failure | Isolated account: success, offline interruption, reconnect, background during each network await, then inspect tasks/network |
| Background and lock | Simulator background capture completed; physical blocked | No Simulator runaway CPU; physical historical snapshots show active Mugshot and high `locationd` CPU | 30-minute unlocked-background and locked intervals after ordinary, Map, camera, and upload use |
| Location and notifications | Code, preferences, and historical process evidence completed | Dev nearby preference enabled; production absent; location ownership defect confirmed; real authorization level unavailable | Movement route with reminders enabled/disabled and When In Use/Always transitions |
| Extended attribution | Not completed | Historical CPU correlation only; no battery percentage attribution | Counterbalanced three-hour unplugged control and Mugshot arms, repeat any difference before causality claim |

## Ranked findings

Contribution rank estimates the reported battery/thermal effect. Confidence ranks
the evidence for the finding itself. A confirmed lifecycle defect is not described
as measured battery impact unless physical energy evidence exists.

| Rank | Finding | Classification | Probable contribution | Confidence |
| ---: | --- | --- | --- | --- |
| 1 | Unowned continuous best-accuracy location updates across multiple managers | Confirmed lifecycle defect; energy impact strongly suspected | Very high | High for defect; medium-high for incident contribution |
| 2 | Nearby-reminder background location was enabled on the active dev installation | High-risk hypothesis; feature work is expected when explicitly enabled | High if movement/wakes occurred | Medium |
| 3 | Recovery tasks can continue after the app becomes inactive | Confirmed lifecycle defect; no incident workload found | Low for this incident, medium for affected uploads | High for defect |
| 4 | Physical memory reached a 328 MiB lifetime peak | High-risk measurement gap; no leak proved | Low to medium | High for peak, low for cause |
| 5 | Passport ornament animates in a retained offscreen tab | Confirmed lifecycle inefficiency; measured low in Simulator | Low | High |

### 1. Continuous location has no single owner or complete stop path

- **Severity and impact:** Critical, release-blocking. It can keep GPS/location
  processing and the app runnable after the user leaves the relevant screen,
  producing heat and rapid drain.
- **Location and applicability:**
  `testMugshot/Services/LocationManager.swift:15-55,98-106`,
  `testMugshot/Views/MainTabView.swift:66-83,689-699`,
  `testMugshot/Views/Add/AddTabView.swift:274-294,570-573`, and
  `testMugshot/Views/Add/SipComposerView.swift:2023-2028,4791-4795`.
  Applies to build 7 and current source.
- **Evidence:** Every `LocationManager` owns a `CLLocationManager` configured for
  `kCLLocationAccuracyBest` and a 10-meter filter. `startUpdatingLocation()` does
  a one-shot request and then starts continuous updates. The authorization callback
  starts continuous updates for either authorized state without checking scene or
  screen ownership. Seven SwiftUI sites instantiate this wrapper. Retained tabs
  remain mounted at zero opacity. The post-navigation memgraph contained four live
  Core Location managers. Physical snapshots then measured repeated 18–26% Mugshot
  CPU intervals alongside 101–155% `locationd` CPU intervals.
- **Reproduction conditions:** Location authorized; construct any affected owner
  or visit Map/Add/search routes; then stop interacting, switch tabs, background,
  or lock. Exact background persistence depends on iOS suspension, nearby-monitor
  wakes, movement, and the authorization level.
- **Root cause:** One wrapper conflates a one-shot location need with indefinite
  tracking. Authorization changes can acquire tracking implicitly, while lifecycle
  stops cover only the shell's Map manager. There is no lease/token model, shared
  owner, `deinit` stop, or universal inactive-tab/scene cancellation.
- **Smallest fix:** Make one-shot `requestLocation()` the default. Remove continuous
  start from the authorization callback. Permit continuous updates only through an
  explicit owner lease tied to active Map UI, and stop it on tab loss, scene
  inactivity, and owner deallocation. Route search/composer/feed/profile consumers
  through a shared last-location/one-shot service. Add debug signposts for every
  acquire/release and the number of live standard-location clients.
- **Expected improvement:** Standard GPS/location processing should stop outside
  the active route, removing the leading source of app and `locationd` work. A
  battery percentage cannot be promised before the physical A/B test.
- **Verification:** On the installed candidate, record Power Profiler plus Time
  Profiler while visiting each location consumer, returning to Feed, backgrounding,
  and locking for 30 minutes. Require zero standard-update owners outside active
  Map interaction, no attributable background CPU samples, no thermal escalation,
  and a repeated three-hour discharge result indistinguishable from force-quit
  control within measurement noise.

### 2. Nearby reminders can relaunch or wake the app and were enabled on dev

- **Severity and impact:** High when enabled. Significant-change and region
  monitoring are valid opt-in features, but they are the only intentional
  background hardware path and can amplify the standard-location defect.
- **Location and applicability:**
  `testMugshot/testMugshotApp.swift:16-20` and
  `testMugshot/Services/NearbyCafeReminderCoordinator.swift:47-73,105-160,207-236`.
  Applies to build 7 and current source.
- **Evidence:** App initialization constructs the singleton. A persisted enabled
  bit immediately starts significant-change monitoring. Refresh tears down and
  recreates up to 20 regions, then starts significant-change monitoring again.
  The development install's enabled bit was true; the production install had no
  bit. Device snapshots show extreme `locationd` CPU, but system logs do not name
  the responsible Core Location client, so attribution remains inferential.
- **Reproduction conditions:** Preference enabled, location authorization
  compatible with background delivery, device movement or region/significant-change
  delivery, and enough eligible saved cafes for region registration.
- **Root cause or uncertainty:** The work may be expected delivery, redundant
  reconfiguration, or another location client. Actual authorization, monitored
  region count, delivered events, and `locationd` client attribution were not
  available.
- **Smallest fix:** Keep the feature disabled as the release default until measured.
  Start monitoring only when enabled, authorized Always, and at least one eligible
  cafe exists. Fingerprint the desired region set and skip unchanged refreshes.
  Add privacy-safe signposts/counters for start, stop, region-set change, wake,
  notification delivery, and current authorization. Retain a remote kill switch.
- **Expected improvement:** Fewer region registrations and background wakes; if
  this hypothesis caused the incident, the enabled/disabled physical delta should
  be large.
- **Verification:** Run the same 30-minute lock and three-hour movement route with
  reminders off then on, counterbalance order, keep other location apps closed,
  and compare Mugshot CPU, `locationd` CPU, wakeups, thermal state, and discharge.

### 3. Recovery work is not cancelled when scene activity ends

- **Severity and impact:** Medium. An upload, reconciliation, or Home synchronization
  that began in foreground may continue into the background until iOS suspends it
  or the await returns.
- **Location and applicability:**
  `testMugshot/Services/AutomaticSipRecoveryCoordinator.swift:114-127,159-165,210-234`.
  The visit-recovery behavior applies to build 7 and current source; Home recovery
  is current-source only.
- **Evidence:** Eligibility requires `isAppActive`, but `setAppActive(false)` does
  not cancel `recoveryTask` or `homeRecoveryTask`. Account changes do cancel both,
  and visit recovery checks cancellation between remote steps. Both installed
  identities had zero pending visit records, so this path does not explain the
  observed incident. The dev install had two bounded drink-analysis retries, each
  attempted once by an account-scoped SwiftUI task rather than a timer or loop.
- **Reproduction conditions:** A pending recovery starts while active and the app
  backgrounds before the current remote operation completes.
- **Root cause:** Activity gates task creation but does not own the lifetime of an
  already-created task.
- **Smallest fix:** Cancel both tasks when activity becomes false, clear their run
  IDs safely, and recheck activity after each awaited operation before starting the
  next step. Resume idempotently on foreground.
- **Expected improvement:** Prevent network, encoding, and persistence work from
  extending into background for interrupted recovery cases.
- **Verification:** With isolated content and a throttled/offline network, background
  during reconcile, upload, finalization, and Home sync. Confirm task cancellation,
  no further network/file events, intact durable records, and one idempotent resume.

### 4. Memory high-water mark needs a media-loop comparison, but no leak is proved

- **Severity and impact:** Medium risk for memory pressure and secondary CPU; low
  confidence as an incident cause.
- **Location and applicability:** Image caches in
  `testMugshot/Services/RemoteImagePipeline.swift:5-28`,
  `testMugshot/Services/ProtectedImageStore.swift:6-29`, and
  `testMugshot/Services/PhotoCache.swift:23-54`. Both builds use bounded caches;
  exact current-source implementations differ after build 7.
- **Evidence:** Physical lifetime peak was about 328 MiB and current resident about
  164 MiB in the later snapshot. The exercised Simulator flow used 204.9 MiB with
  a 219.5 MiB peak. Leaks found only 1,568 bytes of framework/anonymous allocations
  and no app ownership chain. Mugshot was never the jetsam victim.
- **Reproduction conditions:** Unknown on physical device; likely sensitive to
  photo count, decoded dimensions, and repeated media/detail presentation.
- **Root cause or uncertainty:** Bounded image caches and retained SwiftUI views can
  explain a substantial working set. No monotonic growth or retained camera/session
  object was demonstrated.
- **Smallest fix:** Do not change cache policy without a growth trace. First add a
  ten-cycle camera/library/detail test and capture allocation generations. If growth
  persists, identify the retaining path and lower only the responsible cache or
  clear it on memory warning/account transition.
- **Expected improvement:** Unknown until a retained owner is identified; a correct
  fix would return near baseline after dismissal and reduce memory-pressure work.
- **Verification:** Record Allocations generations before and after ten media cycles,
  issue a memory warning, capture a second memgraph, and require stable retained
  counts for images, controllers, sessions, tasks, and location managers.

### 5. A retained offscreen passport animation lacks activity gating

- **Severity and impact:** Low. It can cause unnecessary foreground rendering after
  Journal has been visited, but the measured cost was small.
- **Location and applicability:**
  `testMugshot/Views/Components/MugshotPassportCard.swift:63-68` plus retained tabs
  in `testMugshot/Views/MainTabView.swift:66-83`. Applies to build 7 and current.
- **Evidence:** `repeatForever` begins on appear and does not read tab activity or
  scene phase. Journal remains mounted at zero opacity. The retained-tab Time
  Profiler capture nevertheless averaged only about 0.17% of one simulated core.
- **Reproduction conditions:** Visit Journal so the card appears, switch to another
  retained tab, leave the app foreground and idle, with Reduce Motion disabled.
- **Root cause:** Animation lifetime follows view retention rather than visibility.
- **Smallest fix:** Gate the ornament by `isMugshotTabActive` and active scene phase,
  or render a static state while inactive.
- **Expected improvement:** Removes avoidable foreground display updates; unlikely
  to explain severe drain by itself.
- **Verification:** Compare SwiftUI/Animation Hitches and Time Profiler on physical
  hardware for Journal visible, Journal retained offscreen, and the gated build.

## Expected or bounded resource use

- **Camera:** Current source uses Apple's `UIImagePickerController` and owns no
  `AVCaptureSession`. Build 7 owned a custom session, but its view calls `stop()`
  and clears the capture callback on disappear; `stop()` cancels its countdown and
  stops the running session on the session queue. Physical repeated-dismissal proof
  remains missing.
- **Protected images:** Both builds gate renewal on active scene and active tab,
  use cancellable SwiftUI `.task` lifetimes, coalesce in-flight loads, and bound
  decoded memory. This is expected visible-content work, not an observed background
  loop.
- **Image processing:** Network images are downsampled to 1,200 pixels on a utility
  task. Local JPEG writes and disk reads are bounded to explicit image operations.
  No periodic encoder or preloader call site was found.
- **Analytics:** PostHog 3.68.4 uses a 30-second foreground run-loop timer, batches
  at 20 events, limits retries to three, and flushes on background. Mugshot disables
  screen autocapture, element autocapture, session replay, surveys, and swizzling;
  it uses an ephemeral 15/30-second session. A timer may fire while the process is
  runnable, but no evidence makes it a plausible 18–26% CPU source.
- **Networking and retries:** Supabase 2.54.1 and explicit app services perform
  request-driven operations. Visit and Activity `while true` loops are bounded
  pagination that return when a page is short. Search tasks cancel prior searches.
  Upload recovery makes a finite FIFO pass and suppresses further automatic retry
  after a failure.
- **Widgets and extensions:** The widget returns one timeline entry with policy
  `.never`. The share extension owns one cancellable search task and at most one
  bounded broad-search retry after 500 ms. Neither provides periodic app work.
- **Hardware/services:** No microphone, Bluetooth, motion, HealthKit, NFC, or speech
  permission string or service owner was found. Camera, Photos, notifications,
  Apple Maps, and Core Location are the permission-backed surfaces. There is no
  declared `UIBackgroundModes`, `BGTaskScheduler`, background `URLSession`, audio,
  or custom Metal workload.
- **Logging/instrumentation:** Debug-only launch hooks and vector export are behind
  `#if DEBUG`. OS logging is event/error driven. No production polling logger,
  crash-reporter SDK, or session-replay SDK is configured.

## Evidence pointing away from Mugshot or from other hypotheses

- Settled current-source Simulator traces did not reproduce runaway CPU in Feed,
  Map, retained tabs, or background.
- Neither install had pending visit upload/recovery records; upload recovery is not
  a supported explanation for this incident. Two dev drink-analysis retries were
  bounded launch work, not a repeating loop.
- The production/TestFlight preference domain did not have nearby reminders
  enabled. This weakens the reminder-specific hypothesis for that identity.
- No September 16 Mugshot CPU-resource, disk-write-resource, hang, crash, or thermal
  exception was present in the device diagnostics that were accessible.
- Mugshot was not the jetsam victim or largest-memory process. The Simulator
  memgraph found no app-owned leak path.
- Camera teardown exists in build 7; current source delegates the capture session
  to the system picker. No microphone, Bluetooth, or motion service can explain the
  drain from this source.
- The low-CPU 08:51–09:34 interval proves the active Mugshot binary was not
  continuously busy for every observed minute. The severe periods were episodic.
- `locationd` is shared by all location clients. Its CPU correlation supports the
  location hypothesis but cannot exclude another app or an iOS location-service
  problem. Spotify and an on-device inference service were prominent in some
  snapshots, and the older serious-thermal watchdog logs show system work with
  negligible Mugshot CPU.

Negative results apply only to the named build, route, duration, and static
Simulator location. They do not disprove an unreproduced historical incident.

## Trace and artifact index

| Artifact | Scope | Result | Storage |
| --- | --- | --- | --- |
| Nine September 16 jetsam logs | Physical, historical | Valid; source for CPU/memory deltas | Local-only `device-logs/` |
| Four September 14 watchdog logs | Physical, historical | Valid; pasteboard/termination and serious thermal context | Local-only `device-logs/` |
| Feed idle Time Profiler | Current Simulator | Valid, symbolicated | `simulator-feed-idle-time-profiler.trace` |
| Map idle Time Profiler | Current Simulator | Valid, symbolicated | `simulator-map-idle-time-profiler.trace` |
| Map background Time Profiler | Current Simulator | Valid, symbolicated | `simulator-map-background-time-profiler.trace` |
| Retained-tabs Feed Time Profiler | Current Simulator | Valid, symbolicated | `simulator-retained-tabs-feed-45s-time-profiler.trace` |
| Post-navigation memgraph/leaks | Current Simulator | Valid; no app-owned leak path | `memgraphs/co.mugshot.app-*.memgraph` and sanitized summary |
| Physical all-process Time Profiler | Physical | Invalid; device disconnected immediately | Kept only as failed-capture evidence |
| Simulator Network | Current Simulator | Invalid; template unsupported | Kept only as failed-capture evidence |
| Simulator SwiftUI | Current Simulator | Invalid; SwiftUI/Hitches unsupported | Kept only as failed-capture evidence |
| Physical Power Profiler/System Trace/Network/Metal | Physical | Not captured; developer service/locked-device boundary | No valid trace |
| ETTrace | Simulator | Not integrated; focused Time Profiler provided symbolicated CPU evidence without modifying the app target | No artifact |

## Release gate and next experiments

1. Fix location ownership first; do not combine it with unrelated refactors.
2. Add privacy-safe location acquire/release/wake signposts in development builds.
3. Run 10-minute screen-specific foreground captures and 30-minute normal
   background/locked captures on the installed candidate, including a movement
   route with reminders off and on.
4. Run the ten-cycle camera/library/media retention experiment and the interrupted
   upload/background matrix with isolated content.
5. Run counterbalanced three-hour unplugged control and Mugshot arms only after the
   focused traces are clean. Repeat any observed difference before assigning a
   discharge rate to Mugshot.
6. Retrieve the iOS Battery Settings view for the reported interval. It must show
   the selected chart interval and the App & System Activity list so screen-on,
   screen-idle, and per-app attribution can be separated.

Release can resume when the location owner count returns to zero outside intentional
active use, no sustained app or `locationd` work follows background/lock, no thermal
state escalation is attributable to Mugshot, the media and recovery matrices show
bounded lifetimes, and repeated three-hour discharge is not materially above the
matched force-quit control.
