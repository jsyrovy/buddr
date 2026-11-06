# Changelog

## 0.2 – 2026-11-06

- New buddies next to the sheep: a corgi that digs while agents work, the Earth that spins with the Moon circling it,
  a rainbow cat flying on a pop-tart, and a UFO that beams up little sheep. They show the same signs as the sheep.
- Choose the buddy in the menu bar ("Buddy"), or let them take turns every 15, 30 or 60 minutes. A turn ends only
  while no agent needs you; the old buddy walks off the screen and the new one runs in.
- Install with Homebrew: `brew install --cask jsyrovy/tap/buddr`.

## 0.1 – 2026-11-05

The first release.

- A pixel-art sheep in a corner of the screen shows the state of all AI coding agents in
  [herdr](https://herdr.dev) and herdr-core (`hc`): busy while they work, jumping with a "!" when one waits for you,
  happy when one is done, dozing off when all are idle.
- Agents of local herdr sessions and its saved SSH machines, and of herdr-core on this Mac and the machines added to
  it.
- A name plate under the sheep names the agent that waits for you or is done.
- The menu bar item lists all agents by machine and workspace, and holds the settings: which backends to read, remote
  machines, animation, the name plate and hiding the sheep when nothing needs you.
- The sheep runs off the screen while a fullscreen app covers its display and comes back afterwards. Drag it anywhere
  (the position is remembered); click it to pet it.
- Requires macOS 14 or later and herdr or herdr-core.
