# Observability: logging and performance

> **Revised 2026-11-13.** The first version of this note, from 2026-10-27, covered a Go server, OpenTelemetry tracing across app and server, an AI provider, MCP, sync, hosted telemetry backends and product analytics. [ADR 0001](../adr/0001-local-only-app-with-no-backend.md) dropped the server and made the app send nothing off the phone. This revision keeps the iOS parts, removes the rest, and adds the operations of the current [vision](../VISION.md). The original is in git history.

Research date: 2026-10-27. Versions were checked against GitHub releases, Apple's documentation JSON and the local Xcode 27.1 toolchain on that date. Anything marked **unverified** could not be confirmed from a primary source.

This builds on [agent-guardrails-and-testing.md](agent-guardrails-and-testing.md) (the guardrail layers and the Simulator test setup) and does not repeat it.

**Performance is the point.** The owner's main reason for observability is speed: knowing how fast the app is, catching regressions before they ship, and letting an agent run experiments to make things faster. Logging serves that goal. Section 3 is the core of the file.

## Summary

- **Few logs, many measurements.** Log one line per unit of work plus errors. Measure durations with signposts, not with "started" and "finished" log pairs. Debug logs are off outside development. An e2e run fails if a scenario logs more lines than its budget or emits an unexpected warning or error.
- **Every e2e run produces `build/e2e/<run-id>/perf.json`.** It lists per-operation timings (launch to keyboard, keystroke, save, flick to view mode, search, scrolling the notes list), each with sample count, median and p95, compared against committed budgets and a stored baseline. The run fails on a budget breach or on a regression larger than both a relative and an absolute threshold.
- **Noise is handled by design, not hope.** Use a dedicated simulator model and runtime, one discarded warm-up, 5 to 10 repetitions, medians and p95, and an absolute floor so tiny jitter can't fail a build. For keep-or-discard decisions, compare base and candidate interleaved on the same machine. Stored numbers are only for coarse CI gates.
- **Route all logging through one small typed `Telemetry` module.** It wraps `os.Logger` and `OSSignposter`. Event names, fields and operations are Swift enums, and no case accepts a free-form string. Note text can't be logged because the API has nowhere to put it.
- **Nothing leaves the phone.** There is no analytics SDK, no crash reporter that uploads, and no telemetry backend. Field data comes from MetricKit, kept on the device, and from a diagnostics file the owner can choose to share. The app can declare that it collects no data.

---

## 1. Primer for someone new to this

### 1.1 The signals

| Signal | What it is | Good for | In this app |
|---|---|---|---|
| **Log** | A timestamped record with a message and fields. | "What happened, and why did it fail?" | `os.Logger`. Few lines, at boundaries. |
| **Signpost** | Apple's name for a lightweight interval or point event recorded through unified logging, shown on the Instruments timeline. | Timing operations during development and in XCTest performance tests. | `OSSignposter` intervals for every budgeted operation. |
| **Metric** | A number aggregated over time: counts, durations, percentiles. | "How fast, at what percentile?" over many runs. | `perf.json` per e2e run. MetricKit daily reports on the phone. |
| **Profile** | Samples of where CPU time or memory goes, by function. | "Which function is hot?" once you know an operation is slow. | Instruments, or `xctrace` from the command line. |

A slow number in `perf.json` leads to the signpost interval that was slow, and a profile of that interval explains the hot function.

### 1.2 Fields

A field is a key and value attached to a log line, such as `note.op.name=search.query` or `note.count=812`. Keys are lowercase and dot-separated, with the app's own `note.` prefix. Section 5 lists the allowed keys.

### 1.3 What "good" looks like here

- Every user-visible operation has a measured duration with a budget, and every e2e run reports it.
- A normal e2e scenario produces a handful of log lines, none above `info`, and zero lines containing a note's text.
- When a number gets worse, the change that made it worse fails.

---

## 2. Logging policy: few lines, high signal

### 2.1 What earns a log line

| Log it | Don't log it |
|---|---|
| One **wide event** per unit of work: the app launched, a note was saved, a search ran, an export finished. Put every useful field on that one line (IDs, sizes, counts, outcome, duration). | "Entering function", "starting X", "done X". Use a signpost interval. |
| Errors the app did not recover from (`error`). | Every retry attempt. Count retries as a field on the final line. |
| Recovered problems worth knowing about (`warn`), such as a database migration that took longer than expected. | Expected outcomes, such as "search found nothing". That is an `info` event with an outcome field, not a warning. |
| Rare state changes: migration applied, trash purged, theme changed. | Anything per keystroke, per row, per loop iteration, or per cache hit. |

The "one wide line per unit of work" idea is Stripe's [canonical log lines](https://stripe.com/blog/canonical-log-lines). Apple's own [logging guide](https://developer.apple.com/documentation/os/generating-log-messages-from-your-code) suggests messages at the start and end of functions and before each step of a multi-step task. I disagree for persisted logs in this app: those are exactly the intervals a signpost records better, with a duration and almost no cost.

**Log or return, not both.** A function that returns an error doesn't also log it. The place that handles the error logs it once, so one failure produces one line.

### 2.2 Levels and defaults

| Level | `Logger` | Persisted? | Default on |
|---|---|---|---|
| debug | `.debug` | No, memory only | Developer machines only, switched on per run |
| info (boundary events) | `.notice` (`.default`) | Yes, up to a storage limit | Everywhere, including e2e |
| warn | `.error` with an outcome field | Yes | Everywhere |
| error | `.error` | Yes | Everywhere |
| fault (a bug, an invariant broken) | `.fault` | Yes | Everywhere |

The persistence column is from Apple's [log level table](https://developer.apple.com/documentation/os/generating-log-messages-from-your-code): debug is never persisted, info only "when collected with the log tool", and notice, error and fault are written to disk "up to a storage limit". `.info` is skipped here because it is neither cheap chatter nor reliably kept.

### 2.3 Enforcing "no useless logs"

1. **A typed event list.** Every log message is a case of one `Event` enum. Adding a log line means adding a case, which is a visible one-line diff a reviewer or agent can question. `Telemetry.event(_:)` takes that enum, so there is nothing else to pass.
2. **A log budget in every e2e run.** `scripts/log-budget` reads `app.log` for the run and fails if:
   - any `warn`, `error` or `fault` line appears that the scenario didn't declare as expected;
   - a scenario exceeds its line budget (start with one line per app operation, plus 3 startup lines);
   - the same event repeats more than 3 times within one operation (chatter detection).
   The result goes into `perf.json` under `log_budget`, so the agent sees it with the timings.
3. **CLAUDE.md, the weakest layer:** "One log line per unit of work, plus errors. Durations go in signposts, not logs."

---

## 3. Performance: measure, budget, compare, investigate

### 3.1 What to measure

Budgets below are starting points for the owner to tune. "Sim" numbers are for the iOS Simulator on a Mac and are only meaningful relative to each other (see 3.5). Each operation is measured when the feature it belongs to is built.

| Operation (`note.op.name`) | Starts | Ends | Recorded by | Initial budget |
|---|---|---|---|---|
| `app.launch` | Process start (system) / `App.init` (in-app) | Text field is first responder with the keyboard up | `XCTApplicationLaunchMetric(waitUntilResponsive: true)` in a UI test, plus a signpost interval from `App.init` to keyboard-up | Device: first frame under 400 ms, the goal Apple states in [WWDC19 "Optimizing App Launch"](https://developer.apple.com/videos/play/wwdc2019/423/). Sim: p95 under 600 ms to keyboard-up. |
| `note.keystroke` (main-thread work per keystroke) | Text change callback | Callback returns | Signpost interval; `XCTOSSignpostMetric` | p95 under 5 ms. Apple suggests "a limit of 5 ms" for work during continuous interaction ([Improving app responsiveness](https://developer.apple.com/documentation/xcode/improving-app-responsiveness)). |
| `note.save` | Save flick | Transaction committed, including the search index | Signpost interval | p95 under 50 ms for the write. |
| `note.view` | Flick into view mode | Formatted note on screen | Signpost interval | p95 under 100 ms for a long note. |
| `search.query` | Keystroke in the search field | Results on screen | Signpost interval | p95 under 50 ms with 10,000 notes. |
| `notes.scroll` | Scripted fling through the notes list | Scrolling stops | `XCTHitchMetric(application:)` (present in Xcode 27.1's `XCTMetric+UIAutomation.h`, iOS 26+) | Zero hitches with 10,000 notes. |
| `export.run` | Export starts | Last file written | Signpost interval | Report only, no budget until there is data. |
| Hitches during the screen swipes and flicks | | | `XCTHitchMetric(application:)` | Zero hitches in the scripted swipes. |

`notes.scroll` and `search.query` need a large fixture to mean anything. The `E2E` configuration's fixture loader generates notes from parameters ("10,000 notes, mixed lengths"), so the same scenario can be scaled.

### 3.2 How an operation is recorded

One call wraps the work:

```swift
try await Telemetry.measure(.noteSave, .noteID(note.id), .textLength(note.text.utf8.count)) {
    try await storage.save(note)
}
```

It does two things. It begins and ends an `OSSignposter` interval named after the operation, so Instruments and `XCTOSSignpostMetric` see it. On completion it writes one `op.end` line through `Logger` with `note.op.name`, `note.op.duration_ms` and the fields. The log line is what `perf.json` and agents read; the signpost is what Instruments and XCTest read. `OSSignposter` interval names must be `StaticString`, so `Op` maps each case to a literal in a `switch` ([OSSignposter](https://developer.apple.com/documentation/os/ossignposter), [Recording performance data](https://developer.apple.com/documentation/os/recording-performance-data)). Signposts are cheap enough to leave on: WWDC18 [Measuring Performance Using Logging](https://developer.apple.com/videos/play/wwdc2018/405/) calls them "lightweight", and a disabled log handle makes them near no-ops.

### 3.3 Every e2e run writes `perf.json`

`make e2e` (from the guardrails note) gains a final step, `scripts/perf-report`, using `jq` (it ships in macOS at `/usr/bin/jq`, so nothing to install). Inputs, all under `build/e2e/<run-id>/`:

| File | Producer | Gives |
|---|---|---|
| `app.log` | `xcrun simctl spawn <udid> log stream --style ndjson --level debug --predicate 'subsystem == "com.rontho14.note"'` started before the app launches | `op.end` lines with durations |
| `*.xcresult` | `xcodebuild test` of the `NotePerfTests` UI target | `XCTApplicationLaunchMetric`, `XCTOSSignpostMetric`, `XCTHitchMetric` samples via `xcrun xcresulttool get test-results metrics --path <bundle> --compact` (subcommand and its JSON schema checked locally on Xcode 27.1) |

`log stream` supports `--style ndjson` and `--timeout` (checked with `log help stream`), so app logs arrive one JSON object per line.

Output, one file per run:

```json
{
  "schema": 1,
  "run_id": "20261027T140311Z-ab12cd",
  "git_sha": "26bcffc", "dirty": false,
  "host": { "class": "local-m3", "macos": "26.6.2", "xcode": "27.1" },
  "simulator": { "model": "iPhone 17", "runtime": "iOS 27.1" },
  "fixture": "notes-10000",
  "ops": [
    { "op": "app.launch", "unit": "ms", "warmup": 1, "n": 10,
      "median": 412, "p95": 455, "budget_p95": 600,
      "baseline_median": 405, "delta_pct": 1.7, "status": "ok" },
    { "op": "search.query", "unit": "ms", "n": 40,
      "median": 18, "p95": 31, "budget_p95": 50, "status": "ok" }
  ],
  "log_budget": { "status": "ok", "unexpected": [], "over_budget": [] },
  "verdict": "pass"
}
```

**Fail rules.**

- **Budget:** p95 above `budget_p95` in `perf/budgets.json` (committed) fails, always.
- **Regression:** median worse than the baseline median by more than 15% **and** by more than an absolute floor (20 ms for screen operations, 5 ms for database operations) fails. Both conditions are needed so a 2 ms operation that becomes 3 ms doesn't fail a build.
- **Missing data:** an operation with `n` below its expected count fails, because a missing measurement usually means a missing signpost or a broken flow.

### 3.4 Keeping the numbers stable

- **Fixed environment.** The `Note-E2E` simulator is always the same model and runtime, recorded in `perf.json`. Status bar and animations are fixed by the `E2E` configuration.
- **Warm-up and repetitions.** Discard the first iteration. XCTest does the same for launch tests: one throwaway launch, then five iterations by default ([WWDC19 423](https://developer.apple.com/videos/play/wwdc2019/423/)). Set `XCTMeasureOptions.iterationCount` to 10 for the perf target. Run each scripted scenario 5 to 10 times.
- **Medians and p95, never means.** One stray simulator hiccup moves a mean a lot and a median barely.
- **Deterministic inputs.** Generated fixtures with fixed note counts and sizes, and a fixed clock.
- **Same machine for decisions.** GitHub-hosted macOS runners are VMs with neighbors, so CI gates only on budgets and large regressions against a baseline from earlier CI runs. Fine-grained decisions run locally, base and candidate interleaved (A, B, A, B ...). [benchstat](https://pkg.go.dev/golang.org/x/perf/cmd/benchstat) is a good comparer: it reports medians with confidence intervals and a Mann-Whitney U-test, recommends at least 10 runs ("ideally 20"), and prints `~` when it finds no significant difference. It is a Go tool, so using it means installing Go for this one script; `perf-report` would write samples in the [Go benchmark format](https://go.googlesource.com/proposal/+/master/design/14313-benchmark-format.md) (`BenchmarkSearchQuery 1 18000000 ns/op`) for it to read. It has no fail-on-regression mode, so the gate script reads its output.

### 3.5 Baselines

- `perf/budgets.json`: committed, absolute, generous, per operation. Changing a budget is a reviewed diff.
- `perf/baselines/ci.json`: written by CI on `main` after a green run and uploaded as a workflow artifact; later runs download the latest one.
- `build/perf/baseline-local.json`: per machine, gitignored. Simulator timings depend on the Mac, so a laptop baseline can't be compared with a CI baseline.

**Simulator numbers are not iPhone numbers.** The Simulator runs on the Mac's CPU and memory. Use it to catch regressions. Check absolute numbers on the iPhone by hand: Instruments on a development-signed build (works with a free Apple ID, not tested here), and MetricKit once it delivers.

### 3.6 Ready for "autoresearch" loops

The future loop: an agent changes code, runs a benchmark, reads the result, keeps the change if it is faster, and repeats. What the repo needs so that works:

1. **One command, comparable output.** `make perf SCENARIO=<name> N=10` builds, runs the scenario N times on the fixed simulator, and writes `perf.json`. Nothing else should be needed.
2. **A/B in one command.** `make perf-ab BASE=<git-sha> N=10` builds both versions in separate worktrees, runs them interleaved, and prints a comparison plus a one-line verdict (`faster`, `slower`, `no significant change`). The agent keeps a change only on `faster` with no other operation `slower`.
3. **Deterministic scenarios as files.** `perf/scenarios/<name>.json` names the fixture (note count, sizes, drawers), the actions and the operations measured.
4. **Correctness travels with speed.** `make perf` runs the e2e invariants too, so a "faster" change that alters typed text is rejected.
5. **Unit-level benchmarks on the Mac.** The shape formatter and search ranking live in `NoteCore` and the database in `NoteStore` ([ADR 0005](../adr/0005-app-structure-and-enforced-boundaries.md)), so their benchmarks run with `swift test` on the Mac, with no simulator, in seconds.
6. **Profiles on demand, from the CLI.** `xcrun xctrace record --template 'Time Profiler' --device <sim-udid> --launch -- <app path> --output build/perf/<run>/launch.trace --time-limit 10s --no-prompt`, then `xctrace export --input ... --toc` and `--xpath` to pull tables an agent can read. `xctrace list devices` on this Mac lists the simulators as targets, and `list templates` includes Time Profiler, App Launch, SwiftUI, Swift Concurrency, Animation Hitches and Allocations. Whether `--launch` into a simulator app behaves well with Xcode 27.1 is **unverified**.
7. **A results log.** `perf/history.jsonl` (gitignored locally, CI artifact) appends each run's summary with the git SHA, so an agent can see the trend and what it already tried.

### 3.7 Field data from the phone

**MetricKit** delivers launch time, hang time, hitches, crashes and hangs from the real phone (4.3). Its numbers are the field equivalent of the e2e budgets.

**From a slow phone to a local reproduction.** Log lines carry *shape* fields, never content: `note.text.length`, `note.count`, `note.drawer.count`, device model and OS. When the phone is slow, the owner exports diagnostics (4.4), an agent reads those numbers, writes a `perf/scenarios/repro-<date>.json` with matching parameters, runs `make perf`, and profiles it. If the local scenario isn't slow, a shape field is missing: add it to the log line.

---

## 4. iOS in detail

### 4.1 `os.Logger`: subsystem, category, privacy

- **Subsystem and category.** Apple: the subsystem "identifies a large functional area" in reverse-DNS form; the category identifies "a particular component or module", with "any convention you want" ([guide](https://developer.apple.com/documentation/os/generating-log-messages-from-your-code)). Use subsystem `com.rontho14.note` (the bundle ID) and categories matching the modules in ADR 0005: `app`, `store`, `ui`, `perf`, `metrics`.
- **Privacy defaults.** The system "doesn't redact integer, floating-point and Boolean values, but it does redact the contents of dynamic strings and complex dynamic objects". `privacy: .public` shows a value; `.private` hides it; `.private(mask: .hash)` replaces it with a per-process hash so equal values can be correlated ([OSLogPrivacy](https://developer.apple.com/documentation/os/oslogprivacy), [Logger](https://developer.apple.com/documentation/os/logger), [WWDC20 "Explore logging in Swift"](https://developer.apple.com/videos/play/wwdc2020/10168/)).
- **Why `.private` isn't enough here.** Reports conflict on whether the Simulator redacts private values; several say it does not, or only when the app runs outside Xcode ([forum thread](https://developer.apple.com/forums/thread/705810)). **Unverified** on iOS 27.1. E2E captures Simulator logs into `build/e2e/`, so anything logged as `.private` may land there in clear text. The defense is not to log content at all, enforced by types (4.5), and checked by a canary grep: fixture notes contain a unique string that must never appear in `app.log` or `perf.json`.
- **Formatting cost.** `Logger` defers string conversion until a message is displayed, and the compiler can skip discarded debug messages ([WWDC20 10168](https://developer.apple.com/videos/play/wwdc2020/10168/)).

### 4.2 Signposts and Instruments

`OSSignposter` uses "the same subsystems and categories that you use for logging". `beginInterval`/`endInterval` pair through an interval state, `withIntervalSignpost` wraps a closure, and `emitEvent` marks a point ([OSSignposter](https://developer.apple.com/documentation/os/ossignposter)). In Instruments, add the `os_signpost` instrument, or use the `SwiftUI`, `Swift Concurrency`, `Animation Hitches` and `App Launch` templates. `XCTOSSignpostMetric(subsystem:category:name:)` measures a named interval in a performance test and records nothing if begin and end don't pair ([docs](https://developer.apple.com/documentation/xctest/xctossignpostmetric)).

### 4.3 MetricKit

- **What it gives.** Daily metric reports (launch time to first draw, resume time, hang time, hitch time, CPU, memory, disk writes, terminations, custom signpost metrics) and diagnostic reports (crash, hang, CPU and disk-write exceptions, app launch) delivered "immediately" since iOS 15 ([MetricKit](https://developer.apple.com/documentation/metrickit)).
- **Which API.** iOS 27 adds `MetricManager` with async sequences `metricReports` and `diagnosticReports`, Codable reports, and per-state breakdowns via the StateReporting framework ([Monitoring app performance with MetricKit](https://developer.apple.com/documentation/metrickit/monitoring-app-performance-with-metrickit)). The app's minimum is iOS 26, so use `MXMetricManager.shared.add(subscriber)` ([docs](https://developer.apple.com/documentation/metrickit/mxmetricmanager)), or put `MetricManager` behind `if #available(iOS 27, *)`.
- **Custom metrics.** `MXMetricManager.makeLogHandle(category:)` plus `mxSignpost` adds your own intervals to the daily report.
- **Testing.** Apple: "run your app on a physical device to receive metric reports". Debug > MetricKit > Simulate MetricKit Payloads sends sample data from Xcode. The Simulator doesn't deliver real payloads.
- **Free Apple ID.** Whether MetricKit delivers to a development-signed, sideloaded build, and whether it depends on the device's "Share with App Developers" setting, is **unverified**. Apple doesn't document it, and forum reports disagree ([thread](https://developer.apple.com/forums/thread/784399)). Try it on the phone; it costs a dozen lines.
- **Where payloads go.** Write each payload's JSON to the app's Application Support folder. It stays there until the owner exports diagnostics (4.4). Nothing is uploaded.

### 4.4 Reading logs

| Where | Command |
|---|---|
| Simulator, live | `xcrun simctl spawn <udid> log stream --style ndjson --level debug --predicate 'subsystem == "com.rontho14.note"'` |
| Simulator, after the fact | `xcrun simctl spawn <udid> log show --last 10m --style ndjson --predicate '...'` (add `--signpost` to include signposts) |
| iPhone over USB | `sudo log collect --device-udid <udid> --last 30m --output build/device.logarchive`, then `log show build/device.logarchive --style ndjson --predicate '...'`. Options checked with `log help collect`; whether `sudo` is required is **unverified**. Console.app also streams the phone. |
| Inside the app | `OSLogStore(scope: .currentProcessIdentifier)` reads the app's own entries ([OSLogStore](https://developer.apple.com/documentation/oslog/oslogstore)). A hidden "export diagnostics" action can write recent log lines and MetricKit payloads to a file through the share sheet, so the phone can be checked without a Mac. The owner chooses where the file goes; the app sends nothing. |

Changing which levels are stored for a subsystem on macOS uses `sudo log config --mode "level:debug" --subsystem ...` or a logging profile ([Customizing logging behavior](https://developer.apple.com/documentation/os/customizing-logging-behavior-while-debugging)).

### 4.5 The `Telemetry` module

The module is the only code that imports `os`:

```swift
import os

enum Event: String, Sendable {         // one case per kind of log line
    case appLaunched = "app.launched", noteSaved = "note.saved"
    case trashPurged = "trash.purged", exportFinished = "export.finished"
    case opEnd = "op.end"
}

enum Field: Sendable {                 // no case takes a free-form String
    case noteID(NoteID), opName(Op), durationMs(Int)
    case textLength(Int), noteCount(Int), drawerCount(Int)
    case errorType(ErrorType)
    var pair: String { ... }           // "note.id=6F1C...", "error.type=timeout"
}

enum Telemetry {
    private static let log = Logger(subsystem: "com.rontho14.note", category: "event")
    static func event(_ e: Event, _ fields: Field..., level: OSLogType = .default) {
        let rendered = fields.map(\.pair).joined(separator: " ")
        // Every Field is safe by construction, so the line is public.
        log.log(level: level, "\(e.rawValue, privacy: .public) \(rendered, privacy: .public)")
    }
}
```

`NoteID` is a wrapper type around `UUID`. `ErrorType` is an enum of error classes, not `error.localizedDescription`, which can quote user input.

**Where it lives is open.** Both `NoteStore` and `NoteUI` need to log and measure, and ADR 0005's `NoteCore` imports only Foundation. The likely answer is a small fourth package that both depend on. Decide when the first measurement is added.

**Rules to add when `Telemetry` exists.** Following ADR 0005, each is a text check, added in the same change as the module:

- no `print`, `debugPrint`, `dump` or `NSLog` anywhere;
- `import os` and `import OSLog` only inside the `Telemetry` module;
- `Logger(`, `OSSignposter(` and `OSLog(` only inside the `Telemetry` module;
- no `localizedDescription` inside the `Telemetry` module.

Lint can't prove that a key flow has a signpost. Tests can: the perf UI tests use `XCTOSSignpostMetric` for each budgeted operation, and `perf-report` fails when an expected operation has no samples (3.3).

### 4.6 Crash reports

- The Xcode Organizer's crash and launch-time panes take data from TestFlight and the App Store, which need the paid program ([Acquiring crash reports](https://developer.apple.com/documentation/xcode/acquiring-crash-reports-and-diagnostic-logs), [Reducing launch time](https://developer.apple.com/documentation/xcode/reducing-your-app-s-launch-time)).
- Free options that send nothing: MetricKit `CrashDiagnostic` and `HangDiagnostic` (4.3); Settings > Privacy & Security > Analytics & Improvements > Analytics Data on the phone; Xcode's Devices window over USB.
- Hosted crash reporters such as Sentry upload reports, so they are ruled out by ADR 0001.

---

## 5. Fields

### 5.1 The allowed list

| Key | Type | Notes |
|---|---|---|
| `note.id` | UUID | |
| `note.drawer.id` | UUID | The ID, never the drawer's name: names are user content. |
| `note.op.name` | enum (section 3.1 operations) | |
| `note.op.duration_ms` | int | |
| `note.text.length`, `note.count`, `note.drawer.count` | int | Shape for reproductions. |
| `note.size_class` | enum `xs`, `s`, `m`, `l`, `xl` | Bucketed length. |
| `note.search.result_count` | int | Never the query. |
| `error.type` | enum | Never the error's text. |
| `note.e2e.run_id` | string | E2E runs only. |

Adding a key means adding a row here and a case to `Field`, so it gets reviewed.

### 5.2 Never, anywhere

Note text, titles, search queries, drawer names, formatting corrections, exported file names or folder paths, raw SQL parameters, and free-form error messages (they can quote the input; use `error.type`).

### 5.3 Enforcement

| Layer | Mechanism |
|---|---|
| Types | `Field` enum with no free-string case; ID wrapper types. |
| Checks | The rules in 4.5. |
| Tests | A unit test that every `Field` key is in the list above. |
| E2E | Canary grep: no fixture canary string in `app.log`, `perf.json` or the exported diagnostics file. |

---

## 6. App Store privacy label

Apple defines "collect" as transmitting data off the device so that you can access it "for a period longer than what is necessary to service the transmitted request in real time" ([App privacy details](https://developer.apple.com/app-store/app-privacy-details/)). The app transmits nothing, and the diagnostics export is a file the owner chooses to share. On that definition the app can declare that it collects no data. That only matters once the app ships through the paid program, and it holds only while ADR 0001 does.

---

## 7. Making it a habit for every feature

### 7.1 Feature checklist

A feature isn't done until:

1. **Boundary event.** It emits one `info` event per unit of work (an `Event` case added), and errors are logged once where they are handled.
2. **Measurement.** Each user-visible operation has a `Telemetry.measure` interval.
3. **Budget.** If the user waits on it, it has an entry in `perf/budgets.json` and a scenario in `perf/scenarios/`.
4. **Fields.** Only listed keys, with shape fields (lengths, counts) where they would help reproduce slowness.
5. **Proof.** The e2e scenario's expectation file lists its required events and operations, and `make e2e` passes the log budget, the perf budget and the canary check.

### 7.2 Ways to enforce or verify it

| Layer | Mechanism |
|---|---|
| Types | `Event`, `Field` and `Op` enums. |
| Checks | The text checks in 4.5. |
| Unit tests | `Telemetry` sends to an injectable sink; tests assert the event and fields for a store operation. |
| E2E | `e2e/expect/<scenario>.json` lists required events and operations. `make e2e` fails on a missing one, an unexpected warning or error, a log budget breach, a perf budget breach or regression, or a canary hit. |
| CI | The same `make e2e` on GitHub Actions. |
| CLAUDE.md (weakest) | "Every feature: one boundary event, a `Telemetry.measure` per user-visible operation, a budget if the user waits on it, listed fields only. Run `make e2e` and read `perf.json`." |

---

## Proposed setup for this repo

These steps slot into the list in [agent-guardrails-and-testing.md](agent-guardrails-and-testing.md#proposed-setup-for-this-repo); its step numbers are in brackets. Smallest first, and each measurement arrives with its feature.

1. **Add the `Telemetry` module** with `Event`, `Field`, `Op`, `Telemetry.event(...)` and `Telemetry.measure(...)`, alongside the packages [2]. Emit `app.launched` and measure `app.launch` from `App.init` to the text field becoming first responder. Add the 4.5 checks in the same change.
2. **Add `perf/budgets.json`** with `app.launch`, and `perf/scenarios/launch.json`.
3. **Add a `NotePerfTests` UI test target** [4] with `XCTApplicationLaunchMetric(waitUntilResponsive: true)` and `XCTOSSignpostMetric` for `app.launch`, 10 iterations.
4. **Add `scripts/perf-report`** (bash and `jq`): reads `xcresulttool get test-results metrics` and the `app.log` `op.end` lines, writes `perf.json`, compares to budgets and `build/perf/baseline-local.json`, and exits non-zero on failure. Expose `make perf` and `make perf-baseline`.
5. **Capture app logs in `scripts/sim`** [5]: `log stream --style ndjson` into `build/e2e/<run-id>/app.log`, started before launch. Add `scripts/log-budget` and the canary grep.
6. **Add `make profile-ios SCENARIO=launch`** wrapping `xctrace record --template 'Time Profiler'` against the E2E simulator.
7. **CI** [7]: run `make perf` on the macOS runner. Report only for the first two weeks to learn the noise, then gate on budgets and the regression rule against the `main` baseline artifact.
8. **CLAUDE.md** [3]: the lines from 2.3 and 7.2.
9. **With each feature**: `note.keystroke` and `note.save` with writing, `note.view` with view mode, `search.query` with search, `notes.scroll` with the 10,000-note fixture, `export.run` with export.
10. **Add the MetricKit subscriber** that writes payload JSON to Application Support, and the diagnostics export. Try it on the phone and record whether payloads arrive on a free-account build.
11. **Later, if fine-grained comparisons are needed**: `make perf-ab BASE=<sha>` with benchstat, which needs Go installed.
