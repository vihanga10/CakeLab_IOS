import Foundation
import FirebaseFirestore
import Combine


@MainActor
final class BakerPortfolioViewModel: ObservableObject {
    @Published var works: [PortfolioWork] = []
    @Published var publishedWorkIDs: Set<String> = []
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage = ""

    let user: AppUser
    private let db = Firestore.firestore()

    init(user: AppUser) {
        self.user = user
    }

    func loadPortfolio() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let artisanSnapshot = try await db.collection("artisans").document(user.id).getDocument()
            let artisanData = artisanSnapshot.data() ?? [:]
            let publishedIDs = artisanData["portfolioPublishedWorkIDs"] as? [String] ?? []

            let snapshot = try await db.collection("artisans")
                .document(user.id)
                .collection("portfolioWorks")
                .order(by: "updatedAt", descending: true)
                .getDocuments()

            let loadedWorks = snapshot.documents.compactMap(PortfolioWork.init(document:))
            let validPublishedIDs = Set(publishedIDs.filter { workID in
                loadedWorks.contains(where: { $0.id == workID })
            })

            works = loadedWorks
            publishedWorkIDs = validPublishedIDs

            if Set(publishedIDs) != validPublishedIDs {
                try await persistPublishedSelection()
            }
        } catch {
            errorMessage = "Failed to load portfolio: \(error.localizedDescription)"
        }
    }

    // Creates a new portfolio work document or updates an existing one.
    @discardableResult
    func saveWork(from draft: PortfolioWorkDraft, editingWorkID: String?) async -> Bool {
        errorMessage = ""
        let trimmedTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = draft.description.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedTraits = draft.traits.compactMap { trait -> PortfolioTrait? in
            let trimmedName = trait.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else { return nil }
            return PortfolioTrait(id: trait.id, name: trimmedName, score: min(max(trait.score, 0), 100))
        }

        guard !trimmedTitle.isEmpty else {
            errorMessage = "Please enter a title for this work."
            return false
        }

        guard !draft.imageBase64.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please add a photo for this work."
            return false
        }

        isSaving = true
        defer { isSaving = false }

        let now = Timestamp(date: Date())
        let workID = editingWorkID ?? UUID().uuidString
        let document = db.collection("artisans")
            .document(user.id)
            .collection("portfolioWorks")
            .document(workID)

        do {
            var payload: [String: Any] = [
                "title": trimmedTitle,
                "description": trimmedDescription,
                "imageBase64": draft.imageBase64,
                "traits": cleanedTraits.map(\.firestoreData),
                "updatedAt": now
            ]

            if editingWorkID == nil {
                payload["createdAt"] = now
            }

            try await document.setData(payload, merge: true)
            await loadPortfolio()

            if publishedWorkIDs.contains(workID) {
                try await persistPublishedSelection()
            }

            await NotificationManager.scheduleLocalNotification(
                title: "Portfolio",
                body: "Portfolio work added",
                identifier: "portfolio-work-added-\(UUID().uuidString)"
            )
            return true
        } catch {
            errorMessage = "Failed to save portfolio work: \(error.localizedDescription)"
            return false
        }
    }

    // Deletes the portfolio work document and removes it from the published selection.
    func deleteWork(_ work: PortfolioWork) async {
        isSaving = true
        defer { isSaving = false }

        do {
            try await db.collection("artisans")
                .document(user.id)
                .collection("portfolioWorks")
                .document(work.id)
                .delete()

            publishedWorkIDs.remove(work.id)
            works.removeAll { $0.id == work.id }
            try await persistPublishedSelection()
        } catch {
            errorMessage = "Failed to delete portfolio work: \(error.localizedDescription)"
        }
    }

    /// Adds or removes `work` from the published set.
    func togglePublished(for work: PortfolioWork) async {
        errorMessage = ""
        let isCurrentlyPublished = publishedWorkIDs.contains(work.id)

        if isCurrentlyPublished {
            publishedWorkIDs.remove(work.id)
        } else {
            guard publishedWorkIDs.count < 6 else {
                errorMessage = "You can publish up to 6 works in your profile."
                return
            }
            publishedWorkIDs.insert(work.id)
        }

        do {
            try await persistPublishedSelection()
            await NotificationManager.scheduleLocalNotification(
                title: "Portfolio",
                body: isCurrentlyPublished ? "Removed from Profile Portfolio" : "Published to Profile Portfolio",
                identifier: "portfolio-publish-\(UUID().uuidString)"
            )
        } catch {
            if isCurrentlyPublished {
                publishedWorkIDs.insert(work.id)
            } else {
                publishedWorkIDs.remove(work.id)
            }
            errorMessage = "Failed to update published works: \(error.localizedDescription)"
        }
    }

    /// Returns only the works currently in the published set.
    var publishedWorks: [PortfolioWork] {
        works.filter { publishedWorkIDs.contains($0.id) }
    }

    private func persistPublishedSelection() async throws {
        let orderedPublishedWorks = publishedWorks
        let publishedIDs = orderedPublishedWorks.map(\.id)

        try await db.collection("artisans").document(user.id).setData([
            "portfolioPublishedWorkIDs": publishedIDs,
            "portfolioPublishedWorks": FieldValue.delete(),
            "portfolioImages": FieldValue.delete(),
            "portfolioUpdatedAt": Timestamp(date: Date())
        ], merge: true)

        let batch = db.batch()
        for work in works {
            let ref = db.collection("artisans")
                .document(user.id)
                .collection("portfolioWorks")
                .document(work.id)
            batch.setData(["isPublished": publishedIDs.contains(work.id)], forDocument: ref, merge: true)
        }
        try await batch.commit()
        NotificationCenter.default.post(name: Notification.Name("bakerPortfolioDidChange"), object: nil)
    }
}
