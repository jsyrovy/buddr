# Buddr

Buddr is a small native macOS desktop buddy: a pixel-art sheep sitting in a corner of the screen that reacts to the
state of AI coding agents running in [herdr](https://herdr.dev). One character shows the aggregated state of all
agents. It is information only – it never focuses, attaches to, or sends anything to agents.

## Commands

```bash
make build    # xcodebuild Debug build into build/DerivedData
make test     # Swift Testing unit tests (hosted by the app)
make coverage # tests + line coverage report of the app target (result bundle build/Test.xcresult)
make run      # build, kill a running instance, open the app
make install  # Release build into ~/Applications (INSTALL_DIR=…), restart it; make uninstall removes it
make format   # xcrun swift-format, in place
make lint     # xcrun swift-format lint --strict
make clean    # rm -rf build
```

Run `make lint test` after every change. `CONFIG=Release make build` builds Release.

## Toolchain and project

- Xcode 27 / Swift 6.4, deployment target macOS 14, Swift 6 language mode (complete strict concurrency).
- `Buddr.xcodeproj` is hand-written (`objectVersion = 77`) with file-system synchronized root groups for `Buddr/` and
  `BuddrTests/`: new files are picked up automatically, do not add file references to `project.pbxproj`. Edit the
  pbxproj only for build settings / targets; keep object IDs in the `B0DD…` scheme.
- Shared scheme `Buddr` (`xcshareddata/xcschemes/Buddr.xcscheme`) so `xcodebuild -scheme Buddr` works.
- Bundle ID `cz.jsyrovy.buddr`, `LSUIElement = YES` (no Dock icon), generated Info.plist, App Sandbox off (the app
  runs `herdr`/`ssh`), no hardened runtime yet, ad-hoc signing ("Sign to Run Locally", no team).
- Nothing may be installed on the dev machine (no XcodeGen, SwiftLint, xcbeautify, …). Formatting is `swift-format`
  from the toolchain, configured in `.swift-format` (4 spaces, 120 columns).

## Structure

```
Buddr/
  App/        @main entry (BuddrMain → BuddrApp with MenuBarExtra, or an empty app under tests), AppDelegate
              wiring, RuntimeEnvironment
  Window/     SheepPanel (NSPanel), SheepPanelController (creation, placement), SheepView (root SwiftUI view),
              ScreenGeometry (screen choice, clamping), FullscreenDetector + FullscreenDebounce (pure) +
              FullscreenMonitor (notifications, polling), EscapeRoute (pure) + SheepEscape (runs off the screen and back)
  Sprite/     PixelSprite / SpriteFrame models, SpriteCanvas renderer, SheepSprites (all character data: palette,
              grids, frame composition, clip timing)
  Animation/  AnimationClip / SheepClipID, SheepAnimator (pure state machine), SheepAnimationDriver (@Observable
              timer that plays it), SplitMix64
  Herdr/      HerdrLocator (binary lookup), ProcessRunner (subprocess with timeout) + OneShotSignal, HerdrClient
              (typed CLI calls + parsing), HerdrModels (Decodable output shapes), HerdrStatusFetcher (one snapshot,
              sources queried concurrently), HerdrPoller (periodic loop on the main actor)
  State/      AgentStatus (+ priority aggregation), HerdrSnapshot / AgentRecord / HerdrSource / SourceFailure
BuddrTests/   Swift Testing tests, mirroring the app folders
  Fixtures/   herdr CLI JSON outputs
  Support/    fixture loader, FakeCommandRunner, ManualSleeper, AgentRecord.stub
```

## Conventions

- Everything in the repo (code, comments, docs, commit messages) is in English.
- No third-party dependencies. No image assets: all graphics are drawn in code from pixel grids.
- All sprite pixel data lives in one file (`SheepSprites.swift`) so the character can be swapped easily.
- Swift 6 strict concurrency: UI types are `@MainActor`; data crossing actors is `Sendable`. Default actor isolation
  is left at `nonisolated` (no `SWIFT_DEFAULT_ACTOR_ISOLATION`), and functions that must run off the main actor are
  marked `@concurrent`. Locks: `OSAllocatedUnfairLock` (`Mutex` needs macOS 15).
- The UI never waits on a subprocess: all `herdr` calls are async, off the main actor, with timeouts.
- `herdr` is used read-only (state queries only). Never run commands that change sessions, panes or agents.

## Design decisions

- The character is an own sheep (one of the "herd"), not any agent's mascot – Buddr is tied to herdr, not to a
  specific agent, and it avoids trademark issues. The current sheep is a placeholder; before settling on the final
  design, propose a few pixel-art variants to the user.
- Sprites are drawn with SwiftUI `Canvas` at an integer scale without smoothing. Default scale 6; S/M/L (4/6/8) later.
  Sprites are character grids (`.` = transparent, other characters = palette colors); a frame is a stack of sprites
  placed on a fixed canvas (`SheepSprites.canvasWidth` × `canvasHeight`) with room for effects above the sheep.
  Effect glyphs can be drawn without an outline and get one from `PixelSprite.outlined(with:)`.
- Window: borderless, transparent, non-activating `NSPanel` (never steals focus), `level = .floating`, on all Spaces
  (`.canJoinAllSpaces`, `.stationary`). Dragging: `SheepPanel.sendEvent` turns every left mouse down into
  `performDrag(with:)`, which does not depend on how the SwiftUI hosting view handles the event (unlike
  `isMovableByWindowBackground`). A click is a drag that ended with the panel moved by at most
  `SheepPanel.clickTolerance` points (`onClick`); it pets the sheep (see below). After a drag (the button is
  released) the panel is moved back into the `visibleFrame` of its screen, so it can't be dragged out of sight. Menu
  bar: SwiftUI `MenuBarExtra`.
- Fullscreen: while a fullscreen window covers the display with the sheep, the sheep runs off the screen and comes
  back when it is gone. Details in "Fullscreen escape" below.
- Data sources: local herdr sessions now; later all *enabled* saved machines, discovered dynamically (nothing
  hardcoded). Polling: local every ~2 s; remote every ~15 s (later). Sources are queried concurrently.
- A failed source is reported as a failure (later: "⚠" badge + error in the info bubble); it never blocks the others.
- Before implementing remote machines, verify whether `herdr --machine` can hang on an SSH authentication prompt; if
  so, gate remote queries by `herdr machine status --json`.
- Out of scope: sounds and notifications, focusing / replying to agents, one character per agent, non-herdr sources.

## herdr CLI

Resolve the binary from `PATH`, falling back to `/opt/homebrew/bin/herdr` and `/usr/local/bin/herdr` – GUI apps
don't inherit the shell `PATH`. Commands print JSON (verified with herdr 0.9.3):

```bash
herdr session list --json            # {"sessions":[{"name":"default","default":true,"running":true,
                                     #   "session_dir":"…","socket_path":"…/herdr.sock"}]}
herdr --session <name> agent list    # {"id":"cli:agent:list","result":{"type":"agent_list","agents":[…]}}
herdr --session <name> workspace list  # {"id":"cli:workspace:list","result":{"type":"workspace_list","workspaces":[…]}}
herdr machine list --json            # [{"id":"…","label":"Devel","target":"…","session":"default","enabled":true,…}]
herdr machine status --json          # checks saved machines without prompting for authentication
herdr --machine <id> agent list      # same as above, on a saved SSH machine
herdr api schema --json              # full JSON schema of the socket API (requests, responses, events)
```

- `agent list` entries: `agent` (optional, e.g. `"claude"`), `agent_status`, `pane_id`, `tab_id`, `workspace_id`,
  `terminal_id`, `focused`, `revision`, optional `cwd`, `foreground_cwd`, `terminal_title`,
  `terminal_title_stripped`, … Only `workspace_id` is given – join `workspace list` (`workspace_id` → `label`).
- `agent_status` is one of `idle`, `working`, `blocked`, `done`, `unknown` (`done` = finished and not yet seen by the
  user). Decode unknown future values as `unknown`.
- `agent list` / `workspace list` print JSON without `--json`; `session list` and `machine list` need `--json`.
  `machine list --json` is pretty-printed, the others are single-line.
- Errors use the envelope `{"error":{"code":"…","message":"…"},"id":"…"}` instead of `result`. The CLI prints it to
  **stderr** with exit status 1 (stdout stays empty).
- `--machine` must not be combined with `--session` / `--remote`; it uses the session saved in the machine profile.
  Use the profile `id` (labels may be ambiguous). Only query machines with `enabled: true`.
- Buddr polls `session list --json`, then `agent list` and `workspace list` of every running session concurrently
  (`HerdrStatusFetcher`). A failing `workspace list` only loses the labels (workspace IDs are shown instead); a
  failing `agent list` makes the source a `SourceFailure`. The binary is looked up again on every poll.
- Every subprocess gets a timeout (a few seconds local, ~15 s remote), `stdin = /dev/null`, and is terminated on
  timeout. One slow or unreachable source must never block the others or the UI.
- A timeout watcher must not hold the output pipe of the command being read, otherwise every call waits for the full
  timeout (lesson from the shell prototype). Likewise, a grandchild (e.g. `ssh`) can keep the pipe open after the
  direct child exits – stop waiting for EOF shortly after the process exits. Foundation starts the child as a process
  group leader, so `ProcessRunner` signals the whole group (`kill(-pid, …)`) on timeout and cancellation.
- Later (phase 4): event-driven updates over the socket instead of polling. Newline-delimited JSON over the Unix
  socket from `socket_path` (`~/.config/herdr/herdr.sock`, named sessions `~/.config/herdr/sessions/<name>/herdr.sock`).
  Request `{"id":"req_1","method":"agent.list","params":{}}`; `events.subscribe` answers with an ack line, then pushes
  events (`pane.agent_status_changed` needs a `pane_id`, so subscribe per pane; `pane.created`, `pane.closed`,
  `pane.exited`, `pane.agent_detected`). Events don't replay history – bootstrap with `agent.list`.

## Agent states → sheep behaviour

Aggregated state priority: **blocked > done > working > idle > unknown**. No agents (or herdr unavailable) counts as
`unknown`.

| State | Sheep behaviour |
|---|---|
| `working` | busy: trotting in place / bouncing, little bits flying around |
| `blocked` | pronounced: jumping, blinking "!" above the head |
| `done` | happy jump, "✔" in a small bubble |
| `idle` | calm: occasional blink, looks around; falls asleep ("zzz") after a while |
| `unknown` / no agents | dimmed / semi-transparent, "?" |

A running animation finishes its cycle before the state machine switches to another one.

Implementation (`SheepAnimator`):

- The poller sets the target status (`snapshot.status`); the animator picks the next clip only when the current clip
  has played its last frame. Keep every clip cycle short (tests enforce ≤ 1.6 s) so state changes show promptly.
- `idle` picks `idleRest` / `idleBlink` / `idleLook` at random (seeded `SplitMix64`, deterministic in tests) and
  switches to `sleeping` after 60 s of continuous `idle`. Any status change resets the idle timer.
- `done` plays `doneJump` when it starts and then every 4th cycle, `doneHold` otherwise.
- `unknown` is drawn at `SheepSprites.unknownOpacity`.
- Petting: a click on the sheep interrupts the current clip right away (unlike a state change) with
  `SheepSprites.petted` – eye closed, blushing, a rising heart, a small hop. `SheepAnimationDriver.interject` plays it
  once and hands back to the state machine; it is ignored while a script (escape) or another interjection plays, and a
  script replaces it.
- The sheep is composed of a body sprite and a head sprite drawn on top (offset `headX`/`headY`), so leg and head
  variants combine freely; effects (`!`, `?`, `z`, ✔ bubble, dust, hearts) are separate layers placed on the canvas.

## Fullscreen escape

Detection (`FullscreenDetector`, `FullscreenDebounce`, `FullscreenMonitor`):

- No public API tells whether a display shows a fullscreen app. `CGWindowListCopyWindowInfo` (on-screen windows,
  no desktop elements) is used instead: the display counts as fullscreen when a visible window of another app in
  layer 0 covers it completely. Owner, layer, bounds and alpha need no Screen Recording permission (titles would).
  This also catches borderless "fake fullscreen" windows (games, video); a zoomed window doesn't count, it leaves
  the menu bar (and the Dock, if shown) uncovered. Private CGS Space APIs were rejected.
- Window bounds are in global display coordinates (top-left origin, y down, same as `CGDisplayBounds`); screen frames
  are AppKit coordinates. The display is chosen by the AppKit frame, the windows are compared with its CG bounds.
- Notched displays: fullscreen windows start below the menu bar, which is 33 points tall while the top safe area
  inset is 32 (14" MacBook Pro). The top `safeAreaInsets.top + notchMenuBarAllowance` band may stay uncovered. The
  menu bar window stays on screen there even in fullscreen, so it can't serve as a signal. A zoomed window next to an
  auto-hidden Dock on a notched display can't be told apart and counts as fullscreen.
- The Dock owns a full-display window in layer 20 (27 during transitions); only layer 0 counts.
- Checks run on `NSWorkspace.activeSpaceDidChangeNotification` and screen parameter changes, again after 250 ms (the
  window list lags behind), and every second as a fallback (one query costs ~0.6 ms). Fullscreen ends only after it
  has been gone for 600 ms (`FullscreenDebounce`): during transitions the fullscreen window shrinks or vanishes for a
  moment.
- The notification arrives after the Space slide animation, and the panel (`.canJoinAllSpaces`) is shown on the new
  fullscreen Space at once – the sheep is briefly visible over the fullscreen app. That is where its escape starts.
  Faster polling would catch the window during the slide, but then nobody would see the escape.
- The display is the one of the sheep's home (`SheepEscape.homeFrame`), not of the panel, which moves off the screen.
- Logs: category `fullscreen` (on with the window's owner and layer, off).

Escape (`SheepEscape`, `EscapeRoute`, `SheepSprites.Escape`):

- Away: the current clip plays to its end (`SheepAnimationDriver.waitForCycleEnd`), a startled hop, the sheep turns
  to the nearer of the left and right screen edges (tie: right) and gallops until the panel is completely past it;
  then the panel is hidden. Back: the panel appears past the same edge and the sheep runs home with an ease-out,
  catches breath and continues with the state machine. Neighbouring displays are deliberately ignored.
- Speed: 150 pt/s, but one way never takes longer than 1.2 s (longer distances are run faster). The panel moves
  ~60 times a second in whole sprite pixels (`scale` points) to keep the pixel-art look.
- Each way plays to its end; if fullscreen ends before the clip does, the sheep doesn't leave at all. The panel
  ignores the mouse during the escape. If the home screen is gone, the sheep returns to the nearest one.
- The sheep faces left; running right uses mirrored frames (`SpriteFrame.mirrored(canvasWidth:)`). Escape clips are
  played as scripts by `SheepAnimationDriver` (`play` once, `loop`, `endScript`), outside the state machine, which
  keeps its target status and continues where it stopped.

## Testing

- Swift Testing (`import Testing`, `@Test`, `#expect`). The test bundle is hosted by the app (`TEST_HOST`), so
  `@testable import Buddr` works. Under tests the `@main` entry point (`BuddrMain`) runs an empty `TestHostApp`
  instead of `BuddrApp` (`RuntimeEnvironment.isRunningTests`), so no panel, polling or menu bar item starts and the
  real app code needs no test guards.
- Checking the running app: `screencapture` needs the Screen Recording permission (without it: "could not create
  image from display"). Without it, render views offscreen with SwiftUI `ImageRenderer` in a throwaway test, and
  inspect the panel with `CGWindowListCopyWindowInfo` (owner `Buddr`, layer 3 = `.floating`) – check that its
  bounds lie inside a screen, not just that it exists. Note that `NSScreen.main` is the screen with keyboard focus,
  not necessarily the built-in display.
- Fixtures in `BuddrTests/Fixtures` are real herdr 0.9.3 outputs, anonymized (home directory `/Users/me`, workspace
  labels, session UUID): `session-list`, `agent-list`, `workspace-list`, `error`. Edited variants derived from the same
  shapes: `session-list-multiple`, `agent-list-mixed` (all statuses, missing optional fields, a future status),
  `agent-list-empty`. Never commit personal paths or names. Synchronized groups copy the JSON files flat into the test
  bundle's `Resources/`; load them with `Fixture.data("name")`.
- herdr logic is tested through `FakeCommandRunner` (canned output keyed by the joined arguments); `ProcessRunner` is
  tested with real `/bin/sh` processes (timeouts, SIGTERM-ignoring children, grandchildren holding the pipe).
- Logs: `os.Logger` subsystem `cz.jsyrovy.buddr`. Watch with
  `/usr/bin/log stream --level info --predicate 'subsystem == "cz.jsyrovy.buddr"'` – in zsh, plain `log` is a shell
  builtin.

### Test coverage

`make coverage` runs the tests and prints line coverage of the app target (collection is enabled in the scheme, so
Xcode shows it too). Line-level detail: `xcrun xccov view --archive --file <absolute path> build/Test.xcresult`. The
per-file summary of `xccov` can report wrong line counts for small files (seen with `OneShotSignal.swift`); trust the
line-level output.

Coverage is a tool for finding untested behaviour, not a goal. Writing tests is cheap, maintaining and reviewing them
is not: every test is a constraint on future changes. A test must assert observable behaviour (results, state
transitions, the commands that were run), not just execute lines – a test that only raises the number makes
refactoring harder and proves nothing. There is no global percentage target; the total is dominated by the UI layer,
which is deliberately not unit-tested.

Aim for ~100 %, every branch covered by a meaningful test – this is pure, deterministic logic where bugs hide and
tests are cheap and stable:

- `State/` – status decoding (including unknown future values) and priority aggregation.
- `Herdr/` except `HerdrPoller` – output parsing, the error envelope, binary lookup, concurrent fetching and failure
  isolation between sources, `ProcessRunner` timeouts / process groups / pipes held by grandchildren.
- `Animation/` except `SheepAnimationDriver` – the `SheepAnimator` state machine, clip timing, `SplitMix64`.
- `Sprite/` data and models – `SheepSprites` grids and frame composition, `PixelSprite`, `SpriteFrame`.
- Placement math in `SheepPanelController`, `ScreenGeometry`, `EscapeRoute`.
- `FullscreenDetector` – window list parsing and the covering rules (notch, zoomed windows, other displays, layers);
  `FullscreenDebounce` – on right away, off only after the delay.

Also aim high, but these need a seam or a rendering step – never real-time waiting:

- `HerdrPoller`, `SheepAnimationDriver` – timer-driven loops. They take injectable `sleep` (and the poller `fetch`)
  closures; tests pass `ManualSleeper`, which reports every sleep and suspends until `wake()`, so the loop is driven
  step by step. Tests that sleep are slow and flaky, which is worse than no test. `stop()` is async and returns once
  the loop has ended, so tests can check that nothing happens after it.
- `SpriteCanvas` – rendered with `ImageRenderer` and compared pixel by pixel with the grid (integer scale, no
  smoothing, transparency, layer order, opacity). This checks the actual output, which line coverage of a `Canvas`
  closure cannot.

Fine to leave uncovered:

- `App/` – `BuddrMain`, `BuddrApp`, `AppDelegate` and the non-test branch of `RuntimeEnvironment`. Covering them
  means starting the real panel, menu bar and herdr polling under tests, which defeats `TestHostApp` and makes tests
  depend on the machine. Keep these files pure wiring instead: logic that needs a test moves into a testable type.
- `Window/` SwiftUI / AppKit glue – `SheepView`, `SheepPanel` event handling, `FullscreenMonitor` (notifications,
  window server queries), `SheepEscape` (moving the real panel in real time). Check them by running the app.
- Defensive fallbacks that can only be reached by faking system calls, e.g. the `kill(pid, …)` fallback in
  `ProcessRunner.signalProcessGroup`.

Do not add abstractions to production code just to cover lines. A seam is justified when it makes meaningful behaviour
testable (a clock for the poller), not to reach one more branch.
