import Foundation

struct User: Identifiable, Codable {
    let id: UUID
    var handle: String
    var name: String
    var email: String
    var avatarUrl: String?
    var bio: String?
    var reputationScore: Int
    var homeRegion: String?
    var roles: [UserRole]
    var badges: [Badge]
    var followersCount: Int
    var followingCount: Int
    var spotsCount: Int
    var createdAt: Date
    var updatedAt: Date
    
    enum UserRole: String, Codable {
        case guest
        case user
        case moderator
        case admin
        case verified
    }
}

struct Badge: Identifiable, Codable {
    let id: UUID
    var code: String
    var name: String
    var description: String
    var iconName: String
    var awardedAt: Date?
}