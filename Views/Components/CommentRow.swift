import SwiftUI

struct CommentRow: View {
    let comment: Comment
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "person.circle.fill")
                .font(.title2)
                .foregroundColor(.gray)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("@\(comment.user?.handle ?? "anonymous")")
                        .font(.footnote)
                        .fontWeight(.semibold)
                    
                    Text(comment.timeAgo)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                
                Text(comment.body)
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
                
                HStack(spacing: 16) {
                    Button(action: {}) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up")
                                .font(.caption)
                            Text("\(comment.voteCount)")
                                .font(.caption)
                        }
                    }
                    .foregroundColor(.secondary)
                    
                    Button(action: {}) {
                        Text("Reply")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    CommentRow(comment: Comment(
        id: UUID(),
        spotId: UUID(),
        userId: UUID(),
        user: User(
            id: UUID(),
            handle: "photographer",
            name: "John Doe",
            email: "john@example.com",
            avatarUrl: nil,
            bio: nil,
            reputationScore: 100,
            homeRegion: nil,
            roles: [.user],
            badges: [],
            followersCount: 0,
            followingCount: 0,
            spotsCount: 0,
            createdAt: Date(),
            updatedAt: Date()
        ),
        body: "Amazing spot! The golden hour light here is absolutely perfect. Make sure to arrive at least 30 minutes before sunset to set up properly.",
        attachments: [],
        parentId: nil,
        replies: [],
        voteCount: 12,
        createdAt: Date().addingTimeInterval(-3600),
        updatedAt: Date()
    ))
    .padding()
}