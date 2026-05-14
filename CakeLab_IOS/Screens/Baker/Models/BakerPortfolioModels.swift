import Foundation
import FirebaseFirestore

// MARK: - PortfolioWork

struct PortfolioWork: Identifiable, Hashable {
    let id: String
    let title: String
    let description: String
    let imageBase64: String
    let traits: [PortfolioTrait]
    let createdAt: Date
    let updatedAt: Date

    init(
        id: String,
        title: String,
        description: String,
        imageBase64: String,
        traits: [PortfolioTrait],
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.imageBase64 = imageBase64
        self.traits = traits
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init?(document: QueryDocumentSnapshot) {
        let data = document.data()
        let title = (data["title"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let imageBase64 = data["imageBase64"] as? String ?? ""
        guard !title.isEmpty, !imageBase64.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }

        let traitsData = data["traits"] as? [[String: Any]] ?? []
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? createdAt

        self.init(
            id: document.documentID,
            title: title,
            description: (data["description"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            imageBase64: imageBase64,
            traits: traitsData.compactMap(PortfolioTrait.init(dictionary:)),
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    /// Summary dictionary 
    var publishedSummary: [String: Any] {
        [
            "workID": id,
            "title": title,
            "description": description,
            "imageBase64": imageBase64,
            "traits": traits.map(\.firestoreData),
            "updatedAt": Timestamp(date: updatedAt)
        ]
    }
}

// MARK: - Portfolio Trait
struct PortfolioTrait: Identifiable, Hashable {
    let id: String
    let name: String
    let score: Int

    init(id: String = UUID().uuidString, name: String, score: Int) {
        self.id = id
        self.name = name
        self.score = score
    }

    nonisolated init?(dictionary: [String: Any]) {
        let name = (dictionary["name"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        self.id = dictionary["id"] as? String ?? UUID().uuidString
        self.name = name
        if let score = dictionary["score"] as? Int {
            self.score = score
        } else if let score = dictionary["score"] as? Double {
            self.score = Int(score.rounded())
        } else {
            self.score = 0
        }
    }

    var firestoreData: [String: Any] {
        [
            "id": id,
            "name": name,
            "score": score
        ]
    }
}

// MARK: - Portfolio Work Draft
struct PortfolioWorkDraft {
    var title: String
    var description: String
    var imageBase64: String
    var traits: [PortfolioTraitDraft]

    static let empty = PortfolioWorkDraft(
        title: "",
        description: "",
        imageBase64: "",
        traits: [
            PortfolioTraitDraft(name: "Creativity", score: 88),
            PortfolioTraitDraft(name: "Finishing", score: 92)
        ]
    )

    init(title: String, description: String, imageBase64: String, traits: [PortfolioTraitDraft]) {
        self.title = title
        self.description = description
        self.imageBase64 = imageBase64
        self.traits = traits
    }

    init(work: PortfolioWork) {
        self.title = work.title
        self.description = work.description
        self.imageBase64 = work.imageBase64
        self.traits = work.traits.map { PortfolioTraitDraft(id: $0.id, name: $0.name, score: $0.score) }
    }
}

// MARK: - Portfolio Trait Draft
struct PortfolioTraitDraft: Identifiable {
    let id: String
    var name: String
    var score: Int

    init(id: String = UUID().uuidString, name: String = "", score: Int = 80) {
        self.id = id
        self.name = name
        self.score = score
    }
}
