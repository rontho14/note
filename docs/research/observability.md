# Observability: logging, tagging and performance

> **Note, 2026-11-10.** This research predates the change to a local-only app with no backend and no AI ([VISION](../VISION.md)). The Swift, Simulator and `make check` parts still apply. The Go, server, KMS, MCP and AI-provider parts do not apply to the first iteration.

Research date: 2026-10-27. Versions were checked against GitHub releases, `pkg.go.dev`, Apple's documentation JSON and the local Xcode 27.1 / Go 1.27.1 toolchain on that date. Anything marked **unverified** could not be confirmed from a primary source.

This builds on [agent-guardrails-and-testing.md](agent-guardrails-and-testing.md) (the guardrail layers and the whole-system e2e test mode) and does not repeat it.

**How I read "tagging".** The owner's "tagging" here means the attributes (also called labels, tags or dimensions) attached to logs, traces, metrics and analytics events. It does not mean the app's hidden note tags. To avoid confusion, this file says "attributes" throughout.

**Performance is the point.** The owner's main reason for observability is speed: knowing how fast the app and server are, catching regressions before they ship, letting an agent run experiments to make things faster, and later finding slowness that real users hit. Logging and attributes serve that goal. Section 3 is the core of the file.

## Summary

- **Few logs, many measurements.** Log one line per unit of work at a boundary (a request, a job, a sync, a launch) plus errors. Measure durations with spans and signposts, not with "started"/"finished" log pairs. Debug logs are off outside development. An e2e run fails if a scenario logs more lines than its budget or emits an unexpected warning or error.
- **Every e2e run produces `build/e2e/<run-id>/perf.json`.** It lists per-operation timings (launch to keyboard-up, keystroke to save, finish to rewritten, sync, AI latency and tokens, MCP tool latency), each with sample count, median and p95, compared against committed budgets and a stored baseline. The run fails on a budget breach or on a regression larger than both a relative and an absolute threshold.
- **Noise is handled by design, not hope.** Use a dedicated simulator model and runtime, one discarded warm-up, 5 to 10 repetitions, medians and p95, a fake AI provider with a fixed delay, and an absolute floor so tiny jitter can't fail a build. For keep/discard decisions (the future "autoresearch" loop), compare base and candidate interleaved on the same machine with [benchstat](https://pkg.go.dev/golang.org/x/perf/cmd/benchstat). Stored numbers are only for coarse CI gates.
- **iOS: route all logging through one small typed `Telemetry` module.** It wraps `os.Logger` and `OSSignposter`. Event names, attribute keys and operations are Swift enums, and there is no case that accepts a free-form string. Note text can't be logged because the API has nowhere to put it. SwiftLint bans `print`, `NSLog`, `import os` and `Logger(` outside that module.
- **Go: `log/slog` with the JSON handler plus OpenTelemetry for traces and metrics.** sloglint enforces context-carrying calls, `slog.Attr` only, constant keys from an allowlist, static messages and no global logger. spancheck enforces `span.End()` and error recording. forbidigo restricts `slog.String`/`attribute.String` to a single `attr` package. A `crypt.Plaintext` type redacts itself in `slog`, `fmt` and errors, and ruleguard rules ban passing its revealed bytes to any logging or tracing call.
- **One attribute vocabulary for app and server.** Use OpenTelemetry semantic conventions where a name exists (`http.*`, `db.*`, `error.type`, `gen_ai.*`, `mcp.*`, `service.*`). Add a short list of custom keys under the app's own `note.` prefix (`note.id`, `note.revision.id`, `note.job.kind`, `note.agent.id` and a few more). IDs may go on spans and logs. Only small enums may go on metrics. Note text, titles, drawer and tag names, tokens, keys and emails never go anywhere.
- **One trace ID crosses the whole system.** The app creates a W3C `traceparent` per user operation and sends it on sync requests. The server continues it through the job queue (stored with the job and used as a link), the OpenAI call (plus OpenAI's `X-Client-Request-Id`), and MCP calls (from `params._meta`, as the MCP semantic conventions specify). In e2e, `scripts/trace <id>` greps `app.log`, `server.log` and `spans.jsonl`, and the local viewer answers `otel-desktop-viewer trace <id> --json`.
- **Locally, telemetry goes to files and [otel-desktop-viewer](https://github.com/CtrlSpice/otel-desktop-viewer).** It installs with Homebrew, needs no Docker, receives OTLP on 4317/4318, and has CLI commands that return a trace as JSON, which suits agents. No OpenTelemetry Collector is needed until production needs scrubbing, tail sampling or two destinations.
- **In production, start with Grafana Cloud's free tier.** It gives 10k active metric series and 50 GB each of logs, traces and profiles per month with 14-day retention, and Grafana's MCP server lets an agent search traces with TraceQL and query metrics and logs. Honeycomb's free tier (20M events/month) is the alternative. Define SLOs on the same histograms the e2e budgets use.
- **Product analytics: define events now, send nothing off the device yet.** Analytics events are entries in the same typed registry and are logged locally. Once the Go backend exists, send them to your own server as OpenTelemetry events. Pick a vendor only if a second user arrives; if so, TelemetryDeck fits a privacy-first Swift app best.
- **Telemetry keys never enter the repo or the app binary.** The repo is public and an iOS binary can be unpacked. The app sends telemetry to your own server, and only the server holds the backend's OTLP token. GitHub secret scanning runs free on public repos.

---

## 1. Primer for someone new to this

### 1.1 The signals

| Signal | What it is | Good for | In this repo |
|---|---|---|---|
| **Log** | A timestamped record with a message and attributes. | "What happened, and why did it fail?" | iOS `os.Logger`; Go `log/slog` JSON lines. Few, at boundaries. |
| **Metric** | A number aggregated over time: counters, gauges, histograms. Cheap to store, cheap to alert on. | "How often, how fast, at what percentile?" over days or months. | OTel histograms on the server. MetricKit daily reports on device. |
| **Trace / span** | A span is one timed operation with a name, start, end, status and attributes. A trace is the tree of spans for one request across processes, joined by a trace ID. | "Where did the time go in *this* request?" | OTel Go spans on the server. On iOS, a trace ID per user operation sent in `traceparent`, and signpost intervals locally. |
| **Analytics event** | A product action ("note finished", "drawer closed") with a few properties, counted per user or session. | "Do people use this feature?" | Typed events, logged locally now, sent to your own backend later. |
| **Profile** | Samples of where CPU time or memory goes, by function. | "Which function is hot?" once you know an operation is slow. | Instruments / `xctrace` on iOS; `pprof` in Go. |
| **Signpost** | Apple's name for a lightweight interval or point event recorded through unified logging, shown on the Instruments timeline. | Timing app operations during development and in XCTest performance tests. | `OSSignposter` intervals for every budgeted iOS operation. |

Logs, metrics and traces answer different questions, and good systems tie them together: a slow point on a latency histogram leads to an example trace, the trace leads to the log line of the span that failed, and a profile explains the hot function.

### 1.2 Attributes ("tags")

An attribute is a key/value pair attached to a signal, for example `http.route="/v1/sync"` or `note.job.kind="format"`. Two kinds matter:

- **Resource attributes** describe the process emitting telemetry: `service.name`, `service.version`, `deployment.environment.name`. They are set once at startup.
- **Signal attributes** describe one event or span: the route, the note ID, the error type.

OpenTelemetry publishes **semantic conventions**: agreed names for common attributes so tools understand them. Names are lowercase, dot-namespaced and snake_case within a component (`http.response.status_code`), per the [naming rules](https://github.com/open-telemetry/semantic-conventions/blob/main/docs/general/naming.md).

### 1.3 Cardinality

Cardinality is the number of distinct values an attribute takes, and for a metric, the number of distinct attribute combinations. Each combination is a separate time series that costs memory and money. `http.route` has maybe 15 values. A note ID has one per note, which is unbounded. The OTel metrics SDK spec sets a default **cardinality limit of 2000** points per metric per collection cycle and folds the rest into one series marked `otel.metric.overflow=true` ([spec](https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/metrics/sdk.md#cardinality-limits)). The rule that follows: IDs go on spans and logs, never on metrics.

### 1.4 Sampling

Sampling means keeping only some traces to save cost. The OTel trace SDK defines samplers such as `AlwaysOn`, `TraceIdRatioBased` and `ParentBased` ([spec](https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/trace/sdk.md)). At one user, keep 100% (`ParentBased(AlwaysOn)`). Revisit only if volume approaches a free-tier limit. Metrics are never sampled; they are aggregated.

### 1.5 Correlation IDs and trace context

A correlation ID lets you find every record about one request. The standard one is the W3C [Trace Context](https://www.w3.org/TR/trace-context/) `traceparent` header: `00-<32 hex trace-id>-<16 hex parent-id>-<2 hex flags>`. Every service that receives it continues the same trace. OpenTelemetry's [compatibility spec](https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/compatibility/logging_trace_context.md) says non-OTLP JSON logs should carry it as top-level `trace_id`, `span_id` and `trace_flags` fields, lowercase hex. That makes every log line greppable by trace ID.

### 1.6 What "good" looks like here

- Given a trace ID, an agent can see in one command every app log line, server log line and span for that operation, with durations.
- Every user-visible operation has a measured duration with a budget, and every e2e run reports it.
- A normal e2e scenario produces a handful of log lines, none above `info`, and zero lines containing a note's text.
- When a number gets worse, the PR that made it worse fails.

---

## 2. Logging policy: few lines, high signal

### 2.1 What earns a log line

| Log it | Don't log it |
|---|---|
| One **wide event** per unit of work at the boundary: an HTTP request finished, a job finished, a sync finished, the app launched, a note was finished. Put every useful attribute on that one line (IDs, sizes, counts, outcome, duration). | "Entering function", "starting X", "done X". Use a span or signpost interval. |
| Errors the system did not recover from (`error`). | Every retry attempt. Count retries as an attribute on the final line. |
| Recovered problems a human should know about (`warn`): a retry that succeeded after backoff, a degraded mode switch, a KMS slowdown. | Expected business outcomes such as "rewrite rejected by the content check". That is an `info` event with an outcome attribute, not a warning. |
| Rare state changes: migration applied, key rotated, grant revoked, config summary at startup. | Anything per keystroke, per row, per loop iteration, or per cache hit. |
| | Values that a metric already counts. |

The "one wide line per unit of work" idea is Stripe's [canonical log lines](https://stripe.com/blog/canonical-log-lines). Apple's own [logging guide](https://developer.apple.com/documentation/os/generating-log-messages-from-your-code) suggests messages at the start and end of functions and before each step of a multi-step task. I disagree for persisted logs in this app: those are exactly the intervals a signpost or span records better, with a duration and almost no cost.

**Log or return, not both.** A function that returns an error doesn't also log it. The boundary that handles the error logs it once, so one failure produces one line.

### 2.2 Levels and defaults

| Level | Go (`slog`) | iOS (`Logger`) | Persisted on iOS? | Default on |
|---|---|---|---|---|
| debug | `Debug` | `.debug` | No, memory only | Developer machines only, switched on per run |
| info (boundary events) | `Info` | `.notice` (`.default`) | Yes, up to a storage limit | Everywhere, including e2e |
| warn | `Warn` | `.error` with an outcome attribute | Yes | Everywhere |
| error | `Error` | `.error` | Yes | Everywhere |
| fault (a bug, an invariant broken) | `Error` with `error.type=invariant` | `.fault` | Yes | Everywhere |

The iOS persistence column is from Apple's [log level table](https://developer.apple.com/documentation/os/generating-log-messages-from-your-code): debug is never persisted, info only "when collected with the log tool", and notice, error and fault are written to disk "up to a storage limit". iOS `.info` is skipped here because it is neither cheap chatter nor reliably kept.

Server default is `info`. A `slog.LevelVar` lets an operator raise detail at runtime without a restart ([HandlerOptions](https://pkg.go.dev/log/slog#HandlerOptions)). E2E runs at `info` so its log volume matches production.

### 2.3 Enforcing "no useless logs"

1. **A typed event registry (both languages).** Every log message is a constant from one `events` list (`note.finished`, `sync.completed`, `http.request`, ...). Adding a log line means adding a registry entry, which is a visible one-line diff a reviewer or agent can question. In Go, sloglint's `static-msg` rejects messages built with `fmt.Sprintf`, and a ruleguard rule can require the message to come from the `events` package (sketch in 5.5). In Swift, the `Telemetry.event(_:)` API takes an `Event` enum, so there is nothing else to pass.
2. **A log budget in every e2e run.** `scripts/log-budget` reads `app.log` and `server.log` for the run and fails if:
   - any `warn`/`error`/`fault` line appears that the scenario didn't declare as expected;
   - a scenario exceeds its line budget (start with: per HTTP request, 1 server line; per job, 1; per app operation, 1; plus 3 startup lines per process);
   - the same event name repeats more than 3 times within one trace (chatter detection).
   The result goes into `perf.json` under `log_budget`, so the agent sees it with the timings.
3. **Lint for log calls inside loops (Go).** A ruleguard rule flags `slog` calls in a `for` body (sketch in 5.5, **unverified** that the pattern compiles as written).
4. **CLAUDE.md, the weakest layer:** "One log line per unit of work at a boundary, plus errors. Durations go in spans/signposts, not logs."

---

## 3. Performance: measure, budget, compare, investigate

### 3.1 What to measure from day one

Budgets below are starting points for the owner to tune. "Sim" numbers are for the iOS Simulator on a Mac and are only meaningful relative to each other (see 3.5).

| Operation (`note.op.name`) | Starts | Ends | Recorded by | Initial budget |
|---|---|---|---|---|
| `app.launch` | Process start (system) / `App.init` (in-app) | Text field is first responder with the keyboard up | `XCTApplicationLaunchMetric(waitUntilResponsive: true)` in a UI test, plus a signpost interval `app.launch` from `App.init` to keyboard-up | Device: first frame under 400 ms, the goal Apple states in [WWDC19 "Optimizing App Launch"](https://developer.apple.com/videos/play/wwdc2019/423/). Sim: p95 under 600 ms to keyboard-up. |
| `note.keystroke` (main-thread work per keystroke) | Text change callback | Callback returns | Signpost interval; `XCTOSSignpostMetric` | p95 under 5 ms. Apple suggests "a limit of 5 ms" for work during continuous interaction ([Improving app responsiveness](https://developer.apple.com/documentation/xcode/improving-app-responsiveness)). |
| `note.save` (keystroke to durable) | Last text change | GRDB transaction committed | Signpost interval + `op.end` log line | p95 under 250 ms including any debounce; the write itself under 20 ms. |
| `note.finish` (finish to rewritten) | Swipe into view mode (app) | Rewritten revision stored (server) | App span start + server spans in the same trace | Fake AI with fixed 200 ms delay: p95 under 1 s end to end. Real AI: p95 under 20 s. |
| `sync.run` | App sync starts | App applied the response | Signpost + `traceparent` to server; server `http.server.request.duration` | Localhost, small delta: p95 under 300 ms. |
| `ai.inference` | Request sent to provider | Full response received | Server span + `gen_ai.*` histogram + token counts | Fake: fixed. Real: track p50/p95 and tokens per job kind; no hard budget until there is data. |
| `mcp.tool` | MCP request received | Response written | Server span + `mcp.server.operation.duration` | Excluding AI: p95 under 150 ms for `read`/`create`/`edit`. |
| Hitches during typing and the mode swipe | | | `XCTHitchMetric(application:)` (present in Xcode 27.1's `XCTMetric+UIAutomation.h`, iOS 26+) | Zero hitches in the scripted swipe. |

Server operations get histograms whose names come from semantic conventions where one exists: `http.server.request.duration` (stable, buckets `[0.005 ... 10]` s, [HTTP metrics](https://github.com/open-telemetry/semantic-conventions/blob/main/docs/http/http-metrics.md)), `mcp.server.operation.duration` ([MCP conventions](https://github.com/open-telemetry/semantic-conventions-genai/blob/main/docs/gen-ai/mcp.md)), and the GenAI client duration and token metrics. Custom ones use the app prefix: `note.finish.duration`, `note.sync.duration`, `note.job.queue_wait.duration`.

The GenAI conventions moved in 2026 from the main repo to [open-telemetry/semantic-conventions-genai](https://github.com/open-telemetry/semantic-conventions-genai), are all in "Development" status, and currently list both `gen_ai.client.operation.duration` ([gen-ai-metrics.md](https://github.com/open-telemetry/semantic-conventions-genai/blob/main/docs/gen-ai/gen-ai-metrics.md)) and the newer `gen_ai.client.inference.duration` and `gen_ai.client.inference.usage.input_tokens`/`output_tokens` ([client-inference.md](https://github.com/open-telemetry/semantic-conventions-genai/blob/main/docs/gen-ai/client-inference.md)). Pin one version and expect renames.

### 3.2 How each side records an operation

**iOS.** One call wraps the work:

```swift
try await Telemetry.measure(.noteSave, .noteID(note.id), .textLength(note.text.utf8.count)) {
    try await store.save(note)
}
```

It does three things: begins and ends an `OSSignposter` interval named after the op (so Instruments and `XCTOSSignpostMetric` see it), and on completion writes one `op.end` line through `Logger` with `note.op.name`, `note.op.duration_ms`, the fields and the current `trace_id`. The log line is what `perf.json` and agents read; the signpost is what Instruments and XCTest read. `OSSignposter` interval names must be `StaticString`, so `Op` maps each case to a literal in a `switch` ([OSSignposter](https://developer.apple.com/documentation/os/ossignposter), [Recording performance data](https://developer.apple.com/documentation/os/recording-performance-data)). Signposts are cheap enough to leave on: WWDC18 [Measuring Performance Using Logging](https://developer.apple.com/videos/play/wwdc2018/405/) calls them "lightweight", and a disabled log handle makes them near no-ops.

**Go.** A span per operation plus a histogram for budgeted operations. Spans give per-request detail; the histogram gives percentiles and SLOs cheaply. The `slog` boundary line carries the same `trace_id`.

### 3.3 Every e2e run writes `perf.json`

`make e2e` (from the guardrails proposal) gains a final step, `scripts/perf-report`, using `jq` (it ships in macOS at `/usr/bin/jq`, so nothing to install). Inputs, all under `build/e2e/<run-id>/`:

| File | Producer | Gives |
|---|---|---|
| `app.log` | `xcrun simctl spawn <udid> log stream --style ndjson --level debug --predicate 'subsystem == "com.rontho14.note"'` started before the app launches | App `op.end` lines with durations and trace IDs |
| `server.log` | Go server, `slog` JSON | Boundary events, errors, trace IDs |
| `spans.jsonl` | Go server in e2e mode (5.3) | Server span durations, `gen_ai.usage.*` token counts, MCP timings |
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
  "ai_mode": "fake-fixed-200ms",
  "ops": [
    { "op": "app.launch", "unit": "ms", "warmup": 1, "n": 10,
      "median": 412, "p95": 455, "budget_p95": 600,
      "baseline_median": 405, "delta_pct": 1.7, "status": "ok" },
    { "op": "ai.inference", "unit": "ms", "n": 12, "median": 203, "p95": 210,
      "tokens_in_median": 410, "tokens_out_median": 395, "status": "ok" }
  ],
  "log_budget": { "status": "ok", "unexpected": [], "over_budget": [] },
  "verdict": "pass"
}
```

`scripts/perf-report` also emits the same samples in the [Go benchmark format](https://go.googlesource.com/proposal/+/master/design/14313-benchmark-format.md) (`BenchmarkAppLaunch 1 412000000 ns/op`), so `benchstat` can compare iOS operations exactly as it compares Go benchmarks. One statistics tool for both.

**Fail rules.**

- **Budget:** p95 above `budget_p95` in `perf/budgets.json` (committed) fails, always.
- **Regression:** median worse than the baseline median by more than 15% **and** by more than an absolute floor (20 ms for UI ops, 5 ms for server ops) fails. Both conditions are needed so a 2 ms op that becomes 3 ms doesn't fail a build.
- **Missing data:** an op with `n` below its expected count fails, because a missing measurement usually means a missing span or a broken flow.

### 3.4 Keeping the numbers stable

- **Fixed environment.** The `Note-E2E` simulator is always the same model and runtime, recorded in `perf.json`. Status bar and animations are fixed by the E2E configuration.
- **Warm-up and repetitions.** Discard the first iteration. XCTest does the same for launch tests: one throwaway launch, then five iterations by default ([WWDC19 423](https://developer.apple.com/videos/play/wwdc2019/423/)). Set `XCTMeasureOptions.iterationCount` to 10 for the perf target. Run each scripted scenario 5 to 10 times.
- **Medians and p95, never means.** One stray GC pause or simulator hiccup moves a mean a lot and a median barely.
- **Deterministic inputs.** Seeded fixtures with fixed note sizes, the fake AI with a fixed delay (`ai/mode=ok&delay=200ms`), no network beyond localhost. The real provider is a separate, manual `ai_mode=real` run whose numbers are never compared with fake runs.
- **Same machine for decisions.** GitHub-hosted macOS runners are VMs with neighbors, so CI gates only on budgets and large regressions against a baseline from earlier CI runs. Fine-grained decisions run locally, base and candidate interleaved (A, B, A, B ...), then `benchstat`. benchstat reports medians with confidence intervals and a Mann-Whitney U-test, recommends at least 10 runs ("ideally 20"), and prints `~` when it finds no significant difference ([benchstat docs](https://pkg.go.dev/golang.org/x/perf/cmd/benchstat)). It has no fail-on-regression mode, so the gate script reads its output.

### 3.5 Baselines

- `perf/budgets.json`: committed, absolute, generous, per op. Changing a budget is a reviewed diff.
- `perf/baselines/ci.json`: written by CI on `main` after a green run and uploaded as a workflow artifact; PR runs download the latest one. Optionally committed by a `make perf-baseline` PR when the owner accepts a new normal.
- `build/perf/baseline-local.json`: per machine, gitignored. Simulator timings depend on the Mac, so a laptop baseline can't be compared with a CI baseline.

**Simulator numbers are not iPhone numbers.** The Simulator runs on the Mac's CPU and memory. Use it to catch regressions. Check absolute numbers on the iPhone by hand: Instruments on a development-signed build (works with a free Apple ID, not tested here), and MetricKit once it delivers.

### 3.6 Ready for "autoresearch" loops

The future loop: an agent changes code, runs a benchmark, reads the result, keeps the change if it is faster, and repeats. What the repo needs now so that works later:

1. **One command, comparable output.** `make perf SCENARIO=<name> N=10` builds, runs the scenario N times on the fixed simulator and local server, and writes `perf.json`. Nothing else should be needed.
2. **A/B in one command.** `make perf-ab BASE=<git-sha> N=10` builds both versions in separate worktrees, runs them interleaved, and prints the benchstat table plus a one-line verdict (`faster`, `slower`, `no significant change`). The agent keeps a change only on `faster` with no other op `slower`.
3. **Deterministic scenarios as files.** `perf/scenarios/<name>.json` names the fixture (note count, sizes, revision depth), the actions and the ops measured. Seed data is generated from parameters, not hand-written, so a scenario can be scaled ("1,000 notes of 20 KB").
4. **Correctness travels with speed.** `make perf` runs the e2e invariants and the canary check too, so a "faster" change that drops content or leaks plaintext is rejected.
5. **Profiles on demand, from the CLI.**
   - iOS: `xcrun xctrace record --template 'Time Profiler' --device <sim-udid> --launch -- <app path> --output build/perf/<run>/launch.trace --time-limit 10s --no-prompt`, then `xctrace export --input ... --toc` and `--xpath` to pull tables an agent can read. `xctrace list devices` on this Mac lists the simulators as targets, and `list templates` includes Time Profiler, App Launch, SwiftUI, Swift Concurrency, Animation Hitches and Allocations. Whether `--launch` into a simulator app behaves well with Xcode 27.1 is **unverified**.
   - Go: `go test -bench=. -count=10 -cpuprofile cpu.out -memprofile mem.out` for microbenchmarks, `/debug/pprof/profile?seconds=10` on the e2e server during a scenario, and `go tool pprof -top cpu.out` for text output. `runtime/trace.FlightRecorder` (in Go 1.27, checked with `go doc`) keeps the last few seconds of execution trace in memory, so a slow request can be snapshotted after the fact.
6. **A results log.** `perf/history.jsonl` (gitignored locally, CI artifact) appends each run's summary with the git SHA, so an agent can see the trend and what it already tried.

### 3.7 Production, later

**SLOs on the same histograms.** Examples to start with: 99% of `note.finish` complete within 20 s over 28 days; 99.5% of sync requests complete within 1 s; 99.9% of MCP tool calls succeed. Alert on error-budget burn rate, not on single slow requests. Grafana Cloud's free tier includes alerting; Honeycomb's free tier includes 2 triggers ([pricing](https://www.honeycomb.io/pricing)).

**Device-side truth.** MetricKit delivers launch time, hang time, hitches, crashes and hangs from the real phone (4.3). Its numbers are the field equivalent of the e2e budgets.

**Letting an agent investigate.**

| Backend | Agent access | Notes |
|---|---|---|
| Grafana Cloud (Tempo, Loki, Prometheus) | [mcp-grafana](https://github.com/grafana/mcp-grafana) v2.1.1: `search_tempo_traces` (TraceQL), `get_tempo_trace`, `diff_tempo_traces`, PromQL and LogQL queries, alert rules | `diff_tempo_traces` compares a slow trace with a normal one, which is most of an investigation. |
| Honeycomb | Hosted MCP server with OAuth or API key; tools include running queries and fetching traces ([docs](https://docs.honeycomb.io/integrations/mcp/)). The older self-hosted `honeycomb-mcp` repo is archived. | Whether the hosted MCP works on the free plan is **unverified**. |
| SigNoz | [signoz-mcp-server](https://github.com/SigNoz/signoz-mcp-server) v0.16.0 (hosted for SigNoz Cloud, or self-run): metrics, traces, logs, services | |
| Sentry | [sentry-mcp](https://github.com/getsentry/sentry-mcp) | For iOS crashes if Sentry is adopted. |

**From a production trace to a local reproduction.** Spans carry *shape* attributes, never content: `note.text.length`, `note.revision.count`, `note.count` for the user, `gen_ai.usage.input_tokens`, `note.job.kind`, `service.version`, device model and OS. An agent fetches the slow trace through MCP, reads those numbers, writes a `perf/scenarios/repro-<trace-id>.json` with matching parameters, runs `make perf SCENARIO=repro-<trace-id>`, and profiles it. If the local scenario isn't slow, the missing shape attribute is the lesson: add it to the span.

---

## 4. iOS in detail

### 4.1 `os.Logger`: subsystem, category, privacy

- **Subsystem and category.** Apple: the subsystem "identifies a large functional area" in reverse-DNS form; the category identifies "a particular component or module", with "any convention you want" ([guide](https://developer.apple.com/documentation/os/generating-log-messages-from-your-code)). Use subsystem `com.rontho14.note` (the bundle ID) and categories matching the planned packages: `app`, `store`, `sync`, `ui`, `perf`, `metrics`.
- **Privacy defaults.** The system "doesn't redact integer, floating-point and Boolean values, but it does redact the contents of dynamic strings and complex dynamic objects". `privacy: .public` shows a value; `.private` hides it; `.private(mask: .hash)` replaces it with a per-process hash so equal values can be correlated ([OSLogPrivacy](https://developer.apple.com/documentation/os/oslogprivacy), [Logger](https://developer.apple.com/documentation/os/logger), [WWDC20 "Explore logging in Swift"](https://developer.apple.com/videos/play/wwdc2020/10168/)).
- **Why `.private` isn't enough here.** Reports conflict on whether the Simulator redacts private values; several say it does not, or only when the app runs outside Xcode ([forum thread](https://developer.apple.com/forums/thread/705810)). **Unverified** on iOS 27.1. E2E captures Simulator logs into `build/e2e/`, so anything logged as `.private` may land there in clear text. The defense is not to log content at all, enforced by types (4.6), and checked by the canary grep.
- **Formatting cost.** `Logger` defers string conversion until a message is displayed, and the compiler can skip discarded debug messages ([WWDC20 10168](https://developer.apple.com/videos/play/wwdc2020/10168/)).

### 4.2 Signposts and Instruments

`OSSignposter` uses "the same subsystems and categories that you use for logging". `beginInterval`/`endInterval` pair through an interval state, `withIntervalSignpost` wraps a closure, and `emitEvent` marks a point ([OSSignposter](https://developer.apple.com/documentation/os/ossignposter)). In Instruments, add the `os_signpost` instrument, or use the `SwiftUI`, `Swift Concurrency`, `Animation Hitches` and `App Launch` templates. `XCTOSSignpostMetric(subsystem:category:name:)` measures a named interval in a performance test and records nothing if begin and end don't pair ([docs](https://developer.apple.com/documentation/xctest/xctossignpostmetric)).

### 4.3 MetricKit

- **What it gives.** Daily metric reports (launch time to first draw, resume time, hang time, hitch time, CPU, memory, disk writes, terminations, custom signpost metrics) and diagnostic reports (crash, hang, CPU and disk-write exceptions, app launch) delivered "immediately" since iOS 15 ([MetricKit](https://developer.apple.com/documentation/metrickit)).
- **Which API.** iOS 27 adds `MetricManager` with async sequences `metricReports` and `diagnosticReports`, Codable reports, and per-state breakdowns via the StateReporting framework ([Monitoring app performance with MetricKit](https://developer.apple.com/documentation/metrickit/monitoring-app-performance-with-metrickit)). The app's minimum is iOS 26, so use `MXMetricManager.shared.add(subscriber)` ([docs](https://developer.apple.com/documentation/metrickit/mxmetricmanager)), or put `MetricManager` behind `if #available(iOS 27, *)`.
- **Custom metrics.** `MXMetricManager.makeLogHandle(category:)` plus `mxSignpost` adds your own intervals to the daily report.
- **Testing.** Apple: "run your app on a physical device to receive metric reports". Debug > MetricKit > Simulate MetricKit Payloads sends sample data from Xcode. The Simulator doesn't deliver real payloads.
- **Free Apple ID.** Whether MetricKit delivers to a development-signed, sideloaded build, and whether it depends on the device's "Share with App Developers" setting, is **unverified**. Apple doesn't document it, and forum reports disagree ([thread](https://developer.apple.com/forums/thread/784399)). Try it on the phone; it costs a dozen lines.
- **Where payloads go.** Write each payload's JSON to the app's Application Support folder now. After milestone 2, upload it to your own server.

### 4.4 Reading logs

| Where | Command |
|---|---|
| Simulator, live | `xcrun simctl spawn <udid> log stream --style ndjson --level debug --predicate 'subsystem == "com.rontho14.note"'` |
| Simulator, after the fact | `xcrun simctl spawn <udid> log show --last 10m --style ndjson --predicate '...'` (add `--signpost` to include signposts) |
| iPhone over USB | `sudo log collect --device-udid <udid> --last 30m --output build/device.logarchive`, then `log show build/device.logarchive --style ndjson --predicate '...'`. Options checked with `log help collect`; whether `sudo` is required is **unverified**. Console.app also streams the phone. |
| Inside the app | `OSLogStore(scope: .currentProcessIdentifier)` reads the app's own entries ([OSLogStore](https://developer.apple.com/documentation/oslog/oslogstore)). A hidden "export diagnostics" action can share recent safe log lines from the phone without a Mac. |

Changing which levels are stored for a subsystem on macOS uses `sudo log config --mode "level:debug" --subsystem ...` or a logging profile ([Customizing logging behavior](https://developer.apple.com/documentation/os/customizing-logging-behavior-while-debugging)).

### 4.5 Crash reporting without the paid program

- The Xcode Organizer's crash and launch-time panes take data from TestFlight and the App Store, which need the paid program ([Acquiring crash reports](https://developer.apple.com/documentation/xcode/acquiring-crash-reports-and-diagnostic-logs), [Reducing launch time](https://developer.apple.com/documentation/xcode/reducing-your-app-s-launch-time)).
- Free options: MetricKit `CrashDiagnostic`/`HangDiagnostic` (4.3); Settings > Privacy & Security > Analytics & Improvements > Analytics Data on the phone; Xcode's Devices window over USB.
- Third party: Sentry ([sentry-cocoa](https://github.com/getsentry/sentry-cocoa) 9.31.0; free Developer plan with 5k errors, 1 user, 30-day lookback, per [pricing](https://sentry.io/pricing/)). If adopted, keep the defaults that matter: no IP address unless `sendDefaultPii` is true, URLs with query strings stripped from network breadcrumbs ([data collected](https://docs.sentry.io/platforms/apple/data-management/data-collected/)). Turn off screenshots, view hierarchy and session replay, because a screenshot of a notes app is note content (option names not verified on that page).
- Recommendation: MetricKit now. Revisit Sentry when there are users other than the owner.

### 4.6 The `Telemetry` module and its lint rules

The module (a file now, the `NoteTelemetry` package once the app is split into packages) is the only code that imports `os`:

```swift
import os

enum Event: String, Sendable {         // the registry; one case per log line kind
    case appLaunched = "app.launched", noteFinished = "note.finished"
    case syncCompleted = "sync.completed", opEnd = "op.end"
}

enum Field: Sendable {                 // no case takes a free-form String
    case noteID(NoteID), revisionID(RevisionID), opName(Op), durationMs(Int)
    case textLength(Int), revisionCount(Int), syncDirection(SyncDirection)
    case errorType(ErrorType), traceID(TraceID)
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

`NoteID` and friends are wrapper types around `UUID`. `ErrorType` is an enum of low-cardinality error classes, not `error.localizedDescription`, which can quote user input.

SwiftLint additions to the guardrails config (regex rules; swift-syntax custom rules would need a Bazel build of SwiftLint, per the guardrails file):

```yaml
custom_rules:
  no_print:                          # replaces the earlier rule
    regex: '\b(print|debugPrint|dump|NSLog)\('
    message: "Use Telemetry.event(...) or Telemetry.measure(...)"
    severity: error
  os_only_in_telemetry:
    regex: '^\s*(@preconcurrency\s+)?import\s+(os|OSLog)\b'
    excluded: ['.*/NoteTelemetry/.*', '.*/Telemetry\.swift$']
    message: "Only the Telemetry module talks to unified logging; use Telemetry.event/measure"
    severity: error
  no_logger_outside_telemetry:
    regex: '\b(Logger|OSSignposter|OSLog)\('
    excluded: ['.*/NoteTelemetry/.*', '.*/Telemetry\.swift$']
    message: "Use Telemetry; it carries the typed fields and the trace ID"
    severity: error
  no_error_description_in_telemetry:
    regex: 'localizedDescription'
    included: ['.*/NoteTelemetry/.*']
    message: "Map errors to ErrorType; error text can contain note content"
    severity: error
```

Lint can't prove that a key flow has a signpost. Tests can: the perf UI tests use `XCTOSSignpostMetric` for each budgeted op, and `perf-report` fails when an expected op has no samples (3.3).

---

## 5. Go in detail

### 5.1 `log/slog`

- **Handler.** `slog.NewJSONHandler(w, &slog.HandlerOptions{Level: levelVar, ReplaceAttr: scrub})`. `ReplaceAttr` sees every non-group attribute after `LogValuer` resolution and can "sanitize personal information, or remove attributes" ([HandlerOptions](https://pkg.go.dev/log/slog#HandlerOptions)). Use it as a last net that drops keys not in the registry, not as the main defense.
- **Context.** Always call the `...Context` variants so the handler can read the span. A small wrapping handler adds `trace_id` and `span_id` from `trace.SpanContextFromContext(ctx)`, matching OTel's [non-OTLP log field names](https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/compatibility/logging_trace_context.md). It must also wrap `WithAttrs` and `WithGroup`.
- **Fan-out.** `slog.NewMultiHandler` (in the Go 1.27 standard library, checked with `go doc`) sends each record to both the JSON file handler and the OTel bridge.
- **Redaction by type.** If a type implements `LogValuer`, its `LogValue` is used for logging, "for example, you can redact secret information like passwords" ([package docs](https://pkg.go.dev/log/slog)).
- **Testing handlers.** `testing/slogtest` checks a custom handler against the `slog` contract.

### 5.2 OpenTelemetry Go

- **Versions.** `go.opentelemetry.io/otel` v1.47.0 (2026-10-02). Its release notes call it "the first stable release of the OpenTelemetry Go Logs API and SDK". Contrib v1.47.0. The Go semconv package goes up to `semconv/v1.43.0`, with helper subpackages `httpconv`, `dbconv`, `rpcconv` and `genaiconv` ([pkg.go.dev](https://pkg.go.dev/go.opentelemetry.io/otel/semconv)); the spec is at v1.44.0, and the GenAI and MCP conventions now live in their own repo, so `genaiconv` may lag.
- **Traces.** `otelhttp.NewHandler` on the server and `otelhttp.NewTransport` on outbound clients (OpenAI). Spans for DB calls set `db.system.name="sqlite"`, `db.operation.name`, `db.collection.name` and `db.query.summary`, all stable. `db.query.text` is fine only with parameterized SQL; the spec says non-parameterized text "SHOULD NOT be collected by default unless there is sanitization" ([DB spans](https://github.com/open-telemetry/semantic-conventions/blob/main/docs/db/database-spans.md)). Never enable parameter capture.
- **GenAI spans.** Span name `{gen_ai.operation.name} {gen_ai.request.model}` (for example `chat gpt-5`), with `gen_ai.provider.name="openai"` (required), `gen_ai.request.model`, `gen_ai.response.model`, `gen_ai.usage.input_tokens`, `gen_ai.usage.output_tokens`, `gen_ai.response.finish_reasons` ([client-inference.md](https://github.com/open-telemetry/semantic-conventions-genai/blob/main/docs/gen-ai/client-inference.md), [openai.md](https://github.com/open-telemetry/semantic-conventions-genai/blob/main/docs/gen-ai/openai.md)). The spec says instrumentations "SHOULD NOT capture" instructions, inputs and outputs by default ([gen-ai-spans.md](https://github.com/open-telemetry/semantic-conventions-genai/blob/main/docs/gen-ai/gen-ai-spans.md)). For this app, never: `gen_ai.input.messages`, `gen_ai.output.messages` and `gen_ai.system_instructions` would put note text in telemetry.
- **MCP spans.** Server span kind `SERVER`, name `{mcp.method.name} {target}` (for example `tools/call edit_note`), attributes `mcp.method.name` (required), `gen_ai.tool.name`, `mcp.session.id`, `mcp.protocol.version`, `jsonrpc.request.id`, `error.type` (`tool_error` when `isError` is true). Metric `mcp.server.operation.duration` with buckets `[0.01 ... 300]` s. `gen_ai.tool.call.arguments` and `.result` are opt-in and stay off ([mcp.md](https://github.com/open-telemetry/semantic-conventions-genai/blob/main/docs/gen-ai/mcp.md)). The MCP Go SDK v1.8.0 has no built-in tracing; add it with `Server.AddReceivingMiddleware`, which wraps every method handler, and read trace context with the params' `GetMeta()`.
- **Logs bridge.** `go.opentelemetry.io/contrib/bridges/otelslog` turns `slog` records into OTel log records ([pkg.go.dev](https://pkg.go.dev/go.opentelemetry.io/contrib/bridges/otelslog), v0.21.0, pre-1.0). The log SDK copies the trace and span ID from the `ctx` passed to `...Context` calls (`trace.SpanContextFromContext(ctx)` in `sdk/log/logger.go` at v1.47.0).
- **Resource attributes.** `service.name=note-server`, `service.version=<git describe>`, `service.instance.id`, `deployment.environment.name` (`dev`, `e2e`, `prod`), all stable. In e2e add `note.e2e.run_id`.
- **Errors.** Set span status `Error` and `error.type` on failures; don't set `error.type` on success ([recording errors](https://github.com/open-telemetry/semantic-conventions/blob/main/docs/general/recording-errors.md)). `span.RecordError(err)` stores `err.Error()`, so error messages must not contain content (5.4).
- **Runtime metrics.** `go.opentelemetry.io/contrib/instrumentation/runtime` exports Go runtime metrics (memory, GC, goroutines) from `runtime/metrics`.

### 5.3 E2E mode wiring

Under the `e2e` build tag the server:

- writes `slog` JSON to `build/e2e/<run-id>/server.log`;
- exports spans to `build/e2e/<run-id>/spans.jsonl` with `stdouttrace.New(stdouttrace.WithWriter(f))` ([stdouttrace](https://pkg.go.dev/go.opentelemetry.io/otel/exporters/stdout/stdouttrace)). Pretty printing is opt-in, so output should be compact JSON; one span per line is **unverified**, so `perf-report` should parse a stream of JSON values, which `jq` does anyway;
- also exports OTLP to `localhost:4318` if `otel-desktop-viewer` is running (the exporter fails quietly otherwise);
- serves `net/http/pprof` on a second listener bound to `127.0.0.1` only. In production, pprof stays off or sits on the same loopback-only admin listener. Profiles hold stack samples and allocation sizes, not memory contents, but the endpoint still costs CPU on demand and shouldn't be public.

### 5.4 Keeping plaintext out, by type

ADR 0002 says plaintext exists only in server memory. Logs, spans, metrics and error strings leave memory, so they are part of that boundary.

```go
package crypt

// Plaintext holds decrypted note content. It cannot be printed, logged or
// marshaled by accident; Reveal is the only way out.
type Plaintext struct{ b []byte }

func (Plaintext) LogValue() slog.Value          { return slog.StringValue("[redacted]") }
func (Plaintext) String() string                { return "[redacted]" }
func (Plaintext) GoString() string              { return "[redacted]" }
func (Plaintext) Format(f fmt.State, _ rune)    { _, _ = io.WriteString(f, "[redacted]") }
func (p Plaintext) Len() int                    { return len(p.b) }  // shape, for spans
func (p Plaintext) Reveal() []byte              { return p.b }       // allowed callers only
```

`Format` covers `%v`, `%s`, `%q` and `%+v`, so `fmt.Errorf("...: %v", text)` is safe too. `Reveal` is allowed only in the sync encoder, the MCP response encoder, the AI provider and `crypt` itself, enforced by forbidigo with `analyze-types` (method matching) and path exclusions.

### 5.5 golangci-lint additions

Added to the `.golangci.yml` sketch in the guardrails file. Option names below were checked against `.golangci.reference.yml` at v2.15.0, which pins sloglint v0.12.0.

```yaml
linters:
  enable: [sloglint, spancheck]          # plus the existing list
  settings:
    sloglint:
      no-global: "all"                   # no slog.Info / slog.Default()
      context: "all"                     # only ...Context variants
      static-msg: true                   # message must be a literal or constant
      attr-only: true                    # slog.Attr arguments, no loose key/value pairs
      no-raw-keys: true                  # keys must be constants
      allowed-keys: [ ... ]              # the registry in section 6, generated later
      forbidden-keys: [time, level, msg, source]
      # key-naming-case: leave unset. It converts with ettle/strcase, which
      # treats "." as a delimiter, so "http.route" would be reported as not
      # snake_case. (From reading key_checks.go at v0.12.0; not run.)
    spancheck:
      checks: [end, record-error, set-status]
      extra-start-span-signatures:
        - "example.com/note/internal/telemetry.Start:opentelemetry"
    forbidigo:
      analyze-types: true
      forbid:
        - pattern: ^slog\.(String|Int|Int64|Uint64|Float64|Bool|Time|Duration|Any|Group|GroupAttrs)$
          msg: build attributes with internal/telemetry/attr so only registered keys and safe types are logged
        - pattern: ^attribute\.(String|StringSlice|Int|Int64|Float64|Bool|Stringer)$
          msg: build span attributes with internal/telemetry/attr
        - pattern: ^crypt\.Plaintext\.Reveal$
          msg: plaintext leaves crypt only in the sync/MCP encoders and the AI provider (ADR 0002)
```

Exempt `internal/telemetry/...` from the first two patterns and the allowed packages from the third with `linters.exclusions.rules`. Whether forbidigo's `analyze-types` matches the method expression `crypt.Plaintext.Reveal` as written is **unverified**; if not, a ruleguard rule does the same job.

ruleguard rules (`tools/ruleguard/rules-telemetry.go`). These are **sketches**: the DSL calls (`Match`, `Where`, `Type.Is`, `Text.Matches`, `Report`) exist per the [DSL docs](https://github.com/quasilyte/go-ruleguard/blob/master/_docs/dsl.md), but the patterns have not been run.

```go
//go:build ruleguard

package gorules

import "github.com/quasilyte/go-ruleguard/dsl"

// Revealed plaintext must never reach a log, span, metric or error.
func plaintextNeverInTelemetry(m dsl.Matcher) {
	m.Match(`$f($*_, $x.Reveal(), $*_)`, `$f($*_, string($x.Reveal()), $*_)`).
		Where(m["x"].Type.Is(`example.com/note/internal/crypt.Plaintext`) &&
			m["f"].Text.Matches(`(^attr\.|^attribute\.|^slog\.|\.(Debug|Info|Warn|Error|Log)(Context|Attrs)?$|\.SetAttributes$|\.AddEvent$|\.RecordError$|^fmt\.Errorf$|^errors\.New$)`)).
		Report(`note content must not reach telemetry or errors (ADR 0002)`)
}

// Log messages come from the events registry.
func logMessageFromRegistry(m dsl.Matcher) {
	m.Match(`$l.$f($ctx, $msg, $*_)`).
		Where(m["f"].Text.Matches(`^(Debug|Info|Warn|Error)Context$|^LogAttrs$`) &&
			!m["msg"].Text.Matches(`^events\.`)).
		Report(`log messages must be constants from internal/telemetry/events`)
}

// No logging inside loops: aggregate and log once at the boundary.
func noLogInLoop(m dsl.Matcher) {
	m.Match(`for $*_ { $*_; $l.$f($*_); $*_ }`,
		`for $*_ := range $_ { $*_; $l.$f($*_); $*_ }`).
		Where(m["f"].Text.Matches(`^(Debug|Info|Warn|Error)(Context)?$`)).
		Report(`log once per unit of work, not per iteration; count in a variable and log at the end`)
}
```

---

## 6. Attribute conventions shared by app and server

### 6.1 Base: OpenTelemetry semantic conventions

Use the stable names as-is: `service.*`, `deployment.environment.name`, `http.request.method`, `http.route`, `http.response.status_code`, `url.scheme`, `db.*`, `error.type`. Use the development-status `gen_ai.*`, `mcp.*`, `jsonrpc.request.id` and `session.id` too, pinned to one release. On iOS, OTel's `app.*` namespace (`app.installation.id`, `app.screen.name`) and `device.model.identifier`/`os.version` exist in the registry ([app attributes](https://github.com/open-telemetry/semantic-conventions/blob/main/docs/registry/attributes/app.md)).

OTel's naming guide says application-specific names should be prefixed by the application name and must not reuse an existing OTel namespace ([naming.md](https://github.com/open-telemetry/semantic-conventions/blob/main/docs/general/naming.md#recommendations-for-application-developers)). The app's prefix is `note.`.

### 6.2 The allowed list

| Key | Type | Spans / logs | Metrics | Analytics | Notes |
|---|---|---|---|---|---|
| `user.id` | string (internal random UUID) | yes | **no** | no | Never the email. Pseudonymous, not anonymous. Use OTel's `user.hash` instead if a third party ever receives per-user data. |
| `note.id` | UUID | yes | no | no | |
| `note.revision.id`, `note.revision.base_id` | UUID | yes | no | no | `base_id` makes sync conflicts readable. |
| `note.drawer.id` | UUID | yes | no | no | The ID, never the drawer's name: names are user content. |
| `note.agent.id` | string (OAuth grant/client ID) | yes | no | no | Not the agent's display name. |
| `note.actor.kind` | enum `user`, `ai`, `agent` | yes | yes | yes | |
| `note.job.kind` | enum `format`, `title`, `file`, `tag`, `link`, `backfill` | yes | yes | no | |
| `note.job.id`, `note.job.attempt` | string, int | yes | no | no | |
| `note.op.name` | enum (section 3.1 ops) | yes | yes | no | |
| `note.op.duration_ms` | int | logs | (histogram value) | no | |
| `note.sync.direction` | enum `push`, `pull` | yes | yes | no | |
| `note.text.length`, `note.revision.count`, `note.count` | int | yes | no | no | Shape for reproductions. Lengths are weakly sensitive; acceptable here. |
| `note.size_class` | enum `xs`, `s`, `m`, `l`, `xl` | yes | yes | yes | Bucketed length, safe for metrics. |
| `note.ai.provider_request_id` | string | yes | no | no | OpenAI's `x-request-id`, for support tickets. |
| `note.e2e.run_id` | string | resource attr in e2e only | | | |

Adding a key means adding a row here (later, a registry YAML entry), so it gets reviewed.

### 6.3 Never, anywhere

Note text, titles, Markdown, revision diffs; drawer names, tag names; agent display names; emails; OAuth access/refresh tokens, API keys, session cookies, `Authorization` headers; KMS key material, data keys, ciphertext; prompts and completions (`gen_ai.input.messages`, `gen_ai.output.messages`, `gen_ai.system_instructions`); MCP tool arguments and results (`gen_ai.tool.call.arguments`, `.result`); raw SQL parameters; full URLs with query strings (`url.full`, `url.query`); client IP addresses (`client.address`, unless truncated); free-form error messages from the AI provider (they can quote the input; use `error.type`). `mcp.resource.uri` is allowed only because this app's resource URIs contain IDs, never titles.

### 6.4 Cardinality budget

- Metric attributes come only from enums. Each metric stays under 50 series. The whole server stays under 1,000 active series, a tenth of Grafana Cloud's free 10k.
- Span and log attributes may be high-cardinality IDs. That is what traces are for.
- Span names stay low-cardinality: `POST /v1/sync`, `tools/call edit_note`, `chat gpt-5`. Never `GET /v1/notes/6F1C...`.

### 6.5 Enforcement

| Layer | iOS | Go |
|---|---|---|
| Types | `Field` enum with no free-string case; ID wrapper types | `attr` package: `attr.NoteID(ids.NoteID) slog.Attr`, `attr.JobKind(jobs.Kind)`; `crypt.Plaintext` redacts itself |
| Lint | SwiftLint rules in 4.6 | forbidigo on raw constructors, sloglint `allowed-keys` + `no-raw-keys`, ruleguard rules in 5.5 |
| Tests | Unit test that every `Field` key is in the registry | `tracetest` assertions that spans carry only registered keys |
| E2E | Canary grep: no seeded canary string in `app.log`, `server.log`, `spans.jsonl`, `perf.json`, analytics output, or exported OTLP files | same |
| Schema | Hand-written enums now | [OTel Weaver](https://github.com/open-telemetry/weaver) v0.28.0 later: a YAML registry that generates the Go and Swift constants and docs, and `weaver registry live-check` that receives OTLP during e2e and reports attributes not in the registry |

The canary grep extends the guardrails file's `make e2e-invariants` from the database to every telemetry output. It's the check that catches what types and lint miss.

---

## 7. Correlation across the system

```
iPhone app                  Go server                                  outside
----------                  ---------                                  -------
user finishes note
 trace T, span A
 POST /v1/sync ---------->  otelhttp server span B (parent A)
 traceparent: 00-T-A-01      store revision; enqueue job,
                             saving traceparent 00-T-B-01 on the row
                            ...
                            worker picks job: span C, parent B,
                             link to worker's own context
                             chat gpt-5: span D (parent C) ---------->  OpenAI
                               X-Client-Request-Id: <T>-<D>            returns x-request-id
                               log note.ai.provider_request_id
                             content check, revision stored

Claude (agent)
 tools/call edit_note ---->  MCP middleware: parent from params._meta.traceparent
                             if present, else new trace; span E
```

- **App.** Generate a 16-byte trace ID and 8-byte span ID per user operation with `SystemRandomNumberGenerator`, add `traceparent` to the `URLRequest`, and include `trace_id` on the `op.end` line. The OTel Swift SDK ([opentelemetry-swift](https://github.com/open-telemetry/opentelemetry-swift) 2.6.0) isn't needed for this; formatting one header is a few lines. Adopt it only if app spans should be exported later.
- **Server.** `otelhttp.NewHandler` with the W3C propagator continues the app's trace. The server returns its trace ID in a response header (for example `Note-Trace-Id`) so the app can log it even when it didn't start the trace.
- **Job queue.** Store the enqueuing span's `traceparent` in the job row. When processing, use it as the parent so the whole finish flow is one trace, and add the worker's ambient context as a link. The messaging conventions make links the default and allow the creation context as parent, in which case the ambient context "SHOULD" be added as a link ([messaging spans](https://github.com/open-telemetry/semantic-conventions/blob/main/docs/messaging/messaging-spans.md)). One trace per finish is what lets `note.finish` be measured from spans.
- **OpenAI.** Wrap the openai-go client's HTTP client with `otelhttp.NewTransport`. OpenAI accepts a caller-chosen `X-Client-Request-Id` (ASCII, at most 512 characters) and returns `x-request-id`; it recommends logging request IDs ([API reference, request IDs](https://developers.openai.com/api/reference/llms-full.txt)). OpenAI ignores `traceparent`, so the trace ends at the client span.
- **MCP.** The MCP conventions put `traceparent`, `tracestate` and `baggage` in `params._meta`; the server "extracts the context from `params._meta` and uses it as the remote parent" ([mcp.md](https://github.com/open-telemetry/semantic-conventions-genai/blob/main/docs/gen-ai/mcp.md)). Most agent clients won't send it, so expect new root spans. Returning the trace ID in the tool result's `_meta`, and in error text, lets an agent report "this call failed, trace T" back to the owner.

**How agents use it in e2e.** Every file under `build/e2e/<run-id>/` carries `trace_id`. `scripts/trace <trace-id>` prints all matching lines from `app.log`, `server.log` and `spans.jsonl`, sorted by time, as JSON. If the viewer is running, `otel-desktop-viewer trace <trace-id> --json` returns every span and trace-linked log with durations, and `otel-desktop-viewer query '<SQL>'` runs read-only SQL over stored spans ([README](https://github.com/CtrlSpice/otel-desktop-viewer)). A failing scenario prints its trace IDs, so the agent's first move is obvious.

---

## 8. Product analytics

### 8.1 Options

| Option | Fit | Cost | Privacy and labels |
|---|---|---|---|
| Nothing third party; OTel events to own backend | Best fit with ADR 0002 and the "no content" rule; same registry as logs. No dashboards for free: query with SQL on your own server or the observability backend. | Free | Data stays on infrastructure you control. Still "collected" in Apple's sense once it leaves the device. |
| [TelemetryDeck](https://telemetrydeck.com/) ([SwiftSDK](https://github.com/TelemetryDeck/SwiftSDK) 2.14.2) | Swift-first, privacy-focused, made for Apple apps. | New accounts get 50,000 free events/month since July 2026 ([pricing update](https://telemetrydeck.com/blog/pricing-update-2026/)); paid prices not stated in text. | Salts and hashes user identifiers on device and again at ingestion. Its guide says to declare Device ID and Product Interaction as not linked to you, unless you add identifying data ([guide](https://telemetrydeck.com/docs/articles/apple-app-privacy/)). |
| [PostHog](https://posthog.com/) ([posthog-ios](https://github.com/PostHog/posthog-ios) 3.92.6) | Most features: funnels, feature flags, session replay, surveys. Heavy for one user. | Cloud free tier 1M events/month ([self-host docs](https://posthog.com/docs/self-host)). Self-hosting is "officially unsupported" and needs a 4 vCPU / 16 GB VM. | Session replay on a notes app would record note text on screen; never enable it. |
| [Aptabase](https://github.com/aptabase/aptabase) ([aptabase-swift](https://github.com/aptabase/aptabase-swift) 0.4.0) | Small, simple, open source (AGPLv3, SDKs MIT), self-hostable. | Cloud: 20,000 events/month free, then $10/month for 200,000 ([pricing](https://aptabase.com/pricing)). | Claims "minimal usage data without using unique identifiers". |

### 8.2 Recommendation

Start the **definitions** now and the **sending** later.

- Now: put analytics events in the same `Event` registry (`note.finished`, `note.reverted`, `drawer.moved_by_user`, `rewrite.rejected`), each with only enum or count properties from section 6. Log them locally like any other event. This costs nothing and makes the event list part of every feature's checklist.
- With the Go backend: send them as OTel log records with an event name (the logs data model has an `EventName` field; [data model](https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/logs/data-model.md)) to your own server, batched with sync. Query them in the observability backend or SQLite.
- Only if other users arrive and you want dashboards without building them: TelemetryDeck, because it is Swift-native and its privacy model matches this app. PostHog is the choice if feature flags or experiments become a need.

**App Store privacy labels** (needed only once the app ships through the paid program). Apple defines "collect" as transmitting data off the device so that you can access it "for a period longer than what is necessary to service the transmitted request in real time". Product Interaction (taps, launches), Crash Data, Performance Data and Other Diagnostic Data are separate types. Data tied to `user.id` is "linked to you" unless it is de-identified before collection. "Tracking" means combining with third-party data for advertising or sharing with data brokers, which this app never does ([App privacy details](https://developer.apple.com/app-store/app-privacy-details/)). Expect to declare Product Interaction, Performance Data and Crash Data, linked to the user if they carry `user.id`, not used for tracking. Note content synced to your server is "Other User Content", declared because sync is the app's function.

---

## 9. Where telemetry goes

### 9.1 Local development and e2e

| Tool | What | Fit |
|---|---|---|
| Files under `build/e2e/<run-id>/` | `app.log`, `server.log`, `spans.jsonl`, `perf.json` | Always on. The source of truth for agents and CI. |
| [otel-desktop-viewer](https://github.com/CtrlSpice/otel-desktop-viewer) v0.6.0 | Built on the OTel Collector and DuckDB. UI on `:8000`, OTLP on `:4317`/`:4318`. In-memory by default, `--db` to persist (512 MB in memory, 2 GB on disk, oldest pruned). CLI: `traces`, `logs`, `metrics`, `trace <id>`, `span <id>`, `query '<SQL>'`, all with `--json`. | **Recommended.** `brew tap ctrlspice/otel-desktop-viewer && brew install --cask otel-desktop-viewer`. No Docker. |
| [grafana/otel-lgtm](https://github.com/grafana/docker-otel-lgtm) v0.38.1 | One Docker image: Collector, Prometheus, Tempo, Loki, Pyroscope, Grafana. "Intended for development, demo, and testing." | Useful to rehearse Grafana dashboards and alerts before production. Needs Docker. |
| [Jaeger](https://github.com/jaegertracing/jaeger) v2.22.0 | Traces only. | Superseded here by the viewer. |
| [SigNoz](https://github.com/SigNoz/signoz) v0.147.0, [OpenObserve](https://github.com/openobserve/openobserve) v1.1.2 | Full backends you can self-host. | More than local dev needs. |
| [otel-tui](https://github.com/ymtdzzz/otel-tui) v0.7.5 | OTLP receiver with a terminal UI. | Optional, for humans in a terminal. |

### 9.2 Production

- **Grafana Cloud free** ([pricing](https://grafana.com/pricing/)): 10k active metric series, 50 GB logs, 50 GB traces, 50 GB profiles per month, 14-day retention, 3 users, alerting. With mcp-grafana, agents can search and diff traces. **Recommended start.**
- **Honeycomb free** ([pricing](https://www.honeycomb.io/pricing)): up to 20M events and 100M metric data points per month, 2 triggers, no SLOs on free. The best tool for exploring wide events; the free plan's limits on SLOs and triggers make it second here.
- **Sentry free** for iOS crashes, if MetricKit isn't enough (4.5).
- **OTel Collector: not at first.** The Go SDK exports OTLP straight to the backend. Add a Collector ([releases](https://github.com/open-telemetry/opentelemetry-collector-releases) v0.164.0) when you need tail-based sampling, a central scrubbing step, or two destinations. Litestream and the server share one host anyway.

### 9.3 Secrets that touch telemetry

- The backend's OTLP token lives only in the server's environment on the host. It is read by `internal/config` (the only package allowed `os.Getenv`, per the guardrails file).
- The iOS app never holds a third-party telemetry write key. The repo is public, and strings in an app binary can be extracted. The app sends telemetry to your own server with the user's normal auth, and the server forwards it. A TelemetryDeck app ID, if ever used, is designed to be public, but still goes in an `.xcconfig`, not in Swift source.
- GitHub secret scanning "runs automatically for free" on public repositories ([docs](https://docs.github.com/en/code-security/secret-scanning/introduction/about-secret-scanning)), and push protection for users is on by default and blocks pushing supported secrets to public repos ([docs](https://docs.github.com/en/code-security/secret-scanning/introduction/about-push-protection)). Grafana Cloud and Honeycomb tokens being in GitHub's supported pattern list is **unverified**; [gitleaks](https://github.com/gitleaks/gitleaks) v8.30.1 in the pre-commit hook is a cheap local check if it isn't.
- `.env*`, `*.logarchive` and `build/` stay in `.gitignore`. E2E logs never get committed; CI uploads them as artifacts, and the canary check guarantees they contain no content anyway.

---

## 10. Making it a habit for every feature

### 10.1 Feature checklist

A feature isn't done until:

1. **Boundary event.** It emits one `info` event per unit of work at its boundary (registry entry added), and errors are logged once where they are handled.
2. **Span.** Each user-visible operation has a span (server) or a `Telemetry.measure` interval (app), named from the registry.
3. **Budget.** If users wait on it, it has an entry in `perf/budgets.json`, a histogram on the server, and a scenario in `perf/scenarios/`.
4. **Attributes.** Only registered keys; shape attributes (lengths, counts) where they would help reproduce slowness.
5. **Analytics.** If it is a product action, an analytics event in the registry.
6. **Proof.** The e2e scenario's expectation file lists its required events and spans, and `make e2e` passes the log budget, the perf budget and the canary check.

### 10.2 Ways to enforce or verify it

| Layer | Mechanism |
|---|---|
| Types | `Event`, `Field`, `Op` enums (Swift); `events`, `attr` packages and `crypt.Plaintext` (Go). |
| Lint | SwiftLint rules (4.6); sloglint, spancheck, forbidigo, ruleguard (5.5). |
| Go unit tests | `tracetest.NewInMemoryExporter()` / `NewSpanRecorder()` give the spans a handler produced ([tracetest](https://pkg.go.dev/go.opentelemetry.io/otel/sdk/trace/tracetest)). A shared helper asserts: span name, required attributes present, no unregistered keys, status set on error. A capture `slog.Handler` asserts exactly one boundary event per request. |
| iOS unit tests | `Telemetry` sends to an injectable sink; tests assert the event and fields for a store operation. |
| E2E | `e2e/expect/<scenario>.json` lists required events, spans and ops. `make e2e` fails on a missing one, an unexpected warning or error, a log budget breach, a perf budget breach or regression, or a canary hit. |
| CI | The same `make e2e` on GitHub Actions. The repo is public, so macOS minutes are free. |
| CLAUDE.md (weakest) | "Every feature: one boundary event, a span or `Telemetry.measure` per user-visible op, a budget if users wait on it, registered attributes only. Run `make e2e` and read `perf.json`." |

---

## Proposed setup for this repo

These steps slot into the ordered list in [agent-guardrails-and-testing.md](agent-guardrails-and-testing.md#proposed-setup-for-this-repo); its step numbers are in brackets. Smallest first.

### Now (iOS only, before the data layer)

1. **Add `Telemetry.swift`** with `Event`, `Field`, `Op`, `Telemetry.event(...)` and `Telemetry.measure(...)` (Logger + OSSignposter, subsystem `com.rontho14.note`). Emit `app.launched` and measure `app.launch` from `App.init` to the text field becoming first responder. It moves into a `NoteTelemetry` package at guardrails step [8].
2. **Extend `.swiftlint.yml`** [2] with `no_print` (widened), `os_only_in_telemetry`, `no_logger_outside_telemetry` and `no_error_description_in_telemetry`.
3. **Add `perf/budgets.json`** with the section 3.1 ops, and `perf/scenarios/launch.json`.
4. **Add a `NotePerfTests` UI test target** [4] with `XCTApplicationLaunchMetric(waitUntilResponsive: true)`, `XCTOSSignpostMetric` for `app.launch`, and `XCTHitchMetric` for the mode swipe, 10 iterations.
5. **Add `scripts/perf-report`** (bash + `jq`): reads `xcresulttool get test-results metrics` and `app.log` `op.end` lines, writes `perf.json` and Go-benchmark-format samples, compares to budgets and `build/perf/baseline-local.json`, and exits non-zero on failure. Expose `make perf`, `make perf-baseline`, and `make perf-ab BASE=<sha>` (git worktrees + benchstat via `go run golang.org/x/perf/cmd/benchstat@<version>`).
6. **Capture app logs in `scripts/sim`** [5]: `log stream --style ndjson` into `build/e2e/<run-id>/app.log`, started before launch. Add `scripts/log-budget` and the canary grep over `app.log`.
7. **Add `make profile-ios SCENARIO=launch`** wrapping `xctrace record --template 'Time Profiler'` against the E2E simulator.
8. **Add the MetricKit subscriber** (`MXMetricManager`) that writes payload JSON to Application Support. Try it on the phone; record whether payloads arrive on a free-account build.
9. **CI** [7]: run `make perf` on the macOS runner. Report-only for the first two weeks to learn the noise, then gate on budgets and the regression rule against the `main` baseline artifact.
10. **CLAUDE.md** [3]: the two lines from 2.3 and 10.2.

When GRDB lands [8], add `note.save` and `note.keystroke` measurements and their budgets.

### With the Go backend (milestone 2)

1. **`internal/telemetry`** [9]: `slog` JSON handler with `trace_id`/`span_id`, `ReplaceAttr` scrubber, `MultiHandler` to the otelslog bridge; `events` and `attr` packages; tracer and meter providers with resource attributes; runtime metrics.
2. **`crypt.Plaintext`** with `LogValue`/`String`/`GoString`/`Format` redaction and `Reveal` restricted.
3. **golangci-lint**: sloglint (settings in 5.5, `allowed-keys` from the registry), spancheck, the forbidigo patterns, `tools/ruleguard/rules-telemetry.go`. Prove each rule bites with a known-bad snippet, as the guardrails file asks.
4. **HTTP and correlation**: `otelhttp` server and client, `Note-Trace-Id` response header, `traceparent` from the app's sync client, the job row's `traceparent` with parent plus link, OpenAI `X-Client-Request-Id` and `note.ai.provider_request_id`, MCP receiving middleware reading `params._meta`.
5. **Histograms** for every budgeted server op, using semconv names and bucket boundaries where defined.
6. **E2E telemetry** [10, 11]: `server.log`, `spans.jsonl`, optional OTLP to otel-desktop-viewer, loopback pprof, `note.e2e.run_id`. `perf-report` adds `note.finish`, `sync.run`, `ai.inference` (with tokens) and `mcp.tool`. Add `scripts/trace <id>`.
7. **Invariants** [12]: extend the canary check to every telemetry output; add `e2e/expect/<scenario>.json` checks and the server log budget.
8. **Go benchmarks** for the content check, Markdown handling, encryption and sync encoding, using `b.Loop()` and `-count=10`, compared with benchstat in `make perf-ab`. Add `make profile-server`.
9. **`tracetest` helpers** so each handler test asserts its span and boundary event.
10. **Weaver registry**: move the section 6 table to YAML, generate Go and Swift constants and sloglint's `allowed-keys`, and run `weaver registry live-check` during `make e2e`.
11. **Production**: export OTLP from the server to Grafana Cloud free (token in host env only), define the SLOs in 3.7 with burn-rate alerts, set up mcp-grafana for agents, and start sending analytics events and MetricKit payloads through your own server.
12. **Later, only if needed**: an OTel Collector (scrubbing, tail sampling), Sentry for iOS crashes, TelemetryDeck if other users arrive.
