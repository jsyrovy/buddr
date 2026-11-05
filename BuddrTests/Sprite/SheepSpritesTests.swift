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
}
