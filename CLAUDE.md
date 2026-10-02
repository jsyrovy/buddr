# Buddr

Buddr is a small native macOS desktop buddy: a pixel-art sheep sitting in a corner of the screen that reacts to the
state of AI coding agents running in [herdr](https://herdr.dev). One character shows the aggregated state of all
agents. It is information only – it never focuses, attaches to, or sends anything to agents.

## Commands

```bash
make build    # xcodebuild Debug build into build/DerivedData
make test     # Swift Testing unit tests (hosted by the app)
make run      # build, kill a running instance, open the app
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
  App/        @main App (MenuBarExtra with Quit), AppDelegate wiring, RuntimeEnvironment
BuddrTests/   Swift Testing tests
```

## Conventions

- Everything in the repo (code, comments, docs, commit messages) is in English.
- No third-party dependencies. No image assets: all graphics are drawn in code from pixel grids.
- All sprite pixel data lives in one file (`SheepSprites.swift`) so the character can be swapped easily.
- Swift 6 strict concurrency: UI types are `@MainActor`; data crossing actors is `Sendable`.
- The UI never waits on a subprocess: all `herdr` calls are async, off the main actor, with timeouts.
- `herdr` is used read-only (state queries only). Never run commands that change sessions, panes or agents.

## Design decisions

- The character is an own sheep (one of the "herd"), not any agent's mascot – Buddr is tied to herdr, not to a
  specific agent, and it avoids trademark issues. The current sheep is a placeholder; before settling on the final
  design, propose a few pixel-art variants to the user.
- Sprites are drawn with SwiftUI `Canvas` at an integer scale without smoothing. Default scale 6; S/M/L (4/6/8) later.
- Window: borderless, transparent, non-activating `NSPanel` (never steals focus), `level = .floating`, on all Spaces
  (`.canJoinAllSpaces`, `.stationary`), dragged with the mouse. Menu bar: SwiftUI `MenuBarExtra`.
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
- Errors use the envelope `{"id":"…","error":{…}}` instead of `result`.
- `--machine` must not be combined with `--session` / `--remote`; it uses the session saved in the machine profile.
  Use the profile `id` (labels may be ambiguous). Only query machines with `enabled: true`.
- Every subprocess gets a timeout (a few seconds local, ~15 s remote), `stdin = /dev/null`, and is terminated on
  timeout. One slow or unreachable source must never block the others or the UI.
- A timeout watcher must not hold the output pipe of the command being read, otherwise every call waits for the full
  timeout (lesson from the shell prototype). Likewise, a grandchild (e.g. `ssh`) can keep the pipe open after the
  direct child exits – stop waiting for EOF shortly after the process exits.
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

## Testing

- Swift Testing (`import Testing`, `@Test`, `#expect`). The test bundle is hosted by the app (`TEST_HOST`), so
  `@testable import Buddr` works. `RuntimeEnvironment.isRunningTests` keeps the host app inert during tests (no
  panel, no polling, no menu bar item).
