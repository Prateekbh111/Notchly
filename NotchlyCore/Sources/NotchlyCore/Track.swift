import Foundation

public struct Track: Equatable, Sendable {
    public let title: String
    public let artist: String
    public let album: String?
    public let artwork: Data?
    public let duration: TimeInterval

    public init(title: String, artist: String, album: String?, artwork: Data?, duration: TimeInterval) {
        self.title = title
        self.artist = artist
        self.album = album
        self.artwork = artwork
        self.duration = duration
    }
}
