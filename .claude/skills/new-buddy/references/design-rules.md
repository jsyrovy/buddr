# Design rules for a buddy

## Meeting the rules

The rules are the doc comment of `Buddy` (`Buddr/Sprite/Buddy.swift`), checked for every `BuddyID` by
`BuddrTests/Animation/BuddyClipsTests.swift`; the clips are `ClipID` and `EscapeClipID` (`Animation/AnimationClip.swift`
documents each) and `petted`. How to meet them:

- **Something coming in from an edge** (the UFO's sheep rising from the ground) is a cut-off sprite, e.g.
  `Grid.sheep.prefix(rows)` – no layer may reach past the canvas.
- **Facing left** is untested: check it in the previews. Asymmetric details (glints, lights, speed lines) flip with the
  mirrored frames when the buddy runs right.
- **At rest** the opaque pixels may be off center by 1 px at most.
- **Still poses:** `AnimationClip.still(clip.frames[i].sprite)` of the state's clip (done: of `doneHold`).

## Shared with every buddy

- **Signs:** `SheepSprites.Effect` ("!", ✔ bubble, "?", z's, hearts) – never redraw them. Usual places: ✔ bubble
  (0, 0), "!" (1, 0), "?" (0, 0 / 1); z's and hearts are placed per buddy. They sit at the top left and often overlap
  the buddy's head a little – check every frame with a sign in `frames.png`.
- **Colors:** `SheepSprites.outline` for the outline. A color that has to match a sign (an alarm light next to "!", a
  pink light next to the hearts) comes from `SheepSprites.palette`, so recoloring a sign keeps them together.

## Drawing within the limits

- **No alpha:** palette colors are opaque RGB. Glass, beams or glow are drawn as stripes or a dither with gaps, and
  animated stripes read as light (the UFO's beam).
- **Contrast:** signs and effects must read on a dark and a light desktop – the previews show both. Pale on pale
  vanishes (white sparkles on the pale beam did); add a colored edge or a darker core.
- **Small details:** at 22 × 20 a recognisable thing needs about 6 × 5 px with an outline (the beamed sheep is 8 × 6).
  A one-pixel feature (eye, antenna) works when it contrasts with what is around it.
- **Building parts:** grids as character rows in `Grid`, variants of a part differ only in a row or two (a function
  building the grid, see `UFOSprites.Grid.dome`), sprites built once (`Part`, or a dictionary over a `CaseIterable`
  enum), frames composed by one function with defaults (`ufo(face:lights:legs:dy:)`), back to front.
- **No transitions:** the state machine switches clips, it has no in-between clip. A pose far from the rest pose (the
  UFO hovering 5 px higher) jumps when the state changes – accept it consciously or keep the poses closer.
- **Timing:** ~150 ms per frame is the norm (sheep, cat); escape run 80 ms. Shorter frames in a long-lasting state
  (working) cost wakeups and redraws for as long as agents work; repeating an identical frame is free. If it matters,
  compare with `make -s measure ARGS="--json --duration 120"`.
- **Smooth loops:** a looping clip should end where it starts – a thing that pops up at the start of each cycle looks
  like a glitch (the UFO's sheep now rises out of the bottom edge).

