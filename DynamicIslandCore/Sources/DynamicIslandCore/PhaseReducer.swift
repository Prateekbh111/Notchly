public enum PhaseReducer {
    public static func reduce(hovered: Bool, hasMedia: Bool, recentChange: Bool) -> Phase {
        if hovered { return .expanded }
        guard hasMedia else { return .idle }
        return recentChange ? .titleBanner : .compact
    }
}
