/// When the sheep moves. Without animation it shows a still pose of its state.
enum AnimationMode: String, CaseIterable, Sendable {
    /// Always a still pose.
    case off
    /// Animated for a while after the state changed or another agent started waiting for the user, then still.
    case onChange
    /// Always animated.
    case always
}
