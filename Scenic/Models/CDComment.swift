import Foundation
import CoreData

@objc(CDComment)
public class CDComment: NSManagedObject {
    
}

extension CDComment {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDComment> {
        return NSFetchRequest<CDComment>(entityName: "CDComment")
    }
    
    @NSManaged public var id: UUID
    @NSManaged public var userId: UUID
    @NSManaged public var body: String
    @NSManaged public var attachmentsString: String // JSON encoded array
    @NSManaged public var parentId: UUID? // For nested comments
    @NSManaged public var repliesString: String // JSON encoded array of UUIDs
    @NSManaged public var voteCount: Int32
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
    
    // Server Sync Properties
    @NSManaged public var serverCommentId: String?
    @NSManaged public var lastSynced: Date?
    
    // Relationships
    @NSManaged public var spot: CDSpot?
}

extension CDComment {
    var attachments: [UUID] {
        get {
            guard !attachmentsString.isEmpty,
                  let data = attachmentsString.data(using: .utf8),
                  let attachments = try? JSONDecoder().decode([UUID].self, from: data) else {
                return []
            }
            return attachments
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let string = String(data: data, encoding: .utf8) {
                attachmentsString = string
            } else {
                attachmentsString = "[]"
            }
        }
    }
    
    var replies: [UUID] {
        get {
            guard !repliesString.isEmpty,
                  let data = repliesString.data(using: .utf8),
                  let replies = try? JSONDecoder().decode([UUID].self, from: data) else {
                return []
            }
            return replies
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let string = String(data: data, encoding: .utf8) {
                repliesString = string
            } else {
                repliesString = "[]"
            }
        }
    }
    
    func toComment() -> Comment {
        Comment(
            id: id,
            spotId: spot?.id ?? UUID(),
            userId: userId,
            body: body,
            attachments: attachments,
            parentId: parentId,
            replies: [], // Reply objects would be loaded separately to avoid circular dependencies
            voteCount: Int(voteCount),
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    
    func updateFromComment(_ comment: Comment) {
        id = comment.id
        userId = comment.userId
        body = comment.body
        attachments = comment.attachments
        parentId = comment.parentId
        replies = comment.replies.map { $0.id } // Extract IDs from reply Comment objects
        voteCount = Int32(comment.voteCount)
        createdAt = comment.createdAt
        updatedAt = comment.updatedAt
    }
    
    static func fromComment(_ comment: Comment, in context: NSManagedObjectContext) -> CDComment {
        let cdComment = CDComment(context: context)
        cdComment.updateFromComment(comment)
        return cdComment
    }
}