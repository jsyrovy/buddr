#if DEBUG
    extension SheepSprites {
        /// A second buddy to try out choosing buddies before there is a real one: the sheep with dark wool and light
        /// legs; the effects keep their colors. Debug builds only.
        static let blackSheep = buddy.recolored(
            id: .blackSheep, name: "Black Sheep",
            colors: [
                palette["W"]!: PixelColor(red: 0x4A, green: 0x44, blue: 0x52),
                palette["w"]!: PixelColor(red: 0x3B, green: 0x36, blue: 0x42),
                palette["F"]!: PixelColor(red: 0x9C, green: 0x8F, blue: 0x9F),
            ],
            in: [
                Body.stand, Body.trotA, Body.trotB, Body.gallop, Body.jump, Body.lying, Head.normal, Head.blink,
                Head.look, Head.bleat, Head.content, Head.yawn,
            ])
    }

    extension Buddy {
        /// The same buddy under another name, with `colors` replaced in the layers showing one of `sprites`, and in
        /// the palette.
        func recolored(
            id: BuddyID, name: String, colors: [PixelColor: PixelColor], in sprites: Set<PixelSprite>
        ) -> Buddy {
            let recolor = { (clip: AnimationClip) in clip.recolored(colors, in: sprites) }
            return Buddy(
                id: id, name: name,
                clips: Clips(
                    idleRest: recolor(clips.idleRest), idleBlink: recolor(clips.idleBlink),
                    idleLook: recolor(clips.idleLook), sleeping: recolor(clips.sleeping),
                    working: recolor(clips.working), blocked: recolor(clips.blocked),
                    doneJump: recolor(clips.doneJump), doneHold: recolor(clips.doneHold),
                    unknown: recolor(clips.unknown), idleStill: recolor(clips.idleStill),
                    sleepingStill: recolor(clips.sleepingStill), workingStill: recolor(clips.workingStill),
                    blockedStill: recolor(clips.blockedStill), doneStill: recolor(clips.doneStill),
                    unknownStill: recolor(clips.unknownStill)),
                escape: Escape(
                    startle: recolor(escape.startle), yawn: recolor(escape.yawn), turn: recolor(escape.turn),
                    run: recolor(escape.run), walk: recolor(escape.walk), arrive: recolor(escape.arrive)),
                petted: recolor(petted), grids: grids, palette: palette.mapValues { colors[$0] ?? $0 })
        }
    }

    extension AnimationClip {
        fileprivate func recolored(_ colors: [PixelColor: PixelColor], in sprites: Set<PixelSprite>) -> AnimationClip {
            AnimationClip(
                frames.map { frame in
                    let layers = frame.sprite.layers.map { layer in
                        sprites.contains(layer.sprite)
                            ? SpriteLayer(sprite: layer.sprite.recolored(colors), x: layer.x, y: layer.y) : layer
                    }
                    return AnimationFrame(
                        sprite: SpriteFrame(layers: layers, opacity: frame.sprite.opacity), duration: frame.duration)
                })
        }
    }

    extension PixelSprite {
        fileprivate func recolored(_ colors: [PixelColor: PixelColor]) -> PixelSprite {
            let pixels = (0..<height).flatMap { y in
                (0..<width).map { x in color(x: x, y: y).map { colors[$0] ?? $0 } }
            }
            return PixelSprite(width: width, height: height, pixels: pixels)
        }
    }
#endif
