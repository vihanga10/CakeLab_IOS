import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth

// MARK: - Baker Matching Requests ViewModel
@MainActor
final class BakerMatchingRequestsViewModel: ObservableObject {
    
    @Published var matchingRequests: [CakeRequestRecord] = []
    @Published var allPublishedRequests: [CakeRequestRecord] = []
    @Published var bakerSpecialties: [String] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private var bakerUID: String {
        Auth.auth().currentUser?.uid ?? ""
    }
    
    // MARK: - Fetch Baker Specialties & Matching Requests
    func loadMatchingRequests() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Step 1: Fetch baker's specialties from artisans collection
            let bakerDoc = try await db.collection("artisans").document(bakerUID).getDocument()
            guard let data = bakerDoc.data() else {
                errorMessage = "Baker profile not found. Please complete your profile first."
                isLoading = false
                return
            }
            
            self.bakerSpecialties = data["specialties"] as? [String] ?? []
            
            if bakerSpecialties.isEmpty {
                errorMessage = "Please add specialties to your profile first."
                isLoading = false
                return
            }
            
            print("🎂 DEBUG: Baker specialties loaded: \(bakerSpecialties)")
            
            // Step 2: Fetch all published requests (status == "open")
            let snapshot = try await db.collection("cakeRequests")
                .whereField("status", isEqualTo: "open")
                .getDocuments()
            
            let allRequests = snapshot.documents
                .compactMap(CakeRequestRecord.init(document:))
                .sorted { $0.createdAt > $1.createdAt }
            self.allPublishedRequests = allRequests
            
            // Step 3: Filter requests that match baker's specialties
            self.matchingRequests = allRequests.filter { request in
                matchesAnySpecialty(request: request, specialties: bakerSpecialties)
            }
            
            print("✅ Matching requests filtered: \(self.matchingRequests.count) out of \(allRequests.count)")
            
        } catch {
            errorMessage = "Failed to load matching requests: \(error.localizedDescription)"
            print("❌ Error loading matching requests: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    // MARK: - Filter Logic
    func matches(request: CakeRequestRecord, specialty: String) -> Bool {
        let normalizedSpecialty = normalizedCategory(specialty)
        guard !normalizedSpecialty.isEmpty else { return false }

        return requestCategories(for: request).contains { normalizedCategory($0) == normalizedSpecialty }
    }

    private func matchesAnySpecialty(request: CakeRequestRecord, specialties: [String]) -> Bool {
        let normalizedSpecialties = Set(specialties.map(normalizedCategory).filter { !$0.isEmpty })
        guard !normalizedSpecialties.isEmpty else { return false }

        let requestSet = Set(requestCategories(for: request).map(normalizedCategory).filter { !$0.isEmpty })
        return !requestSet.isDisjoint(with: normalizedSpecialties)
    }

    private func requestCategories(for request: CakeRequestRecord) -> [String] {
        let categoryList = request.categories.isEmpty ? [request.category] : request.categories
        if categoryList.isEmpty, !request.displayCategory.isEmpty {
            return [request.displayCategory]
        }
        return categoryList
    }

    private func normalizedCategory(_ raw: String) -> String {
        let cleaned = raw
            .lowercased()
            .replacingOccurrences(of: "&", with: " and ")
            .replacingOccurrences(of: "cakes", with: "")
            .replacingOccurrences(of: "cake", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
