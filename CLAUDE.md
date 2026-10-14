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
make measure  # CPU, wakeups, power and memory of the running app (scripts/measure.swift; ARGS="…")
make format   # xcrun swift-format, in place
make lint     # xcrun swift-format lint --strict
make clean    # rm -rf build
```

Run `make lint test` after every change. `CONFIG=Release make build` builds Release.

CI (`.github/workflows/ci.yml`, GitHub Actions on pushes to `main` and pull requests) runs `make lint`,
`make coverage` and `CONFIG=Release make build` in one job; the steps run even after an earlier one fails, and the
result bundle is uploaded when something fails. It uses the `xcode-27` runner image (a preview; `macos-26` only has
Xcode 26).

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
              wiring, Preferences (menu bar settings in UserDefaults), RuntimeEnvironment
  Window/     FloatingPanel (shared NSPanel setup), SheepPanel, SheepPanelController (creation, placement, the name
              plate window), PanelPositionStore (last position in UserDefaults), SheepView (root SwiftUI view),
              ScreenGeometry (screen choice, clamping), FullscreenDetector + FullscreenDebounce (pure) +
              FullscreenMonitor (notifications, polling), EscapeRoute (pure) + SheepEscape (runs off the screen and
              back), HideMode (pure) + SheepHiding (hides the sheep after a while of calm), NamePlatePanel (child
              panel) + NamePlateLayout (pure: plate scale, reserved room, placement)
  Sprite/     PixelSprite / SpriteFrame models, SpriteCanvas renderer, SheepSprites (all character data: palette,
              grids, frame composition, clip timing, the plate's look), PixelFont (glyphs, marks, truncation)
  Animation/  AnimationClip / SheepClipID, AnimationMode, SheepAnimator (pure state machine), SheepAnimationDriver
              (@Observable timer that plays it), SplitMix64
  Herdr/      HerdrLocator (binary lookup), ProcessRunner (subprocess with timeout) + OneShotSignal, HerdrClient
              (typed CLI calls + parsing), HerdrModels (Decodable output shapes), HerdrStatusFetcher (one snapshot
              of local sessions or of saved machines, sources queried concurrently), HerdrPoller (periodic loop on
              the main actor), HerdrMonitor (one poller per kind of source; combines, filters and logs changes)
  State/      AgentStatus (+ priority aggregation), HerdrSnapshot / AgentRecord / HerdrSource / SourceFailure,
              AgentOverview (pure: snapshot grouped by source and workspace for the menu bar list), AttentionTracker
              (pure: agents newly blocked / done, which one the plate names) + NamePlate (the plate's parts)
  Menu/       SnapshotStore (@Observable latest snapshot), AgentListView (content of the menu bar window)
  Debug/      Debug builds only (`#if DEBUG`): DebugControls (play any clip, send the sheep away, override the
              status, a long name plate), DebugSection (its orange box in the menu bar list)
BuddrTests/   Swift Testing tests, mirroring the app folders
  Fixtures/   herdr CLI JSON outputs
  Support/    fixture loader, FakeCommandRunner, ManualSleeper, ScriptedFetch + SnapshotRecorder, AgentRecord.stub,
              HerdrSnapshot init that derives the queried sources
scripts/      measure.swift (resource usage of the running app, see "Measuring resource usage")
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
- Window: borderless, transparent, non-activating `NSPanel` (`FloatingPanel`, never steals focus), `level = .floating`,
  on all Spaces (`.canJoinAllSpaces`, `.stationary`). Dragging: `SheepPanel.sendEvent` turns every left mouse down into
  `performDrag(with:)`, which does not depend on how the SwiftUI hosting view handles the event (unlike
  `isMovableByWindowBackground`). A click is a drag that ended with the panel moved by at most
  `SheepPanel.clickTolerance` points (`onClick`); it pets the sheep (see below). After a drag (the button is released)
  the panel is moved back into the `visibleFrame` of its screen, so it can't be dragged out of sight. Menu bar: SwiftUI
  `MenuBarExtra` in `.window` style (a popover; the `.menu` style can't lay out columns or color the rows) with the
  agent list, the settings ("Animation" and "Hide" pop-ups, "Watch Remote Machines") and "Quit Buddr". A segmented
  "Off | On Change | Always" control plus the duration doesn't fit the 360 pt width. A separate Settings window is not
  worth it until there are more settings (an `LSUIElement` app has to activate itself to show one).
- Agent list (`AgentListView`, grouping in `AgentOverview`): a summary ("1 blocked · 2 working"), then one section
  per source – "This Mac" (with the session name when several local sessions run), then the machines by label – in
  the order of discovery (`HerdrSnapshot.sources`, so sources without agents and failed ones show up too). A failed
  source shows only its error, no stale agents. Within a source, workspaces in herdr's sidebar order (`number`);
  agents in `agent list` order. Order never depends on status, so rows don't jump while the list is open. More than
  `WorkspaceGroup.idleFoldLimit` idle agents in a workspace are folded into one "N idle" row that unfolds on click.
  Status icons are SF Symbols differing in shape and color. Rows are information only (no focusing).
- The list reads `SnapshotStore`, which `AppDelegate` updates with every changed combined snapshot of
  `HerdrMonitor`, so an open list updates live, and disabled machines disappear from it like from the sheep's state.
  Opening the list (`onAppear`, which a `MenuBarExtra` window calls on every opening) calls `HerdrMonitor.refresh()`:
  every enabled poller that sleeps between polls polls right away (`HerdrPoller.refresh()` replaces the sleeping loop
  with a new one, which starts with a poll); one whose poll runs is left alone, so repeated openings never stack up
  `--machine` calls. No "updated … ago" label for now (the user didn't like a ticking age).
- Position: the origin after every drag is saved in `UserDefaults` (`panelOrigin`, `PanelPositionStore`). At launch
  the panel goes there, moved into the `visibleFrame` of its screen or the nearest one (displays may have changed);
  without a saved position it starts in the bottom-right corner of `NSScreen.main`. Escape moves are not saved.
  Room for the name plate is always kept below the panel (`NamePlateLayout.reservedHeight`): clamping
  (`SheepPanelController.onScreenOrigin`) and the default corner use the panel frame extended by it, so the sheep
  doesn't jump up when a plate appears. A saved position that is too low moves up at the next launch or drag.
- Fullscreen: while a fullscreen window covers the display with the sheep, the sheep runs off the screen and comes
  back when it is gone. Details in "Fullscreen escape" below.
- Hiding: the sheep can leave the screen on its own after a while of calm. Details in "Hiding" below.
- Name plate: while the sheep is `blocked` or `done`, a plate under it names the agent. Details in "Name plate" below.
- Data sources: running local herdr sessions and all *enabled* saved machines, both discovered on every poll
  (nothing hardcoded). `HerdrMonitor` polls them in independent loops – local every 2 s, machines every 15 s – so a
  slow machine never delays local updates, and shows the combined snapshot. Sources are queried concurrently.
- Remote machines can be switched off in the menu bar (`Preferences.watchesRemoteMachines`, `UserDefaults` key
  `watchesRemoteMachines`, on by default). Off stops the machine poller – no `--machine` calls at all, a running one
  is cancelled – and removes the machines' agents and failures from the snapshot at once
  (`HerdrMonitor.setEnabled(_:_:)`); on polls them right away.
- Animation can be set in the menu bar (`Preferences.animationMode`, key `animationMode`: `off` / `onChange` /
  `always`, default `always`; `Preferences.animationSeconds`, key `animationDurationSeconds`, one of 5 / 10 / 30 /
  60 s, default 10). See "Animation modes" below.
- A failed source is reported as a failure (⚠ + error in the menu bar list); it never blocks the others.
  A machine that can't be reached or would need authentication is just a failed source: Buddr doesn't gate machine
  queries by `herdr machine status` (see "herdr CLI").
- Debug builds (`#if DEBUG`, set in the Debug configuration) show an orange "DEBUG" box in the menu bar list
  (`DebugSection`, `DebugControls`): a button for every clip (`SheepSprites.allClips`), played once over whatever
  plays (`endScript()` + `interject`) or looped until "Stop Clip", optionally mirrored; "Run Away" / "Wander Off" /
  "Come Back" (`SheepEscape.Reason.debug(startled:)`); a status override that replaces the herdr status for the
  animation, hiding and the name plate (not for the list) – overridden to `blocked` / `done` without an agent in it,
  the plate shows `debug · blocked`; and "Long Name", a long sample on the plate (shortening, screen edges). Release
  builds contain none of it;
  check with `CONFIG=Release make build` after touching it.
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
- Read-only extras of `agent list` entries (herdr 0.9.3, `herdr api schema --json`, `AgentInfo`); there are no
  timestamps:
  - `state_change_seq` (integer, default 0): a counter of status changes, increasing across the whole herdr server,
    so it orders agents of one source but can't be compared between sources. Buddr reads it
    (`AgentRecord.stateChangeSeq`, `nil` when missing in older versions) only to order agents that arrive in one poll.
  - `completion_seq` (integer or `null`): set when the current idle state followed finished work, whether or not the
    user has seen it. Unused.
  - `agent_session` (object or `null`): the agent's own session, e.g. `{"agent":"claude","kind":"id",
    "source":"herdr:claude","value":"<uuid>"}`. Unused (it could locate a transcript; out of scope).
- `agent_status` is one of `idle`, `working`, `blocked`, `done`, `unknown` (`done` = finished and not yet seen by the
  user). Decode unknown future values as `unknown`.
- `agent list` / `workspace list` print JSON without `--json`; `session list` and `machine list` need `--json`.
  `machine list --json` is pretty-printed, the others are single-line.
- Errors use the envelope `{"error":{"code":"…","message":"…"},"id":"…"}` instead of `result`. The CLI prints it to
  **stderr** with exit status 1 (stdout stays empty).
- `--machine` must not be combined with `--session` / `--remote`; it uses the session saved in the machine profile.
  Use the profile `id` (labels may be ambiguous). Only query machines with `enabled: true`. An unknown machine is a
  plain-text error on stderr with exit status 2 (`Error: unknown machine '…'`), not an envelope.
- `--machine` forwards the API request to the herdr server on the machine; Buddr never runs `ssh` itself. The
  `agent list` output has the same shape as locally. herdr's own SSH connections (seen from the TUI client) use
  `BatchMode=yes`, `NumberOfPasswordPrompts=0`, `ConnectTimeout=10` and a shared `ControlMaster` socket with
  `ControlPersist=600`; with an open master, a `--machine` call took ~0.3 s and started no new `ssh` process. Whether
  a call without a master uses the same options is unverified – the machine timeout covers a hang either way.
- Buddr polls `session list --json`, then `agent list` and `workspace list` of every running session concurrently
  (`HerdrStatusFetcher.fetchSessions`); likewise `machine list --json` (local, doesn't connect) and the same two
  commands with `--machine <id>` of every enabled machine (`fetchMachines`). A failing `workspace list` only loses
  the labels (workspace IDs are shown instead); a failing `agent list` makes the source a `SourceFailure`. The binary
  is looked up again on every poll.
- Every subprocess gets a timeout (5 s local, 15 s for `--machine`; `HerdrSource.timeout`), `stdin = /dev/null`, and
  is terminated on timeout. One slow or unreachable source must never block the others or the UI.
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

Animation modes (`AnimationMode`, set with `SheepAnimator.setAnimation(_:for:)`):

- `always`: as above. `off`: a still pose of the state instead of its clip (`idleStill`, `sleepingStill` after the
  usual 60 s, `workingStill`, `blockedStill`, `doneStill`, `unknownStill`) – one picture made of the clip's pictures,
  so the state's sign ("!", ✔, "?", "zzz", flecks) still shows. `onChange`: animated until `animatesFor` has been
  played since the last change, then the running clip finishes and still poses follow.
- A change is a status change (`setStatus`) or `replay()`, which plays the current status from its start again
  (`done` jumps again). `AppDelegate` calls it when an agent is newly `blocked` or `done`, which matters when the
  aggregated status stays the same (`AttentionTracker.hasNewArrivals`, agents keyed by source, pane and status –
  agents of a source that comes back count as new). A newly working agent doesn't count.
- Time is counted from played frames, so it pauses during scripts (escape, petting). Changing the mode or duration
  takes effect when the clip ends; the time already played since the last change counts towards a new duration.
- A still pose is one 500 ms frame, so a state change still shows within half a second.
- Petting plays in every mode and hands back to the still pose. Without animation (`off`) the fullscreen escape
  doesn't run: the panel is just hidden and shown again (`SheepEscape` reads `SheepAnimationDriver.animationMode`).

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
- Speed (`EscapeRoute.Pace`): running 150 pt/s, but one way never takes longer than 1.2 s (longer distances are run
  faster); walking (hiding) 45 pt/s, at most 3 s. The panel moves ~60 times a second in whole sprite pixels (`scale`
  points) to keep the pixel-art look.
- Each way plays to its end; if fullscreen ends before the clip does, the sheep doesn't leave at all. The panel
  ignores the mouse during the escape. If the home screen is gone, the sheep returns to the nearest one.
- The sheep faces left; running right uses mirrored frames (`SpriteFrame.mirrored(canvasWidth:)`). Escape clips are
  played as scripts by `SheepAnimationDriver` (`play` once, `loop`, `endScript`), outside the state machine, which
  keeps its target status and continues where it stopped.
- With the animation mode `off` (`SheepAnimationDriver.animationMode`, read at the start of each way) the panel is
  hidden right away, without waiting for the clip, and shown again at home.

## Hiding

Set in the menu bar (`Preferences.hideMode`, key `hideMode`: `never` / `whenIdle` / `unlessNeeded`, default `never`;
`Preferences.hideMinutes`, key `hideAfterMinutes`, one of 1 / 5 / 15 / 30 min, default 5).

- Calm (`HideMode.isCalm`): `whenIdle` – the aggregated status is `idle` or `unknown`; `unlessNeeded` – it is not
  `blocked` or `done` (agents may work). `unknown` (no agents, herdr not running) counts as calm, so a hidden sheep
  doesn't show "?" when herdr goes away.
- `SheepHiding` hides the sheep after `hideMinutes` of continuous calm and brings it back as soon as the status isn't
  calm. The countdown (real time) starts again on every status change, settings change, petting and `show()`; at
  launch the sheep is visible and the countdown runs from the start. While hidden, a change between two calm statuses
  (e.g. `idle` → `working` in `unlessNeeded`) keeps it hidden.
- The sheep can't be clicked while hidden; the menu bar list then shows "Show Sheep" (`SheepHiding.show()`), which
  calls it back until another `hideMinutes` of calm.
- Moving uses `SheepEscape` with the same route as the fullscreen escape. When hiding is the only reason, the sheep
  leaves bored instead of startled: a yawn (`SheepSprites.Escape.yawn`; if the reason is gone by its end, it stays),
  then a slow walk (`Escape.walk`, `EscapeRoute.Pace.walk`). It comes back running, like after a fullscreen window.
  `off` animation just hides the panel.
- `SheepEscape.setAway(_:for:)` keeps a set of reasons (`fullscreen`, `hiding`); the sheep is away while there is any.
- Logs: category `hiding`.

## Name plate

A dark plate with light pixel text under the sheep's feet, naming the agent the sheep reports.

- Shown only while the aggregated (or debug-overridden) status is `blocked` or `done` – the statuses that are not calm
  in `HideMode.unlessNeeded`. It names one agent in that status, the one that got into it last, and adds `+N` for the
  others in it; agents in a lower status are not counted. Text: `[machine label · ]workspace · title` – the machine
  label only for remote sources; the title is `AgentRecord.displayTitle`, dropped when it equals the workspace label.
- Order without clocks (`AttentionTracker`, which also tells `replay()` about new arrivals): every agent keyed by
  source, pane and status gets an increasing arrival number when it first shows up as `blocked` / `done` and loses it
  once it is gone, so an agent that leaves and comes back is new. Ties within one poll (e.g. at launch):
  `state_change_seq`, then `agent list` order.
- Font (`PixelFont`): 5×7 px, proportional, 2 rows for descenders, 1 px between glyphs, glyphs taken from the mockup
  (`1` redrawn so it doesn't read as `l`). Lowercase letters with a caron, acute or ring get the mark in the two rows
  above the x-height (`í` without its dot); after an ascender a caron becomes an apostrophe to the right (`ď`, `ť`,
  `ľ`). Capitals and other marks are drawn without the mark; characters without a glyph become `?`. The font lives in
  its own file (not part of the character); the plate's colors (outline and wool), padding, gap, pixel size and
  `maxTextWidth` (100 px) are in `SheepSprites.Plate`.
- Truncation by pixel width (`SheepSprites.Plate.text(for:maxWidth:)`, on `PixelFont.shortened`, one pass over the
  text): only the title is shortened, ending in `…`; the prefix and `+N` are kept. If even those don't fit, the whole
  text is cut at the end.
- A separate child window (`NamePlatePanel`), not a bigger sheep panel: the plate is wider than the sheep, and growing
  `SheepPanel` would break the clamping, `EscapeRoute` distances, the saved position and the click / drag area. The
  plate panel is borderless, transparent, non-activating, `ignoresMouseEvents`, with the sheep panel's level and
  collection behaviour, added with `addChildWindow(_:ordered: .above)` so it moves with the sheep (also while
  dragging). `SheepPanelController` adds and removes it explicitly (`updatePlate`) instead of relying on how AppKit
  orders child windows with their parent.
- Placement (`NamePlateLayout`): centered under the sheep (the body is centered on the canvas), `Plate.gap` below the
  feet, moved horizontally into the `visibleFrame` of the sheep's screen; never mirrored or moved above the sheep.
  Re-laid out on every `setOrigin`, after a drag and on screen parameter changes. Plate pixel: the sheep's scale
  divided by `Plate.pixelDivisor`, at least one point (2 at the default scale 6).
- The text follows the snapshot right away, without waiting for the running clip (≤ 1.6 s of mismatch). The plate is
  redrawn only when its text changes. It stays in every animation mode and while petted, leaves with the sheep
  (fullscreen, hiding), and is hidden during the escape run itself (`SheepEscape` suppresses it once the startle or
  yawn is over and lifts it after the arrival). The menu bar list is unchanged.

## Testing

- Swift Testing (`import Testing`, `@Test`, `#expect`). The test bundle is hosted by the app (`TEST_HOST`), so
  `@testable import Buddr` works. Under tests the `@main` entry point (`BuddrMain`) runs an empty `TestHostApp`
  instead of `BuddrApp` (`RuntimeEnvironment.isRunningTests`), so no panel, polling or menu bar item starts and the
  real app code needs no test guards.
- Checking the running app: `screencapture` needs the Screen Recording permission (without it: "could not create
  image from display"). Without it, render views offscreen with SwiftUI `ImageRenderer` in a throwaway test (it
  draws neither the content of a `ScrollView` nor AppKit-backed controls such as `.link` buttons), and
  inspect the panel with `CGWindowListCopyWindowInfo` (owner `Buddr`, layer 3 = `.floating`) – check that its
  bounds lie inside a screen, not just that it exists. Note that `NSScreen.main` is the screen with keyboard focus,
  not necessarily the built-in display.
- Fixtures in `BuddrTests/Fixtures` are real herdr 0.9.3 outputs, anonymized (home directory `/Users/me`, workspace
  labels, session UUID, machine IDs, labels and SSH targets): `session-list`, `agent-list`, `workspace-list`, `error`,
  `machine-list`. Edited variants derived from the same shapes: `session-list-multiple`, `agent-list-mixed` (all
  statuses, missing optional fields including `state_change_seq`, a future status), `agent-list-empty`,
  `machine-list-mixed` (a disabled machine). Never commit personal paths or names. Synchronized groups copy the JSON
  files flat into the test bundle's `Resources/`; load them with `Fixture.data("name")`.
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

- `State/` – status decoding (including unknown future values), priority aggregation, `AgentOverview` grouping and
  ordering, `AttentionTracker` arrivals and order, `NamePlate` text.
- `Herdr/` except `HerdrPoller` and `HerdrMonitor` – output parsing, the error envelope, binary lookup, concurrent
  fetching and failure isolation between sources, `ProcessRunner` timeouts / process groups / pipes held by
  grandchildren.
- `Animation/` except `SheepAnimationDriver` – the `SheepAnimator` state machine, clip timing, `SplitMix64`.
- `Sprite/` data and models – `SheepSprites` grids and frame composition, `PixelSprite`, `SpriteFrame`, the
  `PixelFont` glyphs, marks and truncation, the `SheepSprites.Plate` sprite.
- Placement math in `SheepPanelController` (including the room reserved for the plate), `ScreenGeometry`,
  `EscapeRoute`, `NamePlateLayout`.
- `HideMode` – which statuses are calm in each mode.
- `FullscreenDetector` – window list parsing and the covering rules (notch, zoomed windows, other displays, layers);
  `FullscreenDebounce` – on right away, off only after the delay.

Also aim high, but these need a seam or a rendering step – never real-time waiting:

- `HerdrPoller`, `HerdrMonitor`, `SheepAnimationDriver`, `SheepHiding` – timer-driven loops. They take injectable
  `sleep` (and the pollers `fetch`) closures, `HerdrMonitor` one `HerdrPoller.Feed` per kind of source; tests pass
  `ManualSleeper` (one per loop), which reports every sleep and suspends until `wake()`, so the loop is driven step by
  step, and `ScriptedFetch`. Tests that sleep are slow and flaky, which is worse than no test. `stop()` is async and
  returns once the loop has ended, so tests can check that nothing happens after it. `HerdrPoller.cancel()` stops at
  once without waiting (nothing is reported after it); a restarted loop waits for the cancelled one, so two never
  overlap. `refresh()` is checked the same way: a sleep reported by `ManualSleeper` ends without `wake()`.
- `SpriteCanvas` – rendered with `ImageRenderer` and compared pixel by pixel with the grid (integer scale, no
  smoothing, transparency, layer order, opacity). This checks the actual output, which line coverage of a `Canvas`
  closure cannot.

Fine to leave uncovered:

- `App/` – `BuddrMain`, `BuddrApp`, `AppDelegate` and the non-test branch of `RuntimeEnvironment`. Covering them
  means starting the real panel, menu bar and herdr polling under tests, which defeats `TestHostApp` and makes tests
  depend on the machine. Keep these files pure wiring instead: logic that needs a test moves into a testable type.
- `Window/` SwiftUI / AppKit glue – `SheepView`, `SheepPanel` event handling, `FullscreenMonitor` (notifications, window
  server queries), `SheepEscape` (moving the real panel in real time), `NamePlatePanel` and showing the plate in
  `SheepPanelController`. Check them by running the app.
- `Menu/` – `AgentListView` (layout only; the logic is in `AgentOverview`). Check it with `ImageRenderer` or the app.
- Defensive fallbacks that can only be reached by faking system calls, e.g. the `kill(pid, …)` fallback in
  `ProcessRunner.signalProcessGroup`.

Do not add abstractions to production code just to cover lines. A seam is justified when it makes meaningful behaviour
testable (a clock for the poller), not to reach one more branch.

## Measuring resource usage

`scripts/measure.swift` measures the running app from outside – there is no measuring code in the app. Run it with
`make -s measure ARGS="…"`: it is compiled once into `build/measure`, while running it through its shebang makes
`xcrun swift` compile it every time and keep ~300 MB for the whole measurement. `--help` lists the options.

- Every `--interval` (default 5 s) it reads the kernel's counters of the process (`proc_pid_rusage`, no root needed):
  CPU of the app, CPU of its exited child processes (the herdr calls, which Activity Monitor and `top` don't show),
  interrupt and idle wakeups, energy (the kernel's estimate in nJ, shown as mW) and `phys_footprint` (Activity
  Monitor's "Memory"). `avg` is over the whole run, `p95` / `max` over the samples; CPU is in % of one core.
- By default it runs until Ctrl-C (or `SIGTERM`) and prints a line per sample; `--duration` stops it. `--json` prints
  JSON on stdout (messages on stderr) and requires `--duration`, so an agent never waits for a Ctrl-C – agents always
  run it with `--json --duration …`.
- Every run is saved as `build/measurements/<time>-<release|debug>[-<label>].json` (snake_case keys with the units in
  the names, the summary before the samples). `show <file>` prints a saved run, `compare <a> <b>` a table with the
  deltas; it refuses Release vs. Debug and warns when the settings, the power source or profiling differ or a run is
  shorter than a minute.
- Measure the Release build (`make install`) for absolute numbers; Debug (`-Onone`) only against other Debug runs. The
  configuration is detected by `Buddr.debug.dylib` next to the executable and flagged in the output. A run also
  records the menu bar settings as the app uses them (animation and remote machines change the cost a lot; the script
  mirrors the keys, choices and defaults of `Preferences`) and warns when the app was built before the last commit,
  started less than a minute ago, or the settings changed during the run.
- `--profile` also records a Time Profiler trace (`xctrace`) next to the JSON; measuring starts once xctrace records
  (it takes a few seconds to attach).
- Several Buddr processes (a dev build next to the installed one, a test host) need `--pid`.
