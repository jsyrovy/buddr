import Testing

@testable import Buddr

struct SheepSpritesTests {
    @Test func bodyVariantsShareTheirSize() {
        let bodies = [
            SheepSprites.Body.stand, SheepSprites.Body.trotA, SheepSprites.Body.trotB, SheepSprites.Body.gallop,
            SheepSprites.Body.jump, SheepSprites.Body.lying,
        ]
        #expect(Set(bodies.map(\.width)).count == 1)
        #expect(Set(bodies.map(\.height)).count == 1)
    }

    @Test func headVariantsShareTheirSize() {
        let heads = [
            SheepSprites.Head.normal, SheepSprites.Head.blink, SheepSprites.Head.look, SheepSprites.Head.bleat,
            SheepSprites.Head.content, SheepSprites.Head.yawn,
        ]
        #expect(Set(heads.map(\.width)).count == 1)
        #expect(Set(heads.map(\.height)).count == 1)
    }

    /// Only the sheep itself is recolored; the effects and the timing stay.
    @Test func blackSheepIsTheSheepWithItsFigureRecolored() {
        let sheep = BuddyID.sheep.buddy
        let blackSheep = BuddyID.blackSheep.buddy
        #expect(blackSheep.allClips.map(\.name) == sheep.allClips.map(\.name))
        var recolored = 0
        for (sheepClip, blackClip) in zip(sheep.allClips.map(\.clip), blackSheep.allClips.map(\.clip)) {
            #expect(blackClip.frames.map(\.duration) == sheepClip.frames.map(\.duration))
            for (sheepFrame, blackFrame) in zip(sheepClip.frames, blackClip.frames) {
                #expect(blackFrame.sprite.opacity == sheepFrame.sprite.opacity)
                #expect(blackFrame.sprite.layers.count == sheepFrame.sprite.layers.count)
                for (sheepLayer, blackLayer) in zip(sheepFrame.sprite.layers, blackFrame.sprite.layers) {
                    #expect(blackLayer.x == sheepLayer.x && blackLayer.y == sheepLayer.y)
                    if SheepSprites.figure.contains(sheepLayer.sprite) {
                        #expect(blackLayer.sprite != sheepLayer.sprite)
                        recolored += 1
                    } else {
                        #expect(blackLayer.sprite == sheepLayer.sprite)
                    }
                }
            }
        }
        #expect(recolored > 0)
        #expect(blackSheep.palette["W"] != sheep.palette["W"])
        #expect(blackSheep.palette["O"] == sheep.palette["O"])
    }
}
