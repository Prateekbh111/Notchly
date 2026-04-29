public enum PhaseReducer {
    public static func reduce(hovered: Bool, hasMedia: Bool) -> Phase {
        if hovered { return .expanded }
        return hasMedia ? .compact : .idle
    }
}
