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
                isMatchingRequest(request, with: bakerSpecialties)
            }
            
            print("✅ Matching requests filtered: \(self.matchingRequests.count) out of \(allRequests.count)")
            
        } catch {
            errorMessage = "Failed to load matching requests: \(error.localizedDescription)"
            print("❌ Error loading matching requests: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    // MARK: - Filter Logic: Check if request matches baker's specialties
    private func isMatchingRequest(_ request: CakeRequestRecord, with specialties: [String]) -> Bool {
        // Check if any of the request categories match any baker specialty
        // Categories can be in both `category` and `categories` array
        
        let requestCategories = request.categories.isEmpty ? [request.category] : request.categories
        
        for requestCategory in requestCategories {
            // Normalize for comparison (lowercase, trim whitespace)
            let normalizedRequestCategory = requestCategory
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            
            for specialty in specialties {
                let normalizedSpecialty = specialty
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                
                // Check if they match exactly or contain each other (partial matches)
                if normalizedRequestCategory == normalizedSpecialty ||
                   normalizedRequestCategory.contains(normalizedSpecialty) ||
                   normalizedSpecialty.contains(normalizedRequestCategory) {
                    return true
                }
            }
        }
        
        return false
    }
}
