# Agent guardrails and autonomous testing

> **Note, 2026-11-10.** This research predates the change to a local-only app with no backend and no AI ([VISION](../VISION.md)). The Swift, Simulator and `make check` parts still apply. The Go, server, KMS, MCP and AI-provider parts do not apply to the first iteration.

Research date: 2026-10-27. Versions were checked against GitHub releases on that date. Anything marked **unverified** could not be confirmed from a primary source.

## Summary

- **"e2e" is almost certainly [e2e by TesterArmy](https://e2e.tester.army/).** It is an open source (Apache-2.0) TypeScript test runner, launched on [2026-10-01](https://e2e.tester.army/blog/introducing-e2e), with 12k GitHub stars. It **does support native iOS apps in the Simulator**: the repo ships a [SwiftUI example](https://github.com/tester-army/e2e/tree/main/examples/with-swiftui) last checked with Xcode 27.1 on an iOS 26.5 simulator. It is pre-1.0, needs Node, and agent steps need a model key or subscription. It drives the app but does not boot the backend.
- **Make bad code impossible, in this order** (Lauren Tan's ranking, echoed by Matt Pocock): first, design types and modules so the mistake can't be expressed. Second, a lint rule or test that fails CI. Prose in CLAUDE.md comes last.
- **Go: the compiler already enforces module boundaries.** Use `internal/` packages and narrow interfaces (for example, the MCP layer gets a notes interface that has no hard-delete method). Add golangci-lint v2.15 with depguard (import boundaries), forbidigo (banned calls), gocritic/ruleguard (project rules), nilaway (module plugin), and gofumpt.
- **Swift: turn on the stricter compiler modes Xcode 27.1 already ships.** These are Swift 6 mode (already on), warnings as errors (already on), `ExistentialAny`, `MemberImportVisibility`, `InternalImportsByDefault`, approachable concurrency, and default MainActor isolation for the UI target. Split the app into local Swift packages so that, for example, only the store module can `import GRDB`. Add SwiftLint 0.65 with `strict: true`, force unwrapping/`try!` banned, and custom regex rules. Format with swift-format, which ships in the Xcode toolchain.
- **One entry point: `make check`.** It runs format check, lint, build and tests. A plain git pre-commit hook runs the fast part, and GitHub Actions runs everything. CI is the real gate, because `git commit --no-verify` skips local hooks.
- **The top testing priority is a whole-system test mode.** `make e2e-up` starts the Go server built with an `e2e` build tag, using a temp SQLite file, seeded fixtures, a fake AI provider, a fake KMS, a controllable clock and a `/_test` control API. It builds the iOS app in an `E2E` configuration, boots a dedicated simulator, installs the app and launches it pointed at the local server. It then writes one `e2e/state.json` with every URL, UDID, DB path and log path an agent needs.
- **Agents drive the running system several ways.** Claude Code Desktop's built-in [iOS Simulator pane](https://code.claude.com/docs/en/desktop-ios-simulator) or MobileBuildMCP (formerly XcodeBuildMCP) work for exploration. `xcrun simctl` scripts control the simulator. A committed XCUITest suite gives repeatable UI scenarios. For MCP, Claude Code can connect to the local server as a client, the MCP Inspector CLI can script calls, and Go SDK client tests cover the rest. Maestro or TesterArmy's e2e are optional extra drivers.
- **Agents verify outcomes from several sides.** On the app side: the accessibility tree, screenshots, and the app's own SQLite file (`xcrun simctl get_app_container`). On the server side: the server's SQLite file, structured logs, and a `make e2e-invariants` command. That command checks revision chains, trash rules, and that no seeded plaintext canary appears in the database or backups.
- **Nothing here needs the paid Apple Developer Program.** Simulator builds, XCUITest, simctl, Maestro, e2e and the MCP simulator tools all work without signing. Only physical-device automation needs a team ID.

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

**Fit for this repo.** e2e is a good candidate for the agentic and natural-language layer: "finish a note and check it lands in a drawer", with a deterministic check alongside. Three limits: it adds a Node toolchain to a Swift and Go repo, it is pre-1.0, and it only drives the app. The backend test mode in section 3 is still needed underneath it.

### Other candidates considered

| Product | What it is | Native iOS in Simulator? |
|---|---|---|
| [Maestro](https://github.com/mobile-dev-inc/Maestro) (CLI 2.12.0, 2026-10-26) | YAML flows for mobile and web. Has a built-in MCP server (`maestro mcp`). The AI commands `assertWithAI` and `assertNoDefectsWithAI` are experimental and routed through Maestro Cloud. | **Yes.** Runs on "any iOS Simulator managed by Xcode", including SwiftUI apps. ([iOS docs](https://docs.maestro.dev/get-started/supported-platform/ios), [MCP docs](https://docs.maestro.dev/getting-started/maestro-mcp), [assertWithAI](https://docs.maestro.dev/reference/commands-available/assertwithai), [AI configuration](https://docs.maestro.dev/api-reference/configuration/ai-configuration)) |
| [Playwright Test Agents](https://playwright.dev/docs/test-agents) | Planner, generator and healer agents for Playwright tests (`npx playwright init-agents`). | **No.** Browsers only; iOS means mobile Safari emulation. |
| [Shortest](https://github.com/antiwork/shortest) (antiwork) | Natural-language tests "built on Playwright". | **No.** Web only. |
| [Momentic](https://momentic.ai/blog/mobile) | Commercial AI testing platform that added mobile. | **Yes, beta.** Native Swift apps on hosted iOS 26 simulators from a simulator `.app`. ([iOS quickstart](https://momentic.ai/docs/quickstart/ios)) |
| [QA Wolf](https://www.qawolf.com/solutions/ios-testing) | Managed QA service using Appium. | Real iPhones on their device farm, not your Simulator. It is a service, not a framework. |
| Octomind | AI test generation. | No mobile support found. **Unverified.** |

**Conclusion.** The owner's description matches TesterArmy's e2e: a new framework, literally named "e2e", launched about four weeks ago. I'm confident this is the one, but I can't confirm it is what the owner saw. If they meant something else, Maestro is the strongest established alternative with iOS Simulator support.

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
| Agents never hard-delete (ADR 0003) | The MCP package receives a `notes.AgentService` interface that has `Trash`, not `Delete`. Hard delete lives in a separate `internal/purge` package that only the 30-day job imports, enforced by depguard. |
| Every write is a revision (ADR 0003) | Only `internal/notes` can import `internal/store`. `store` exposes no "update note text" except `AppendRevision(base RevisionID, ...)`. |
| Plaintext never reaches the DB (ADR 0002) | Note content columns accept only a `crypt.Ciphertext` type. Its fields are unexported, so only the `crypt` package can construct one. |
| Every record has `user_id` | Store methods take a `UserScope` value, not a raw ID, and queries are built from it. |
| Time-based rules (5-minute draft, 30-day trash) | Inject a `Clock` interface. Ban `time.Now` and `Date()` elsewhere (layer 2). |
| iOS: only the store touches SQLite | GRDB is a dependency of the `NoteStore` Swift package only, so other modules can't `import GRDB` because it isn't in their dependency graph. |

Go's [`internal/` directory rule](https://go.dev/doc/go1.4#internalpackages) is the built-in version of Matt's dependency-cruiser setup: the compiler rejects imports of `a/internal/x` from outside `a/`. Swift packages give the same thing, plus the `package` access level ([SE-0386](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0386-package-access-modifier.md)).

#### Go (layer 2)

Current versions: golangci-lint [v2.15.0](https://github.com/golangci/golangci-lint/releases) (2026-10-16), staticcheck [2026.2.2](https://github.com/dominikh/go-tools/releases), gofumpt [v0.12.0](https://github.com/mvdan/gofumpt/releases), Go 1.27.3.

- **golangci-lint v2 config** uses `version: "2"`. `linters.default` is one of `standard`, `all`, `none` or `fast`. Linters go in `linters.enable` and their settings in `linters.settings`; formatters have their own `formatters.enable` list. Available formatters: gci, gofmt, gofumpt, goimports, golines, swaggo. ([config file docs](https://golangci-lint.run/docs/configuration/file/), [formatters](https://golangci-lint.run/docs/formatters/))
- **Linters confirmed in v2:** depguard, forbidigo, gocritic (with ruleguard), exhaustive, errcheck, wrapcheck, errorlint, nilnil, staticcheck, govet, gosec, revive, sqlclosecheck, rowserrcheck, contextcheck, noctx, nolintlint, forcetypeassert, err113, modernize, usetesting, testifylint, paralleltest. `exhaustruct` and `wsl` are deprecated in favor of `exhaustruct_v5` and `wsl_v5`. ([linters](https://golangci-lint.run/docs/linters/))
- **nilaway** is not built in. It runs through golangci-lint's module plugin system: a `.custom-gcl.yml` names `go.uber.org/nilaway/cmd/gclplugin`, `golangci-lint custom` builds `./custom-gcl`, and the linter is configured as `linters.settings.custom.nilaway.type: module` with `include-pkgs`. ([nilaway README](https://github.com/uber-go/nilaway), [module plugins](https://golangci-lint.run/docs/plugins/module-plugins/))
- **Custom rules:**
  - Simplest: forbidigo patterns with a message. ([settings](https://golangci-lint.run/docs/linters/configuration/))
  - Next: gocritic `ruleguard` with `rules: '${base-path}/ruleguard/rules-*.go'` and `failOn: dsl,import`, which gives AST pattern rules written in Go. ([settings](https://golangci-lint.run/docs/linters/configuration/), [go-ruleguard](https://github.com/quasilyte/go-ruleguard))
  - Heaviest: a full `go/analysis` analyzer loaded as a module plugin ([example plugin](https://github.com/golangci/example-plugin-module-linter)).
- **Outside golangci-lint**, `make check` should also run:
  - `go vet ./...`
  - `go test -race -shuffle=on ./...`
  - `govulncheck ./...` ([golang.org/x/vuln](https://pkg.go.dev/golang.org/x/vuln/cmd/govulncheck))
  - a short fuzz budget on parsers: `go test -fuzz=Fuzz... -fuzztime=10s` ([Go fuzzing](https://go.dev/doc/security/fuzz/))

Sketch `.golangci.yml`. Settings keys follow the docs above; the module path is a placeholder.

```yaml
version: "2"
linters:
  default: standard            # errcheck, govet, ineffassign, staticcheck, unused
  enable:
    - bodyclose
    - contextcheck
    - depguard
    - errorlint
    - exhaustive
    - forbidigo
    - forcetypeassert
    - gocritic
    - gosec
    - nilerr
    - nilnil
    - noctx
    - nolintlint
    - rowserrcheck
    - sqlclosecheck
    - wrapcheck
    - modernize
    - usetesting
    - nilaway                  # module plugin, needs ./custom-gcl
  settings:
    errcheck:
      check-type-assertions: true
      check-blank: true
    govet:
      enable-all: true
    nolintlint:
      require-explanation: true
      require-specific: true
    depguard:
      rules:
        drivers:
          deny:
            - pkg: github.com/mattn/go-sqlite3
              desc: use modernc.org/sqlite (ADR 0001, no cgo)
            - pkg: math/rand$
              desc: use crypto/rand or math/rand/v2
        mcp-through-notes:
          files: ["**/internal/mcp/**"]
          deny:
            - pkg: example.com/note/internal/store
              desc: MCP writes must go through internal/notes so every edit is a revision (ADR 0003)
            - pkg: example.com/note/internal/purge
              desc: agents never hard-delete (ADR 0003)
        no-fakes-in-prod:
          files: ["!$test", "!**/testmode_e2e.go"]
          deny:
            - pkg: example.com/note/internal/testkit
              desc: fakes are only wired in under the e2e build tag
    forbidigo:
      analyze-types: true
      forbid:
        - pattern: ^time\.Now$
          msg: inject clock.Clock so tests can control time
        - pattern: ^fmt\.Print.*$
          msg: use log/slog
        - pattern: ^log\.(Print|Fatal|Panic).*$
          msg: use log/slog
        - pattern: ^os\.Getenv$
          msg: read configuration only in internal/config
    gocritic:
      enabled-checks: [ruleguard]
      settings:
        ruleguard:
          rules: '${base-path}/tools/ruleguard/rules-*.go'
          failOn: dsl,import
    custom:
      nilaway:
        type: module
        settings:
          include-pkgs: example.com/note
formatters:
  enable: [gofumpt, goimports]
```

Use `linters.exclusions.rules` to exempt `internal/config` from the `os.Getenv` ban.

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
| `SWIFT_APPROACHABLE_CONCURRENCY: YES`, `SWIFT_DEFAULT_ACTOR_ISOLATION: MainActor` (UI target only) | Nonisolated async functions run on the caller's actor ([SE-0461](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0461-async-function-isolation.md)), and UI code is MainActor by default ([SE-0466](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0466-control-default-actor-isolation.md)). Keep the store and sync packages nonisolated. |
| `SWIFT_STRICT_MEMORY_SAFETY: YES` (optional) | Flags unsafe constructs in your own code ([SE-0458](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0458-strict-memory-safety.md)). Try it, and keep it if it isn't noisy. |

**Module boundaries.** Move code into local Swift packages, for example `NoteCore` (models, pure logic), `NoteStore` (GRDB), `NoteSync` (HTTP client) and `NoteUI`. Keep the app target as a thin shell. Each `Package.swift` lists allowed dependencies, so a forbidden import is a compile error. XcodeGen references local packages through its `packages:` key.

**SwiftLint.** Settings below are from the [README](https://github.com/realm/SwiftLint):

- `strict: true` turns warnings into failures.
- `opt_in_rules` enables rules outside the default set; `analyzer_rules` lists rules that only `swiftlint analyze` runs.
- `swiftlint analyze` needs `--compiler-log-path` from a clean `xcodebuild` log.
- Regex `custom_rules` support `included`/`excluded` path regexes, `match_kinds`, `message` and `severity`. Swift-syntax custom rules require building SwiftLint with Bazel.
- Rule identifiers below were checked against the repo's rule sources.

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
    message: "Inject Clock so tests control time"
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

- **`make check`** is the one command an agent runs and CI runs. It is ordered fastest first and fails on the first error: format check, lint (both languages), build, unit tests, then `golangci-lint`/`govulncheck` once Go exists. `make e2e` is separate and slower.
- **Pre-commit.** The smallest option is a checked-in `.githooks/pre-commit` that runs `make check-fast` (format and lint on staged files), activated by `git config core.hooksPath .githooks` in `make setup`. [lefthook](https://github.com/evilmartians/lefthook) v2.2.2 (`lefthook.yml` with `pre-commit.jobs[]` using `glob`, `run`, `stage_fixed`) is worth it only if hooks get slow and need parallelism ([config docs](https://lefthook.dev/configuration/)). Pre-commit is a convenience; agents and humans can skip it with `--no-verify`, so CI decides.
- **CI (GitHub Actions).**
  - The `macos-26` image has Xcode 26.x only. Xcode 27 runs on the preview label `runs-on: xcode-27` ([runner-images #14404](https://github.com/actions/runner-images/issues/14404)).
  - Run Go jobs on `ubuntu-latest`.
  - macOS minutes are billed at $0.062/min against the 2,000 free minutes for private repos; public repos are free ([billing docs](https://docs.github.com/en/billing/concepts/product-billing/github-actions)). Keep iOS CI to `make check` plus a small e2e smoke run.
- **CLAUDE.md** states the contract in a few lines: run `make check` before saying done, run `make e2e` for behavior changes, never add `// swiftlint:disable` or `//nolint` without a reason (nolintlint enforces this in Go), and when a mistake repeats, add a rule. By poteto's ranking this file is the weakest layer, so keep it short and let the tools enforce.

---

## 3. Letting an agent test the whole app, integrated

The priority is the whole system: the iOS app in the Simulator, a real local Go server with its SQLite database, the AI job queue (fake or real provider), and the MCP endpoint. An agent should be able to start it with one command, drive it many ways, and check outcomes from several sides.

### 3.1 One command to a running test system

`make e2e-up` should do the following, in order, and be idempotent:

1. **Build the server with `-tags e2e`** and start it on `127.0.0.1:<port>` with:
   - a fresh SQLite file under `build/e2e/<run-id>/server.db`;
   - the fake AI provider, the fake KMS, and a controllable clock;
   - JSON `slog` output to `build/e2e/<run-id>/server.log`.
   Litestream can replicate to a local `file` replica in the same directory, so restores can be tested too (**unverified** that the file replica type is still supported in the current Litestream release).
2. **Seed fixtures**: users, drawers, tags, notes in every state (draft, finished, in a closed drawer, trashed 29 and 31 days ago), and agent OAuth grants. Seed content includes a unique canary string per note.
3. **Build the app in an `E2E` configuration** (XcodeGen `configs:`), which sets the compilation condition `E2E`, adds `NSAllowsLocalNetworking` to that configuration's Info.plist only, and reads the server URL from launch arguments or the environment. Release builds can't contain the test hooks.
4. **Create or reuse a dedicated simulator** (`xcrun simctl create Note-E2E ...`), boot it, `erase` it if asked for a clean run, `install` the `.app`, and `launch` it with environment such as `NOTE_SERVER_URL`. Grant permissions with `simctl privacy`.
5. **Write `build/e2e/state.json`** with the server URL, MCP URL, a pre-minted agent token, the simulator UDID, the app bundle ID, the app container path (`simctl get_app_container <udid> com.rontho14.note data`), the server DB path and the log paths. Every later script and every agent reads this file instead of guessing.

The commands used are all in `xcrun simctl help` on Xcode 27.1: `create`, `boot`, `erase`, `install`, `launch`, `terminate`, `get_app_container`, `io ... screenshot`, `openurl`, `privacy`, `status_bar`, `spawn`, `location`, `push`.

Companion targets:
- `make e2e-reset`: wipe the DB, re-seed, relaunch the app.
- `make e2e-down`: stop everything.
- `make e2e-logs`: tail server and app logs.
- `make e2e-invariants`: the checks in 3.4.
- `make e2e`: up, run all scenarios, invariants, down.

**Server test mode, guarded by the build tag.** Under `//go:build e2e`, the server registers a `/_test` API: `reset`, `seed?fixture=`, `clock/advance?d=`, `ai/mode?m=ok|slow|error|drop-content|offline`, `kms/mode`, `jobs/drain`, `state` (a decrypted JSON dump for assertions), and `token?agent=` (mints an agent token without the OAuth dance). The production binary is built without the tag. A test asserts `/_test/*` returns 404 in a default build, and the depguard rule above keeps fakes out of non-e2e code.

**Fake AI provider.** It runs deterministically: wraps text in simple Markdown, derives a title from the first words, files the note by keyword, and picks tags by keyword. Its modes inject failures, so the VISION rules become testable:
- `drop-content` returns output missing a word, and the rewrite must be rejected;
- `offline` must leave the rewrite queued;
- `slow` exercises timeouts.

A `real` mode with the OpenAI key can be used by hand for smoke runs.

**Fake KMS.** An in-process key-wrapping implementation behind the same interface as the real KMS. It counts unwrap calls, so tests can check caching and audit behavior. A `fail` mode tests the KMS-down path.

**App test hooks (E2E config only).** These are:
- launch arguments to reset local storage;
- a fixed clock offset, for the 5-minute draft reopen;
- turning off animations;
- `os.Logger` with subsystem `com.rontho14.note`, so `xcrun simctl spawn <udid> log stream --predicate 'subsystem == "com.rontho14.note"'` captures app logs.

Give every interactive element a stable `.accessibilityIdentifier`. Every driver below depends on it: XCUITest, Maestro, e2e, agent-device and AXe.

### 3.2 Ways an agent drives the running system

**A. Exploratory, by the agent directly (no test code)**

| Tool | What it gives | Notes |
|---|---|---|
| Claude Code Desktop [iOS Simulator pane](https://code.claude.com/docs/en/desktop-ios-simulator) | Built in. Claude builds with `xcodebuild`, installs, launches, taps, types, and reads the screen while you watch. Each session gets its own simulators (up to 4). | Public beta, macOS, Pro/Max/Team/Enterprise, Claude Desktop v1.24012.0+, Xcode 26.x or 27. Simulators only. Screenshots go to Anthropic. Building and `openurl` follow the session's permission mode. |
| Claude Code CLI [computer use](https://code.claude.com/docs/en/computer-use) | Drives the Simulator window like a mouse. | Research preview, Pro/Max, interactive sessions only (not `-p`). Slowest option; Claude prefers an MCP server when one exists. |
| [MobileBuildMCP](https://github.com/getsentry/XcodeBuildMCP) (formerly XcodeBuildMCP, Sentry, v2.7.1) | MCP server and CLI: `build_run_sim`, test, logs, and UI automation through the bundled AXe helper: `snapshot_ui` returns an accessibility tree with element refs, then `tap`, `swipe`, `type_text`, `batch`. | `npx -y mobilebuildmcp@latest mcp`. macOS 14.5+, Xcode 16+. Only device tools need signing. Sends error telemetry to Sentry (opt-out documented). See the [UI automation docs](https://github.com/getsentry/xcodebuildmcp.com/blob/main/app/docs/_content/architecture-ui-automation.mdx). |
| [ios-simulator-mcp](https://github.com/joshuayoes/ios-simulator-mcp) (v2.2.0) | `ui_describe_all`, `ui_tap`, `ui_type`, `ui_swipe`, `screenshot`, `record_video`, `install_app`, `launch_app`, `open_url`. | Uses Meta's idb (`idb_companion`). Mentioned in Anthropic's [Claude Code best practices](https://www.anthropic.com/engineering/claude-code-best-practices). |
| [agent-device](https://github.com/callstackincubator/agent-device) (Callstack, v0.21.33) | CLI, MCP and Node API for agents: accessibility snapshots, deterministic taps, typing, simulator settings. It is e2e's mobile engine. | `npm i -g agent-device`. Simulator needs no signing. |
| Maestro MCP | `maestro mcp` exposes `list_devices`, `inspect_screen`, `take_screenshot`, `run` (flows). | Needs Java. Cloud tools need a login; local ones don't. ([docs](https://docs.maestro.dev/getting-started/maestro-mcp)) |
| `xcrun simctl` | Lifecycle, screenshots, URLs, permissions, location, logs, app container path. | Always available, so scripts should use it as the base layer. |

Pick one simulator MCP to avoid overlapping tools. In Claude Code Desktop, the built-in pane covers exploration. In the CLI, MobileBuildMCP is the most complete (build, test, logs, UI tree in one server).

**B. Repeatable scenarios (committed code)**

- **XCUITest via `xcodebuild test`.** This is the recommended main scripted driver. It is Apple-native, typed Swift (so SwiftLint and the compiler apply), needs no signing on the Simulator, and runs in CI. The UI test target can call the server's `/_test` API over URLSession to seed, advance the clock, switch AI modes and read state, so one test can span app and server. Use `-only-testing:` so an agent can run one scenario. Swift Testing is used for unit tests; whether it can host `XCUIApplication` UI tests in Xcode 27 is **unverified**, so assume UI tests stay on XCTest.
- **Maestro flows** (optional). YAML is easy for an agent to write and read. `launchApp` supports iOS `arguments`, `clearState` and `clearKeychain` ([docs](https://docs.maestro.dev/api-reference/commands/launchapp)). Calling the `/_test` API from a flow's `runScript` relies on Maestro's JavaScript HTTP support (**unverified** on the current docs page). Adds a Java dependency.
- **TesterArmy e2e** (optional, agentic layer). Natural-language steps such as "write a shopping list, finish it, and check it is filed in Home", paired with deterministic `getByTestId` checks. Point `app.appPath` at `build/DerivedData/Build/Products/E2E-iphonesimulator/Note.app`. Good for coverage of fuzzy flows (gestures, the swipe into view mode) without writing locators for every step. Agent steps need a model key.

**C. MCP side (agents as the system's users)**

- **Claude Code as a real MCP client.** `claude mcp add --transport http note-local <MCP URL from state.json>` with the minted token as a header. The agent then reads, creates, edits and trashes notes exactly as a production agent would, and checks the result in the app UI.
- **MCP Inspector CLI** ([v2.12.0](https://github.com/modelcontextprotocol/inspector)) for scripted calls, for example `npx @modelcontextprotocol/inspector --cli http://127.0.0.1:8080/mcp --method tools/call --tool-name create_note --tool-arg text=... --header "Authorization: Bearer ..."`. URLs ending in `/mcp` default to streamable HTTP. It also supports OAuth from a config file, which can exercise the real OAuth flow once. ([CLI README](https://github.com/modelcontextprotocol/inspector/blob/main/clients/cli/README.md))
- **Go SDK client tests** ([go-sdk v1.8.0](https://github.com/modelcontextprotocol/go-sdk)). For fast in-process tests, `mcp.NewInMemoryTransports()` connects a client and server without HTTP. For the e2e run, the streamable HTTP client points at the live server. The SDK also ships `auth` and `oauthex` packages for the OAuth side.

**D. Sync API.** curl, or a checked-in `.http`/script file, against the sync endpoints using the same token, to simulate a second device or a stale client.

### 3.3 Scenario catalog: "in many different ways"

Each scenario is a short script or test that uses `state.json`. These come straight from VISION.md and the ADRs:

1. **Capture.** Launch, then confirm the keyboard is up, typing works, and an empty note isn't saved. Relaunch within 5 minutes to get the draft back with the cursor in place. Advance the clock 6 minutes and relaunch to get a blank note.
2. **Finish with the AI healthy.** Swipe into view mode, run `jobs/drain`, then check the Markdown, title, drawer, tags (hidden in the UI but present in `state`), and a revision holding the pre-rewrite text. Revert with one tap.
3. **Finish with the AI dropping content.** `ai/mode=drop-content`: the rewrite is rejected and the note is unchanged.
4. **Finish with the AI offline.** The note renders as typed and the rewrite is queued. Switch back to `ok`, drain, and the rewrite is applied.
5. **Re-finish.** No change means no AI call (count fake calls). An edited note gets a minimal rewrite, keeps its title, and keeps manual tags.
6. **Agent edits through MCP while the app is closed.** Open the app: it syncs, the edit appears, and the revision is attributed to that agent.
7. **Agent delete.** The note moves to trash and disappears from Latest. Advance the clock 31 days and run the purge: it's gone, and a note trashed for 29 days is still there.
8. **Agent tries forbidden actions.** Changing drawers, tags or settings, or hard-deleting, fails with a clear error, and the DB is unchanged.
9. **Grant revocation.** Revoke one agent's grant: its calls fail and another agent still works.
10. **Closed drawer.** Its notes leave the main views, an agent can still read them, and the AI stops filing into it.
11. **Offline phone.** Stop the server (or point at a dead port), edit on the phone, restart, reopen: the edit syncs. Every revision records its base revision.
12. **Conflict.** An agent edits through MCP while the phone edits offline. Both revisions exist, whatever the resolution strategy becomes.
13. **KMS failure.** `kms/mode=fail`: no plaintext is written, and the error is surfaced and logged.
14. **Restore.** Stop the server, `litestream restore` to a new path, start on it: `state` matches.

### 3.4 How an agent verifies outcomes

- **Accessibility tree.** `snapshot_ui` (MobileBuildMCP), `ui_describe_all`, the agent-device snapshot, or XCUITest queries. Assert on identifiers and values, not pixels.
- **Screenshots.** `xcrun simctl io <udid> screenshot out.png`, the MCP screenshot tools, or the Desktop pane. For regression checks, [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing) (1.19.7) on SwiftUI views in unit tests, with a pinned simulator model and OS, gives deterministic images.
- **App database.** `$(xcrun simctl get_app_container <udid> com.rontho14.note data)/…/notes.sqlite`, opened with `sqlite3` read-only. The agent can check that the phone's local copy matches the server.
- **Server database.** `sqlite3` on `server.db` for structure: revision chains, `user_id` on every row, trash timestamps. Use `/_test/state` for decrypted content.
- **Logs.** `server.log` (JSON, filterable with `jq`), and the app log from `log stream`. A scenario fails on any `level=ERROR` it didn't expect.
- **Invariants (`make e2e-invariants`)**, run after every scenario:
  - every revision's base exists;
  - no note has zero revisions;
  - no row lacks `user_id`;
  - no seeded canary string appears in `server.db`, its WAL, or the Litestream replica (`grep -c` must be 0), which checks ADR 0002 end to end;
  - agent-attributed revisions never come with a hard delete.

A project-local verification skill, following poteto's [feature-map pattern](https://github.com/poteto/verification-skill-example), tells a fresh agent all of this. It has one short file per feature area (capture, finish, drawers, MCP, sync), each covering how to reach the feature, how to drive it, and what to check, plus a sweep order for "did I break anything".

### 3.5 Secondary layers (still needed)

- **iOS unit tests.** [Swift Testing](https://developer.apple.com/xcode/swift-testing/) for `NoteCore` and `NoteStore`, using GRDB on an in-memory or temp-file database (`DatabaseQueue()` in memory). These run as SwiftPM package tests (fast, no simulator) or through the Xcode scheme.
- **Go unit and integration tests.**
  - [`net/http/httptest`](https://pkg.go.dev/net/http/httptest) for handlers.
  - Real SQLite files in `t.TempDir()`; testcontainers isn't needed, because SQLite is embedded.
  - [`testing/synctest`](https://pkg.go.dev/testing/synctest) for time-dependent job code.
  - Native fuzzing for the content-drop check, Markdown handling and sync payload parsing ([docs](https://go.dev/doc/security/fuzz/)).
  - Property tests with [rapid](https://github.com/flyingmutant/rapid) (`pgregory.net/rapid`), for example: for any input, a rewrite that passes the check contains every input word.
  - Golden files with an `-update` flag for MCP tool schemas and sync responses.
  - [testscript](https://pkg.go.dev/github.com/rogpeppe/go-internal/testscript) for CLI-level scenario scripts if the server gets admin commands.
  - [goleak](https://github.com/uber-go/goleak) for goroutine leaks.
- **MCP server tests.** In-memory transports for tool behavior, golden files for `tools/list` output, and the Inspector CLI in `make e2e`.

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

Ordered smallest useful first. Each step leaves `make check` green.

1. **Tighten `ios/project.yml` settings.** Add `SWIFT_UPCOMING_FEATURE_EXISTENTIAL_ANY`, `..._MEMBER_IMPORT_VISIBILITY`, `..._INTERNAL_IMPORTS_BY_DEFAULT` and `SWIFT_APPROACHABLE_CONCURRENCY` (all `YES`), plus `SWIFT_DEFAULT_ACTOR_ISOLATION: MainActor` on the app target.
2. **Add `.swift-format` and `.swiftlint.yml`** (the config in section 2), with `make fmt`, `make lint-ios` (`xcrun swift-format lint --strict -r ios` plus `swiftlint lint --strict`), and `brew install swiftlint` documented in README.
3. **Add `make check`** that runs `fmt-check`, `lint-ios`, `ios-build` and `ios-test`. Add a short CLAUDE.md section: "done means `make check` passes; behavior changes also need `make e2e`; repeated mistakes become rules."
4. **Add accessibility identifiers and the first tests.** Add a `NoteTests` target (Swift Testing) and a `NoteUITests` target (XCUITest) to `project.yml`, with `make ios-test` running `xcodebuild test` on a named simulator. Adopt one `.accessibilityIdentifier` naming convention.
5. **Add `scripts/sim`.** It creates and boots the `Note-E2E` device, then installs, launches with env, takes screenshots, prints the app container and streams logs. Expose it as `make sim-up`, `make sim-screenshot` and `make sim-logs`.
6. **Add an `E2E` build configuration** in XcodeGen: the `E2E` compilation condition, `NSAllowsLocalNetworking` only there, the server URL from launch env, a clock offset, and animations off.
7. **Set up pre-commit and CI.** `.githooks/pre-commit` runs `make check-fast`, and `make setup` sets `core.hooksPath`. `.github/workflows/check.yml` runs `make check` on `runs-on: xcode-27`.
8. **Split the iOS app into local Swift packages** when GRDB lands: `NoteCore`, `NoteStore` (the only one depending on GRDB), `NoteUI`, and the app shell. Add the `grdb_only_in_store` and `no_raw_date` rules.
9. **Bootstrap the Go server.**
   - Use an `internal/` layout (`notes`, `store`, `crypt`, `purge`, `mcp`, `ai`, `kms`, `clock`, `config`, `testkit`), with the type-level invariants from section 2's Layer 1 table.
   - Add `.golangci.yml`, `.custom-gcl.yml` (nilaway) and `tools/ruleguard/rules-*.go`.
   - Extend `make check` with `gofumpt` check, `golangci-lint run`, `go vet`, `go test -race -shuffle=on ./...` and `govulncheck`.
   - Add a Linux CI job.
10. **Add the server test mode.** `-tags e2e` builds the `/_test` API, the fake AI provider with failure modes, the fake KMS, the controllable clock and seeded fixtures with canary strings. Add a test asserting `/_test` is absent from the default build.
11. **Add `make e2e-up`, `e2e-reset`, `e2e-down`, `e2e-logs` and `build/e2e/state.json`**, which bring the integrated system up with one command.
12. **Add `make e2e-invariants`**: revision chains, `user_id`, trash rules, and canary-not-in-DB/WAL/replica.
13. **Set up MCP verification.**
    - Go SDK in-memory tests for each tool.
    - `scripts/mcp` wrapping the Inspector CLI with the token from `state.json`.
    - A documented `claude mcp add --transport http note-local ...` line, so an agent session can act as a real client.
14. **Build the scenario suite.** The section 3.3 catalog as XCUITest cases that call `/_test`, plus MCP scripts. Expose it as `make e2e`, with a smoke subset in CI.
15. **Write a verification skill.** Add `skills/verify-note/` with a feature map (poteto's pattern) that tells a fresh agent how to bring the system up, drive each feature and check the evidence.
16. **Optional, once the above works:**
    - try TesterArmy e2e for natural-language agentic scenarios, or Maestro flows, against the same `state.json`;
    - add Periphery `--strict` to `make check`;
    - add swift-snapshot-testing for key views;
    - add MobileBuildMCP for CLI sessions.
