import Testing

@testable import Buddr

struct NamePlateSpriteTests {
    @Test func framesTheTextWithCutCorners() {
        typealias Plate = NamePlateSprite
        let sprite = Plate.sprite(for: NamePlate.Label(lead: "buddr", title: "", more: 0))
        #expect(sprite.width == PixelFont.width(of: "buddr") + 2 * Plate.paddingX)
        #expect(sprite.height == Plate.paddingTop + PixelFont.height + Plate.paddingBottom)
        let last = (x: sprite.width - 1, y: sprite.height - 1)
        for (x, y) in [(0, 0), (last.x, 0), (0, last.y), (last.x, last.y)] {
            #expect(sprite.color(x: x, y: y) == nil, "corner (\(x), \(y))")
        }
        #expect(sprite.color(x: 1, y: 0) == Plate.fill)
        #expect(sprite.color(x: 0, y: 1) == Plate.fill)
        // The stem of the "b" in the top-left corner of the text, the empty pixel next to it.
        #expect(sprite.color(x: Plate.paddingX, y: Plate.paddingTop) == Plate.text)
        #expect(sprite.color(x: Plate.paddingX + 1, y: Plate.paddingTop) == Plate.fill)
    }

    @Test func textThatFitsIsKept() {
        let plate = NamePlate.Label(lead: "buddr · ", title: "test123", more: 2)
        #expect(NamePlateSprite.text(for: plate) == "buddr · test123  +2")
    }

    @Test func textShortensOnlyTheTitle() {
        let plate = NamePlate.Label(lead: "Devbox · api · ", title: "Refactor the escape route", more: 2)
        let text = NamePlateSprite.text(for: plate, maxWidth: 120)
        #expect(text.hasPrefix("Devbox · api · Ref"))
        #expect(text.hasSuffix("…  +2"))
        #expect(PixelFont.width(of: text) <= 120)
    }

    @Test func textShortensAWholeTitleWithoutAPrefix() {
        let plate = NamePlate.Label(lead: "", title: "Refactor the escape route", more: 2)
        let text = NamePlateSprite.text(for: plate, maxWidth: 60)
        #expect(text.hasPrefix("Ref"))
        #expect(text.hasSuffix("…  +2"))
        #expect(PixelFont.width(of: text) <= 60)
    }

    @Test func textIsCutAtTheEndWhenThePrefixDoesNotFit() {
        let plate = NamePlate.Label(lead: "A very long machine label · workspace · ", title: "title", more: 3)
        let text = NamePlateSprite.text(for: plate, maxWidth: 60)
        #expect(text.hasPrefix("A very"))
        #expect(text.hasSuffix("…"))
        #expect(PixelFont.width(of: text) <= 60)
        // Without a title too, and nothing at all when not even "…" fits.
        let untitled = NamePlate.Label(lead: "A very long workspace", title: "", more: 0)
        #expect(NamePlateSprite.text(for: untitled, maxWidth: 40).hasSuffix("…"))
        #expect(NamePlateSprite.text(for: untitled, maxWidth: 2) == "")
    }
}
