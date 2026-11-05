// The black sheep: the sheep (`SheepSprites`) with dark wool and a light face and legs. Only the sheep itself is
// recolored; its effects ("!", the ✔ bubble, hearts, dust, flecks) keep their colors. It has no grids of its own, so
// redrawing the sheep redraws it too.

enum BlackSheepSprites {
    static let colors = [
        SheepSprites.palette["W"]!: PixelColor(red: 0x4A, green: 0x44, blue: 0x52),  // wool
        SheepSprites.palette["w"]!: PixelColor(red: 0x3B, green: 0x36, blue: 0x42),  // wool shade
        SheepSprites.palette["F"]!: PixelColor(red: 0x9C, green: 0x8F, blue: 0x9F),  // face and legs
    ]

    static let buddy = SheepSprites.buddy.replacingSprites(
        Dictionary(uniqueKeysWithValues: SheepSprites.figure.map { ($0, $0.recolored(colors)) }),
        id: .blackSheep, name: "Black Sheep")
}
