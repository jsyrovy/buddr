---
name: new-buddy
description: Design and add a new buddy to Buddr (an on-screen character like the sheep, the rainbow cat or the UFO), or redesign an existing buddy's look or clips. Covers the concept, previews rendered from the app's code (`make previews`), side-by-side variants of single clips, implementation, review and commit, with the user deciding at each checkpoint. Use when the user asks for a new buddy or character, or to change how a buddy looks or moves.
---

# New buddy

A buddy is designed with the user, not for them: they see the pixel art only in previews and decide at every
checkpoint. Follow the same steps every time.

Read first: "Buddies" and "Agent states → buddy behaviour" in `CLAUDE.md`, and an existing buddy –
`Buddr/Sprite/UFOSprites.swift` is the closest template (parts as enums, a frame function, clips, escape, petting),
`RainbowCatSprites.swift` the other one. Then `references/design-rules.md` (meeting the rules, drawing within the
limits, pitfalls met so far) – before drawing.

## Ground rules

- **Previews come from the app's code only:** `make -s previews BUDDY=<BuddyID>` (header of
  `scripts/previews.swift`). Never write a separate prototype renderer: a second drawing path drifts from what runs.
- **Draft in the real file:** `Buddr/Sprite/<Name>Sprites.swift` plus its `BuddyID` case (`Buddy.swift`) as soon as
  the look is chosen (step 1), uncommitted until the user approves. Clips not designed yet may reuse the rest pose for
  now. Only competing looks before that live in the variants file (see step 1).
- **Look before showing:** read `build/previews/<id>/frames.png` yourself (overlaps of signs and buddy, legibility,
  timing) and fix what is off before the user sees it. The image is scaled down when read and loses single pixels
  (eyes): crop the clips in question (`sips -c <height> <width> --cropOffset <y> <x> frames.png --out /tmp/…`) or
  render just them as variants. The `unknown` clips are dimmed – check their details undimmed in the variants.
- **Hand over the page:** the `open -a Safari …` command `make previews` prints, for the user to run with `!`.
- **Checkpoints:** stop and wait. Ask open decisions as a short numbered list, each with a recommendation, so the user
  can answer "1. … 2. …".
- **A cleanup keeps the look:** before refactoring an approved buddy, copy `build/previews/<id>`; afterwards render
  again and `cmp` every file – a changed pixel or duration is not a cleanup.
- `make run` quits the user's installed Buddr – suggest it, don't run it unasked.

## Steps

### 1. Concept → checkpoint

Propose in a few lines and a table:
- the look: silhouette, palette, size on the 22 × 20 canvas with room for the signs at the top left;
- the buddy's idea (the cat's rainbow, the UFO's beam) and whether it can be drawn at this size;
- what it does in each state: working, blocked, done, idle (blink, look), sleeping, unknown, petting, running off
  (startle, run, yawn, walk, arrive);
- its menu name (`BuddyID.name`).

Draft the rest pose and the buddy's idea in code, render and show them. If the look is open, show two or three
variants (CLAUDE.md wants variants before a design settles). Competing looks (a corgi, a beagle, a dachshund) don't fit
one `<Name>Sprites.swift`, and the file's and the case's names depend on the choice: draft them in the variants file
(step 2) as whole-figure literal grids with a scratch palette, each rest pose also with the ✔ bubble and the "!" over
it, and the sheep as a size reference. Ask the decisions, then wait.

Expect several rounds on the look (more candidates, variants of the favourite, tuning it), often ending in a
combination of traits from several variants. Keep the current favourite as the reference (`a2-now`), name the others by
what they change (`a2b-ears-blush`, `a2f-eyes-tail-legs`), say in a line what each changes and how it reads, recommend
one. Mention a conflict with the signs when the look is chosen (see "Signs" in `references/design-rules.md`). Create
the real file once the look and the name are settled.

### 2. Variants of single clips → checkpoint (when something is disputed)

Render alternatives of one clip side by side: write a scratch file in `build/` (ignored, never committed) and run
`make -s previews VARIANTS=build/variants.swift` → `build/previews/variants/`.

```swift
// build/variants.swift
enum PreviewVariants {
    static let clips: [(name: String, clip: AnimationClip)] = [
        ("a-now", UFOSprites.buddy.clips[.working]),
        ("b-from-below", AnimationClip((0..<14).map { index in /* frames from the buddy's parts */ })),
    ]
}
```

The file sees the app module: build frames from the buddy's internal parts (`Grid`, the part enums, the frame function
like `UFOSprites.ufo(…)`); a helper needed here can't be `private`. Keep the current version as `a-…`, name the others
by what they change, describe each in one line with its cycle, recommend one, wait.

### 3. Complete → checkpoint

- Every clip of `Buddy.allClips`: states, still poses (`AnimationClip.still` of one of the clip's frames), escape,
  petting. Signs from `SheepSprites.Effect`.
- `BuddrTests/Sprite/<Name>SpritesTests.swift`: every grid valid against the palette; same-size checks only for
  literal grids that must match (e.g. two phases of an effect). `BuddyClipsTests` covers the shared rules by itself.
- `BuddrTests/Window/BuddyTurnsTests.swift`: `menuListsEveryBuddyByName` lists the menu order literally – add the
  buddy by its name.
- Docs: `README.md` (the "Buddy" setting), `CLAUDE.md` (the `Sprite/` line in "Structure"; a bullet in "Buddies" only
  for what is unusual about the buddy). `make screenshots` only if the README images change (they show the sheep and
  the menu with the chosen buddy).
- `make lint test` and `CONFIG=Release make build`.
- Render, check `frames.png` yourself, show the page, list what changed against the concept and what to look at
  (e.g. a jump between states). Iterate on the user's notes: edit, render, show.

### 4. Commit → when the user says so

One commit on `main`: "Add the <name>, a buddy of its own", a short body on the look and the idea. Don't push.
Suggest checking it live: `make run`, choose the buddy in the menu, play every clip from the DEBUG section.
