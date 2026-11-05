/// The canvas every buddy is drawn on. It is the same for all of them, so switching buddies never changes the size of
/// the panel, its saved position, the room kept for the name plate or the escape route.
enum BuddyCanvas {
    /// Size in pixels: the buddy plus room for effects above and behind it.
    static let width = 22
    static let height = 20
    /// Opacity of the whole picture while the state is unknown.
    static let unknownOpacity = 0.45
}
