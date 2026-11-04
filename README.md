# Buddr

Buddr is a desktop buddy for [herdr](https://herdr.dev) agents: a small pixel-art sheep that sits in a corner of your
macOS screen and reacts to the state of the AI coding agents running in herdr or in herdr-core (`hc`, the terminal
runtime behind herdr-app). Think Clippy, but it only tells you when an agent is busy, waiting for you, or done – it
never gets in your way.

| Agent state | The sheep… |
|---|---|
| working | trots in place, bits flying around |
| blocked (waiting for you; also herdr-core's `error`) | jumps, with a blinking "!" |
| done | does a happy jump, shows a "✔" |
| idle | blinks, looks around, falls asleep after a while |
| no agents / unknown | is dimmed, with a "?" |

With several agents, the most urgent state wins: blocked > done > working > idle > unknown. While the sheep is
blocked or done, a small plate under it names the agent – `[machine · ]workspace · title`, with `+N` when more agents
wait for you.

The menu bar item lists all agents and holds the settings. "Agents from" picks herdr, hc or both (the default); a
chosen one that isn't installed or running shows up with a ⚠ in the list.

> **Status:** early development (MVP). The sheep is a placeholder; the final design comes later.

## Requirements

- macOS 14 Sonoma or later
- [herdr](https://herdr.dev) installed (looked up in `PATH`, `/opt/homebrew/bin` and `/usr/local/bin`), or
  herdr-core running – Buddr talks to its socket in the default session
  (`~/.local/state/herdr-core/default/default.sock`) and never starts it
- To build: Xcode 27 (Swift 6)

## Building from source

```bash
git clone https://github.com/jsyrovy/buddr.git
cd buddr
make run      # builds the Debug app into build/DerivedData and opens it
make install  # builds Release, installs it to ~/Applications and opens it
```

Install somewhere else with `make install INSTALL_DIR=/Applications`; `make uninstall` removes the app again.
Other targets: `make build`, `make test`, `make lint`, `make format`, `make clean`. The app has no Dock icon; quit it
from its menu bar item.

## Distribution

Buddr is not going to be in the Mac App Store: the App Sandbox forbids running the system-installed `herdr` and `ssh`
binaries, the herdr and herdr-core sockets live outside the app container, remote machines would need an own SSH
client with access to `~/.ssh`, and the app does nothing without herdr or herdr-core anyway.

Releases are signed with Developer ID and notarized by Apple, so a downloaded copy opens without Gatekeeper warnings
(`make release`, for the maintainer; changes in [CHANGELOG.md](CHANGELOG.md)). Until the first one is published, build
it from source. The plan is a Homebrew cask (herdr users already have Homebrew).

## Roadmap

1. **MVP** – floating, draggable, transparent window with a placeholder sheep drawn from a pixel grid; animations for
   `working`, `blocked`, `done`, `idle` and `unknown`; local herdr state via CLI polling, aggregated by priority; menu
   bar item with Quit.
2. Info bubble with the agent list (machine, session, workspace, agent, status, terminal title).
3. Remote machines (all enabled saved herdr SSH machines), unreachable-machine badge, S/M/L size, remembered
   position, launch at login.
4. Event-driven local updates over the herdr socket (and herdr-core's `events.subscribe`), more animations, final
   sheep design.
5. Packaging: signed and notarized `.app`, Homebrew cask, screenshots.

Done outside this list: herdr-core (`hc`) as a second backend, with its machines.

Out of scope for now: sounds and notifications, focusing or replying to agents, one character per agent, agent sources
other than herdr and herdr-core.

## License

[MIT](LICENSE) – code and artwork.
