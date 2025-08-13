import Foundation

struct Comment: Identifiable, Codable {
    let id: UUID
    var spotId: UUID
    var userId: UUID
    var user: User?
    var body: String
    var attachments: [UUID]
    var parentId: UUID?
    var replies: [Comment]
    var voteCount: Int
    var createdAt: Date
    var updatedAt: Date
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}