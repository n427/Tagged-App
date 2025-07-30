import Foundation
import FirebaseFirestore

struct YearbookSection: Identifiable {
    var id: String { tag + startOfWeek.description }
    let tag: String
    let startOfWeek: Date
    var posts: [Post]
}

import FirebaseFirestore

class YearbookViewModel: ObservableObject {
    @Published var sections: [YearbookSection] = []
    @Published var isLoading = false

    func fetchPosts(for groupID: String) {
        isLoading = true

        Firestore.firestore().collection("Posts")
            .whereField("groupID", isEqualTo: groupID)
            .order(by: "createdAt", descending: true)
            .getDocuments { [weak self] snapshot, error in
                guard let docs = snapshot?.documents else { return }

                let posts: [Post] = docs.compactMap {
                    try? $0.data(as: Post.self)
                }

                var sectionDict: [String: YearbookSection] = [:]

                for post in posts {
                    let _ = post.publishedDate
                    let weekStart = post.publishedDate.startOfWeek()
                    let key = "\(post.tag)-\(weekStart)"


                    if sectionDict[key] == nil {
                        sectionDict[key] = YearbookSection(tag: post.tag, startOfWeek: weekStart, posts: [])
                    }

                    sectionDict[key]?.posts.append(post)
                }

                let sortedSections = sectionDict.values.sorted { $0.startOfWeek > $1.startOfWeek }
                DispatchQueue.main.async {
                    self?.sections = sortedSections
                    self?.isLoading = false
                }
            }
    }
}

extension Date {
    func startOfWeek() -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self))!
    }
}
