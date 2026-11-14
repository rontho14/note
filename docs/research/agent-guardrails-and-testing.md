# Agent guardrails and autonomous testing

> **Revised 2026-11-13.** The first version of this note, from 2026-10-27, planned a Go server with encryption, an AI provider, MCP access and sync. [ADR 0001](../adr/0001-local-only-app-with-no-backend.md) dropped all of that. This revision removes those parts and rewrites the test plan for an app with no server. The original is in git history. The app's structure is decided in [ADR 0005](../adr/0005-app-structure-and-enforced-boundaries.md).

Research date: 2026-10-27. Versions were checked against GitHub releases on that date. Anything marked **unverified** could not be confirmed from a primary source.

## Summary

- **"e2e" is almost certainly [e2e by TesterArmy](https://e2e.tester.army/).** It is an open source (Apache-2.0) TypeScript test runner, launched on [2026-10-01](https://e2e.tester.army/blog/introducing-e2e), with 12k GitHub stars. It **does support native iOS apps in the Simulator**: the repo ships a [SwiftUI example](https://github.com/tester-army/e2e/tree/main/examples/with-swiftui) last checked with Xcode 27.1 on an iOS 26.5 simulator. It is pre-1.0, needs Node, and agent steps need a model key or subscription.
- **Make bad code impossible, in this order** (Lauren Tan's ranking, echoed by Matt Pocock): first, design types and modules so the mistake can't be expressed. Second, a lint rule or test that fails CI. Prose in CLAUDE.md comes last.
- **Swift: turn on the stricter compiler modes Xcode 27.1 already ships.** These are Swift 6 mode (already on), warnings as errors (already on), `ExistentialAny`, `MemberImportVisibility`, `InternalImportsByDefault`, approachable concurrency, and default MainActor isolation for the UI module. Split the app into local Swift packages so that, for example, only the store module imports GRDB. Format with swift-format, which ships in the Xcode toolchain. SwiftLint 0.65 is available for rules the compiler can't express.
- **Add checks as the code they protect is written.** ADR 0005 starts with three import checks and adds the rest when their code appears or when a rule gets broken twice.
- **One entry point: `make check`.** It runs format check, checks, build and tests. A plain git pre-commit hook runs the fast part, and GitHub Actions runs everything. CI is the real gate, because `git commit --no-verify` skips local hooks.
- **The top testing priority is one command to a running app in a known state.** `make sim-up` builds the app in an `E2E` configuration, boots a dedicated simulator, installs the app and launches it with test launch arguments: reset storage, load a fixture, shift the clock, turn off animations. It writes one `build/e2e/state.json` with the simulator ID, the app's data folder, the database path and the log command an agent needs.
- **Agents drive the running app several ways.** Claude Code Desktop's built-in [iOS Simulator pane](https://code.claude.com/docs/en/desktop-ios-simulator) or MobileBuildMCP (formerly XcodeBuildMCP) work for exploration. `xcrun simctl` scripts control the simulator. A committed XCUITest suite gives repeatable scenarios. Maestro or TesterArmy's e2e are optional extra drivers.
- **Agents verify outcomes from several sides.** These are the accessibility tree, screenshots, the app's own SQLite file (found with `xcrun simctl get_app_container`), the app's logs, and a `make e2e-invariants` command that checks the database against the app's rules.
- **Nothing here needs the paid Apple Developer Program.** Simulator builds, XCUITest, simctl, Maestro, e2e and the simulator MCP tools all work without signing. Only physical-device automation needs a team ID.

---

## 1. Which "e2e" AI testing framework?

### Most likely: e2e by TesterArmy

| Fact | Source |
|---|---|
| Announced 2026-10-01 by Oskar Kwaśniewski (TesterArmy, YC-backed). A launch summary on X puts the launch post at about 449K views. | [Launch post](https://e2e.tester.army/blog/introducing-e2e), [AGTP summary on X](https://x.com/AGTPinsights/status/2105811877293084993) (secondary) |
| Package name is literally `e2e` on npm (latest `0.21.3`, 2026-10-27). Install with `npx e2e@latest init`. | [Site](https://e2e.tester.army/), [repo releases](https://github.com/tester-army/e2e/releases) |
| Repo `tester-army/e2e`, Apache-2.0, about 12.0k stars, created 2026-07-22. README: "in active development on the way to 1.0". | [GitHub](https://github.com/tester-army/e2e) |
| Tests can be deterministic (locators and `expect`), agent-driven (`agent.act`, `agent.assert` in natural language), or a mix. Passing agent steps are cached and replayed without model calls. | [Launch post](https://e2e.tester.army/blog/introducing-e2e), [cache docs](https://e2e.tester.army/docs/cache) |
| Ships an MCP server (`e2e mcp`) and an agent skill (`npx skills add tester-army/e2e`), so Claude Code can explore the live app and write locators from the real UI. | [Launch post](https://e2e.tester.army/blog/introducing-e2e), [site](https://e2e.tester.army/) |

**iOS support: yes, native apps in the Simulator.**

- The mobile engine `@e2e-dev/mobile` drives iOS simulators and Android emulators through Callstack's [agent-device](https://github.com/callstackincubator/agent-device) (MIT, v0.21.33). ([mobile docs](https://e2e.tester.army/docs/mobile))
- iOS target config: `mobile({ platform: 'ios' })` plus `app.bundleId` and/or `app.appPath` (a simulator `.app`). `getByTestId` reads the SwiftUI `.accessibilityIdentifier()`. ([mobile docs](https://e2e.tester.army/docs/mobile))
- The repo's [`examples/with-swiftui`](https://github.com/tester-army/e2e/tree/main/examples/with-swiftui) README says its tests passed on 2026-10-19 with e2e 0.21.2, @e2e-dev/mobile 0.12.3, Xcode 27.1 and an iOS 26.5 simulator. That is this repo's exact Xcode.
- Requirements: Xcode with a simulator runtime, plus Node 22.22.3+, 24.8+ or 26+. Agent steps need an AI SDK model, such as a Vercel AI Gateway or OpenRouter key, a local model, or a ChatGPT/Copilot/SuperGrok subscription. Without a key, agent tests skip and deterministic tests still run. ([mobile docs](https://e2e.tester.army/docs/mobile), [SwiftUI example README](https://github.com/tester-army/e2e/blob/main/examples/with-swiftui/README.md), [launch post](https://e2e.tester.army/blog/introducing-e2e))
- Physical iPhones need a team ID and signing (`AGENT_DEVICE_IOS_TEAM_ID`). Simulator use needs neither. ([mobile docs](https://e2e.tester.army/docs/mobile))

**Fit for this repo.** e2e is a good candidate for the agentic and natural-language layer: "write a note, save it into a drawer, and check it shows up there", with a deterministic check alongside. Two limits: it adds a Node toolchain to a Swift-only repo, and it is pre-1.0.

### Other candidates considered

| Product | What it is | Native iOS in Simulator? |
|---|---|---|
| [Maestro](https://github.com/mobile-dev-inc/Maestro) (CLI 2.12.0, 2026-10-26) | YAML flows for mobile and web. Has a built-in MCP server (`maestro mcp`). The AI commands `assertWithAI` and `assertNoDefectsWithAI` are experimental and routed through Maestro Cloud. | **Yes.** Runs on "any iOS Simulator managed by Xcode", including SwiftUI apps. ([iOS docs](https://docs.maestro.dev/get-started/supported-platform/ios), [MCP docs](https://docs.maestro.dev/getting-started/maestro-mcp), [assertWithAI](https://docs.maestro.dev/reference/commands-available/assertwithai), [AI configuration](https://docs.maestro.dev/api-reference/configuration/ai-configuration)) |
| [Playwright Test Agents](https://playwright.dev/docs/test-agents) | Planner, generator and healer agents for Playwright tests (`npx playwright init-agents`). | **No.** Browsers only; iOS means mobile Safari emulation. |
| [Shortest](https://github.com/antiwork/shortest) (antiwork) | Natural-language tests "built on Playwright". | **No.** Web only. |
| [Momentic](https://momentic.ai/blog/mobile) | Commercial AI testing platform that added mobile. | **Yes, beta.** Native Swift apps on hosted iOS 26 simulators from a simulator `.app`. ([iOS quickstart](https://momentic.ai/docs/quickstart/ios)) |
| [QA Wolf](https://www.qawolf.com/solutions/ios-testing) | Managed QA service using Appium. | Real iPhones on their device farm, not your Simulator. It is a service, not a framework. |
| Octomind | AI test generation. | No mobile support found. **Unverified.** |

**Conclusion.** The owner's description matches TesterArmy's e2e: a new framework, literally named "e2e", launched about four weeks before this research. I'm confident this is the one, but I can't confirm it is what the owner saw. If they meant something else, Maestro is the strongest established alternative with iOS Simulator support.

---

## 2. Guardrails: what Lauren Tan and Matt Pocock say

### Lauren Tan (poteto)

Her current X handle is [@poteto](https://x.com/poteto), not @potetotes. She was on the React Compiler team; recent coverage places her on Grok Bot at xAI/SpaceXAI. Sources disagree on her current employer, and it doesn't matter here.

X pages could not be fetched directly (HTTP 402), so the post texts below come from search-engine snippets. Treat exact wording as **unverified**.

- **Ranking of fixes.** In a [post](https://x.com/poteto/status/2089067865098113024), she says every time you correct your agent, you should ask how to remove the problem for good. Her order: categorically eliminate it through architecture or data structures; then "turn it into a lint rule or test so CI catches it"; soft guidance after that.
- **Review feeds lints.** In [another post](https://x.com/poteto/status/2092512896408592713), she says she still reviews what agents land, watches for code smells, and then either refactors to remove the problem or adds lints to prevent it.
- **Talk (Sept 2026), from a third-party [transcript](https://cho.sh/7D77B5) and [write-up](https://redreamality.com/blog/lauren-tan-poteto-trust-before-parallel/).** Her Dune framework and Grok Bot ban `useEffect` and code comments in CI. Her first reaction to a bad pattern is to ask how to turn it into a lint rule. Without hard constraints, she says, a codebase degrades fast. Verification means the agent can actually run the code; it proves correctness, not quality.
- **Verification skill pattern.** Her public [verification-skill-example](https://github.com/poteto/verification-skill-example) repo shows a project-local skill with a doctor step, a driver and a behavior-level feature map: one short file per feature area, saying how a user reaches it, how to drive it, and what to check. Evidence includes screenshots, DOM assertions and reload round-trips.

### Matt Pocock

- **Agents do better locked down.** In a [Sept 2026 post](https://x.com/mattpocockuk/status/2103431302527508886) praising Lauren's talk, he summarizes: humans like powerful "sharp knife" abstractions, but agents perform better in locked-down environments, where abstractions are designed so they can't be misused and lint rules enforce that. (From search snippet; **unverified** wording.)
- **Feedback loops.** In his AI Hero article [Essential AI Coding Feedback Loops](https://www.aihero.dev/essential-ai-coding-feedback-loops-for-type-script-projects), type checking is free feedback for the agent. A pre-commit hook runs typecheck, lint and tests, and a failure blocks the commit, so the agent simply retries.
- **Deep modules need enforcement.** His skills repo's [`codebase-design` doc](https://github.com/mattpocock/skills/blob/main/docs/engineering/codebase-design.md) quotes the question of how to enforce a deep module's interface, and points to a linter that forbids imports bypassing the interface. The in-progress [`setup-ts-deep-modules`](https://github.com/mattpocock/skills/blob/main/skills/in-progress/setup-ts-deep-modules/SKILL.md) skill does this with dependency-cruiser: package root files are the only public entry points, deep imports are errors, cycles are errors, and the skill "proves the rules bite".
- **Pre-commit setup** is packaged as a skill: [`setup-pre-commit`](https://github.com/mattpocock/skills/tree/main/skills/misc/setup-pre-commit).

### Translation to this stack

Both people's advice, applied here, comes down to four steps:

1. Pick types and module boundaries that make the mistake inexpressible.
2. Where that's not possible, add a rule that fails `make check` and CI.
3. Make every rule's failure message tell the agent what to do instead.
4. Prove each rule bites by adding a known-bad snippet and watching it fail.

#### Layer 1: designs that make mistakes impossible

These come from the project's own invariants in VISION.md and the ADRs.

| Invariant | Structural enforcement |
|---|---|
| Typed text is never modified ([ADR 0003](../adr/0003-typed-text-is-never-modified.md)) | `NoteStorage` has one way to write a note's text: save exactly what the user typed. Title, drawer and corrections are written through separate methods that cannot touch the text. |
| Deletes go to the trash first (VISION) | `NoteStorage` offers `trash` and `restore`, not `delete`. Removing a note for good happens only inside the store's 30-day purge. |
| Time-based rules (5-minute draft, 30-day trash) | Pass the current time in as an argument or through a small clock type. `NoteCore` never reads the clock itself. |
| Only the store touches SQLite ([ADR 0004](../adr/0004-sqlite-with-grdb-and-fts5-search.md)) | GRDB is a dependency of the `NoteStore` package only. This does not stop an import under Xcode on its own (see below), so a text check backs it up. |

Swift packages and the `package` access level ([SE-0386](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0386-package-access-modifier.md)) are the Swift version of Matt's dependency-cruiser setup.

#### Swift (layer 2)

Current versions: SwiftLint [0.65.1](https://github.com/realm/SwiftLint/releases), SwiftFormat [0.64.4](https://github.com/nicklockwood/SwiftFormat/releases), swift-format [604.0.0](https://github.com/swiftlang/swift-format/releases), Periphery [3.8.0](https://github.com/peripheryapp/periphery/releases), XcodeGen 2.46.0, GRDB [v7.11.1](https://github.com/groue/GRDB.swift/releases). Local toolchain: Apple Swift 6.4 in Xcode 27.1.

**Compiler settings.** These build setting names exist in Xcode 27.1's `Swift.xcspec`, checked locally. The proposals are linked.

| Setting | Effect |
|---|---|
| `SWIFT_VERSION: 6.0` (already on) | Complete concurrency checking; data races are errors. |
| `SWIFT_TREAT_WARNINGS_AS_ERRORS: YES` (already on) | All warnings fail the build. `SWIFT_WARNINGS_AS_WARNINGS_GROUPS` can exempt a specific diagnostic group if one becomes noise ([SE-0443](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0443-warning-control-flags.md)). |
| `SWIFT_UPCOMING_FEATURE_EXISTENTIAL_ANY: YES` | Requires `any P`, making existential costs visible ([SE-0335](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0335-existential-any.md)). |
| `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY: YES` | A file must import a module to use its members, which keeps module boundaries honest ([SE-0444](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0444-member-import-visibility.md)). |
| `SWIFT_UPCOMING_FEATURE_INTERNAL_IMPORTS_BY_DEFAULT: YES` | Imports don't leak into a module's public API ([SE-0409](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0409-access-level-on-imports.md)). |
| `SWIFT_APPROACHABLE_CONCURRENCY: YES`, `SWIFT_DEFAULT_ACTOR_ISOLATION: MainActor` (UI module only) | Nonisolated async functions run on the caller's actor ([SE-0461](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0461-async-function-isolation.md)), and UI code is MainActor by default ([SE-0466](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0466-control-default-actor-isolation.md)). Keep `NoteCore` and `NoteStore` nonisolated. |
| `SWIFT_STRICT_MEMORY_SAFETY: YES` (optional) | Flags unsafe constructs in your own code ([SE-0458](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0458-strict-memory-safety.md)). Try it, and keep it if it isn't noisy. |

**Module boundaries.** The code is split into local Swift packages, `NoteCore`, `NoteStore` and `NoteUI`, with a thin app target ([ADR 0005](../adr/0005-app-structure-and-enforced-boundaries.md)). Each `Package.swift` lists allowed dependencies, but that alone does not make a forbidden import a compile error. Xcode builds share module search paths, so a package can import a module it never declared. SwiftPM's `--explicit-target-dependency-import-check error` catches this, but only in `swift build`. ADR 0005 records how the boundaries are enforced instead. XcodeGen references local packages through its `packages:` key.

**SwiftLint.** Not needed for the first checks, which are plain text searches. It becomes worth installing when the rules outgrow `grep`. Settings below are from the [README](https://github.com/realm/SwiftLint):

- `strict: true` turns warnings into failures.
- `opt_in_rules` enables rules outside the default set; `analyzer_rules` lists rules that only `swiftlint analyze` runs.
- `swiftlint analyze` needs `--compiler-log-path` from a clean `xcodebuild` log.
- Regex `custom_rules` support `included`/`excluded` path regexes, `match_kinds`, `message` and `severity`. Swift-syntax custom rules require building SwiftLint with Bazel.
- Rule identifiers below were checked against the repo's rule sources.

The configuration below is a menu to pick from as rules are needed, not something to adopt in one go.

```yaml
strict: true
opt_in_rules:
  - force_unwrapping
  - implicitly_unwrapped_optional
  - fatal_error_message
  - discouraged_optional_boolean
  - unhandled_throwing_task
  - unowned_variable_capture
  - private_swiftui_state
  - async_without_await
  - redundant_sendable
  - no_empty_block
  - accessibility_label_for_image
  - accessibility_trait_for_button
analyzer_rules:
  - unused_declaration
  - unused_import
  - typesafe_array_init
  - capture_variable
force_try: error
force_cast: error
custom_rules:
  no_print:
    regex: '\bprint\('
    message: "Use Logger (os) with the app subsystem"
    severity: error
  no_dispatch_queue:
    regex: '\bDispatchQueue\b'
    message: "Use structured concurrency (async/await, actors)"
    severity: error
  no_unchecked_sendable:
    regex: '@unchecked\s+Sendable|nonisolated\(unsafe\)'
    message: "Fix the isolation instead of opting out"
    severity: error
  no_raw_date:
    regex: '\bDate\(\)'
    message: "Pass the time in so tests control it"
    severity: error
  grdb_only_in_store:
    regex: '^import GRDB'
    excluded: ['.*/NoteStore/.*']
    message: "Only NoteStore talks to SQLite"
    severity: error
```

**Formatter.** Use swift-format: it ships in the Xcode toolchain (`xcrun swift-format`, checked locally), so there is nothing extra to install. Use `swift-format lint --strict` in `make check`, and `swift-format format -i` in `make fmt`. SwiftFormat (nicklockwood) has more rules but adds a dependency; pick one, not both.

**Dead code.** Periphery `scan` with `--strict` exits non-zero when it finds unused code (the `strict` flag is in [ScanCommand.swift](https://github.com/peripheryapp/periphery/blob/master/Sources/Frontend/Commands/ScanCommand.swift)). Use `--skip-build --index-store-path <DerivedData>/Index.noindex/DataStore` to reuse the `make` build. ([README](https://github.com/peripheryapp/periphery))

#### Harness: `make check`, pre-commit, CI, CLAUDE.md

Per the owner, Claude Code hooks are out of scope.

- **`make check`** is the one command an agent runs and CI runs. It is ordered fastest first and fails on the first error: format check, text checks, `swift test` for `NoteCore` and `NoteStore`, then the Xcode build and tests. `make e2e` is separate and slower.
- **Pre-commit.** The smallest option is a checked-in `.githooks/pre-commit` that runs `make check-fast` (format and text checks on staged files), activated by `git config core.hooksPath .githooks` in `make setup`. [lefthook](https://github.com/evilmartians/lefthook) v2.2.2 (`lefthook.yml` with `pre-commit.jobs[]` using `glob`, `run`, `stage_fixed`) is worth it only if hooks get slow and need parallelism ([config docs](https://lefthook.dev/configuration/)). Pre-commit is a convenience; agents and humans can skip it with `--no-verify`, so CI decides.
- **CI (GitHub Actions).**
  - The `macos-26` image has Xcode 26.x only. Xcode 27 runs on the preview label `runs-on: xcode-27` ([runner-images #14404](https://github.com/actions/runner-images/issues/14404)).
  - macOS minutes are billed at $0.062/min against the 2,000 free minutes for private repos; public repos are free ([billing docs](https://docs.github.com/en/billing/concepts/product-billing/github-actions)). Keep iOS CI to `make check` plus a small e2e smoke run.
- **CLAUDE.md** states the contract in a few lines: run `make check` before saying done, run `make e2e` for behavior changes, never add `// swiftlint:disable` without a reason, and when a mistake repeats, add a rule. By poteto's ranking this file is the weakest layer, so keep it short and let the tools enforce.

---

## 3. Letting an agent test the whole app

With no server, "the whole system" is the app in the Simulator and its SQLite file. An agent should be able to start it in a known state with one command, drive it many ways, and check outcomes from several sides.

### 3.1 One command to a running app

`make sim-up` should do the following, in order, and be safe to run twice:

1. **Build the app in an `E2E` configuration** (XcodeGen `configs:`), which sets the compilation condition `E2E`. Code under that condition reads test launch arguments. Release builds can't contain the test hooks.
2. **Create or reuse a dedicated simulator** (`xcrun simctl create Note-E2E ...`), boot it, `erase` it if asked for a clean run, and `install` the `.app`.
3. **Launch the app with test arguments**, for example:
   - reset local storage;
   - load a named fixture: notes in every state (draft, saved, untitled, in each drawer, trashed 29 and 31 days ago) and drawers in a set order;
   - shift the clock, for the 5-minute draft reopen and the 30-day trash;
   - turn off animations.
4. **Write `build/e2e/state.json`** with the simulator UDID, the app bundle ID, the app's data folder (`simctl get_app_container <udid> com.rontho14.note data`), the database path inside it and the log command. Every later script and every agent reads this file instead of guessing.

The commands used are all in `xcrun simctl help` on Xcode 27.1: `create`, `boot`, `erase`, `install`, `launch`, `terminate`, `get_app_container`, `io ... screenshot`, `openurl`, `privacy`, `status_bar`, `spawn`.

Companion targets:
- `make sim-reset`: wipe storage, load the fixture again, relaunch.
- `make sim-down`: shut the simulator down.
- `make sim-logs`: stream the app's logs.
- `make e2e-invariants`: the checks in 3.4.
- `make e2e`: up, run all scenarios, invariants, down.

**Logging.** The app logs through `os.Logger` with subsystem `com.rontho14.note`, so `xcrun simctl spawn <udid> log stream --predicate 'subsystem == "com.rontho14.note"'` captures them. Note text is never logged.

Give every interactive element a stable `.accessibilityIdentifier`. Every driver below depends on it: XCUITest, Maestro, e2e, agent-device and AXe.

### 3.2 Ways an agent drives the running app

**A. Exploratory, by the agent directly (no test code)**

| Tool | What it gives | Notes |
|---|---|---|
| Claude Code Desktop [iOS Simulator pane](https://code.claude.com/docs/en/desktop-ios-simulator) | Built in. Claude builds with `xcodebuild`, installs, launches, taps, types, and reads the screen while you watch. Each session gets its own simulators (up to 4). | Public beta, macOS, Pro/Max/Team/Enterprise, Claude Desktop v1.24012.0+, Xcode 26.x or 27. Simulators only. Screenshots go to Anthropic. Building and `openurl` follow the session's permission mode. |
| Claude Code CLI [computer use](https://code.claude.com/docs/en/computer-use) | Drives the Simulator window like a mouse. | Research preview, Pro/Max, interactive sessions only (not `-p`). Slowest option; Claude prefers an MCP server when one exists. |
| [MobileBuildMCP](https://github.com/getsentry/XcodeBuildMCP) (formerly XcodeBuildMCP, Sentry, v2.7.1) | MCP server and CLI: `build_run_sim`, test, logs, and UI automation through the bundled AXe helper: `snapshot_ui` returns an accessibility tree with element refs, then `tap`, `swipe`, `type_text`, `batch`. | `npx -y mobilebuildmcp@latest mcp`. macOS 14.5+, Xcode 16+. Only device tools need signing. Sends error telemetry to Sentry (opt-out documented). See the [UI automation docs](https://github.com/getsentry/xcodebuildmcp.com/blob/main/app/docs/_content/architecture-ui-automation.mdx). |
| [ios-simulator-mcp](https://github.com/joshuayoes/ios-simulator-mcp) (v2.2.0) | `ui_describe_all`, `ui_tap`, `ui_type`, `ui_swipe`, `screenshot`, `record_video`, `install_app`, `launch_app`, `open_url`. | Uses Meta's idb (`idb_companion`). Mentioned in Anthropic's [Claude Code best practices](https://www.anthropic.com/engineering/claude-code-best-practices). |
| [agent-device](https://github.com/callstackincubator/agent-device) (Callstack, v0.21.33) | CLI, MCP and Node API for agents: accessibility snapshots, deterministic taps, typing, simulator settings. It is e2e's mobile engine. | `npm i -g agent-device`. Simulator needs no signing. |
| Maestro MCP | `maestro mcp` exposes `list_devices`, `inspect_screen`, `take_screenshot`, `run` (flows). | Needs Java. Cloud tools need a login; local ones don't. ([docs](https://docs.maestro.dev/getting-started/maestro-mcp)) |
| `xcrun simctl` | Lifecycle, screenshots, URLs, permissions, logs, app container path. | Always available, so scripts should use it as the base layer. |

Pick one simulator MCP to avoid overlapping tools. In Claude Code Desktop, the built-in pane covers exploration. In the CLI, MobileBuildMCP is the most complete (build, test, logs, UI tree in one server).

**B. Repeatable scenarios (committed code)**

- **XCUITest via `xcodebuild test`.** This is the recommended main scripted driver. It is Apple-native, typed Swift (so the compiler and the checks apply), needs no signing on the Simulator, and runs in CI. Each test launches the app with the test arguments from 3.1, so it controls the fixture and the clock. Use `-only-testing:` so an agent can run one scenario. Swift Testing is used for unit tests; whether it can host `XCUIApplication` UI tests in Xcode 27 is **unverified**, so assume UI tests stay on XCTest.
- **Maestro flows** (optional). YAML is easy for an agent to write and read. `launchApp` supports iOS `arguments`, `clearState` and `clearKeychain` ([docs](https://docs.maestro.dev/api-reference/commands/launchapp)). Adds a Java dependency.
- **TesterArmy e2e** (optional, agentic layer). Natural-language steps such as "write a shopping list, save it into Home, and check it is listed there", paired with deterministic `getByTestId` checks. Point `app.appPath` at `build/DerivedData/Build/Products/E2E-iphonesimulator/Note.app`. Good for coverage of fuzzy flows (the swipes between screens, the flick into view mode) without writing locators for every step. Agent steps need a model key.

### 3.3 Scenario catalog

Each scenario is a short test that uses the launch arguments from 3.1. They come from VISION.md and the ADRs:

1. **Capture.** Launch, then confirm the keyboard is up and typing works. Leave an empty note and confirm nothing is saved.
2. **Draft reopen.** Type, leave the app, relaunch within 5 minutes: the draft is back with the cursor in place. Shift the clock 6 minutes and relaunch: a blank note.
3. **Save with the modal.** Flick to save a new note: the modal appears. Save with nothing filled in: the note is untitled in `Unsorted`. Save another with a title and a drawer: both are stored. A note that has been saved once saves with no modal, even when it is untitled.
4. **Delete from the modal.** The note goes to the trash and leaves the list.
5. **View mode.** Flick into view mode on a fixture note: headings, labels and lists are formatted, and dates and phone numbers are tappable. Correct a line by holding it; the correction persists after a relaunch.
6. **Text is never changed.** For every scenario above, the stored text equals the typed text byte for byte.
7. **Drawers.** Open a drawer in place, close it, and reorder drawers by dragging. The new order survives a relaunch and is the chip order in the save modal.
8. **Trash.** Drag a note to the trash button. Open the trash sheet and restore it. Shift the clock 31 days: a note trashed 31 days ago is gone, and one trashed 29 days ago is still there.
9. **Search.** Partial words, accented words and one-letter typos find the right notes. Exact matches rank above typo matches. Tapping a result opens the note at the matching line.
10. **Themes.** Switch theme in settings: colors change and nothing else does.
11. **Export.** Export to a folder: one Markdown file per note, with the text unchanged.

### 3.4 How an agent verifies outcomes

- **Accessibility tree.** `snapshot_ui` (MobileBuildMCP), `ui_describe_all`, the agent-device snapshot, or XCUITest queries. Assert on identifiers and values, not pixels.
- **Screenshots.** `xcrun simctl io <udid> screenshot out.png`, the MCP screenshot tools, or the Desktop pane. For regression checks, [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing) (1.19.7) on SwiftUI views in unit tests, with a pinned simulator model and OS, gives deterministic images.
- **App database.** The database path from `state.json`, opened with `sqlite3` read-only.
- **Logs.** The app log from `log stream`. A scenario fails on any error it didn't expect.
- **Invariants (`make e2e-invariants`)**, run after every scenario:
  - every note's stored text matches what the scenario typed;
  - no empty note is stored;
  - every note is in exactly one drawer, or in `Unsorted`;
  - the FTS index has exactly one entry per note, with matching text;
  - no note sits in the trash for more than 30 days of app time.

A project-local verification skill, following poteto's [feature-map pattern](https://github.com/poteto/verification-skill-example), tells a fresh agent all of this. It has one short file per feature area (write, save, view, drawers, trash, search, export), each covering how to reach the feature, how to drive it, and what to check, plus a sweep order for "did I break anything".

### 3.5 Unit tests

[Swift Testing](https://developer.apple.com/xcode/swift-testing/) for `NoteCore` and `NoteStore`, using GRDB on an in-memory database (`DatabaseQueue()` in memory). These run as SwiftPM package tests with `swift test` on the Mac, fast and with no simulator. This is where the shape formatter and search ranking get their large test suites built from real notes.

### 3.6 Paid Apple account

None of the above needs the paid program:
- Simulator builds don't need signing (the Makefile already relies on this).
- XCUITest on the Simulator needs no team.
- MobileBuildMCP needs signing only for device tools.
- e2e and agent-device need a team ID only for physical iPhones.
- The Claude Desktop pane doesn't support physical devices at all.

Device testing stays manual through Xcode, with the 7-day free-profile limit noted in VISION.md.

---

## Proposed setup for this repo

Ordered smallest useful first. Each step leaves `make check` green. Checks are added when the code they protect exists, as ADR 0005 says.

1. **Tighten `ios/project.yml` settings.** Add `SWIFT_UPCOMING_FEATURE_EXISTENTIAL_ANY`, `..._MEMBER_IMPORT_VISIBILITY`, `..._INTERNAL_IMPORTS_BY_DEFAULT` and `SWIFT_APPROACHABLE_CONCURRENCY` (all `YES`), plus `SWIFT_DEFAULT_ACTOR_ISOLATION: MainActor` for UI code.
2. **Create the packages.** Add `NoteCore`, `NoteStore` and `NoteUI` as local Swift packages and reduce the app target to wiring, per ADR 0005. Add the three import checks as text searches.
3. **Add `make check`** that runs swift-format in lint mode, the text checks, `swift test` for `NoteCore` and `NoteStore`, and the Xcode build and tests. Add a short CLAUDE.md section: "done means `make check` passes; behavior changes also need `make e2e`; repeated mistakes become rules."
4. **Add accessibility identifiers and the first tests.** Add a `NoteUITests` target (XCUITest) to `project.yml`, with `make ios-test` running `xcodebuild test` on a named simulator. Adopt one `.accessibilityIdentifier` naming convention.
5. **Add `scripts/sim`.** It creates and boots the `Note-E2E` device, then installs, launches with test arguments, takes screenshots, prints the app container and streams logs. Expose it as `make sim-up`, `make sim-reset`, `make sim-down` and `make sim-logs`.
6. **Add the `E2E` build configuration** in XcodeGen: the `E2E` compilation condition and the launch arguments for reset, fixture, clock shift and animations.
7. **Set up pre-commit and CI.** `.githooks/pre-commit` runs `make check-fast`, and `make setup` sets `core.hooksPath`. `.github/workflows/check.yml` runs `make check` on `runs-on: xcode-27`.
8. **Build the scenario suite as features land.** The 3.3 catalog as XCUITest cases, plus `make e2e-invariants`. Expose it as `make e2e`, with a smoke subset in CI.
9. **Write a verification skill.** Add `skills/verify-note/` with a feature map (poteto's pattern) that tells a fresh agent how to bring the app up, drive each feature and check the evidence.
10. **Add rules as they are needed.** The candidates listed in ADR 0005, installing SwiftLint when the rules outgrow text searches.
11. **Optional, once the above works:**
    - try TesterArmy e2e for natural-language agentic scenarios, or Maestro flows, against the same `state.json`;
    - add Periphery `--strict` to `make check`;
    - add swift-snapshot-testing for key views;
    - add MobileBuildMCP for CLI sessions.
