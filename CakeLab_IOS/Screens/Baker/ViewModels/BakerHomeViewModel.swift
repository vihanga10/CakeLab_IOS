import UIKit
import Combine
import FirebaseFirestore
import FirebaseAuth

// MARK: - BakerHomeViewModel
/// Loads live stats, profile avatar, baker city, active orders, and earnings for BakerHomeView.
@MainActor
final class BakerHomeViewModel: ObservableObject {
    @Published var profileAvatar: UIImage?
    @Published var bakerCity: String = ""
    @Published var activeOrdersList: [CakeOrder] = []
    @Published var upcomingDeliveriesCount: Int = 0
    @Published var earningsThisMonth: String = "LKR 0"
    @Published var isLoadingStats: Bool = false

    private let db = Firestore.firestore()

    func loadProfileAvatar(userID: String) {
        if let base64String = UserDefaults.standard.string(forKey: "profileAvatar_\(userID)"),
           let imageData = Data(base64Encoded: base64String),
           let image = UIImage(data: imageData) {
            profileAvatar = image
            return
        }
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Task {
            do {
                let doc = try await db.collection("artisans").document(uid).getDocument()
                if let base64 = doc.data()?["profileImageBase64"] as? String, !base64.isEmpty {
                    let payload: String
                    if let comma = base64.firstIndex(of: ",") {
                        payload = String(base64[base64.index(after: comma)...])
                    } else {
                        payload = base64
                    }
                    if let data = Data(base64Encoded: payload), let image = UIImage(data: data) {
                        profileAvatar = image
                        UserDefaults.standard.set(base64, forKey: "profileAvatar_\(userID)")
                    }
                }
            } catch {
                print("Failed to load baker profile image: \(error)")
            }
        }
    }

    func loadBakerCity() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Task {
            do {
                let doc = try await db.collection("artisans").document(uid).getDocument()
                if let city = doc.data()?["city"] as? String, !city.isEmpty {
                    bakerCity = city
                }
            } catch {
                print("Failed to load baker city: \(error)")
            }
        }
    }

    func loadLiveStats() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        isLoadingStats = true
        await loadActiveOrders(bakerUID: uid)
        await loadEarningsThisMonth(bakerUID: uid)
        isLoadingStats = false
    }

    // MARK: - Private Loaders

    private func loadActiveOrders(bakerUID: String) async {
        let statuses = ["confirmed", "baking", "decorating", "quality_check"]
        var seen = Set<String>()
        var orders: [CakeOrder] = []
        do {
            for key in ["artisanId", "bakerID", "bakerId"] {
                let snap = try await db.collection("orders")
                    .whereField(key, isEqualTo: bakerUID)
                    .whereField("status", in: statuses)
                    .getDocuments()
                for doc in snap.documents {
                    guard !seen.contains(doc.documentID),
                          let order = CakeOrder(document: doc) else { continue }
                    seen.insert(doc.documentID)
                    orders.append(order)
                }
            }
        } catch {
            print("BakerHome: active orders error – \(error.localizedDescription)")
        }
        activeOrdersList = orders.sorted { $0.deliveryDate < $1.deliveryDate }
        upcomingDeliveriesCount = min(5, activeOrdersList.count)
    }

    private func loadEarningsThisMonth(bakerUID: String) async {
        let cal = Calendar.current
        let now = Date()
        let thisMonthStart = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now
        let nextMonthStart = cal.date(byAdding: .month, value: 1, to: thisMonthStart) ?? now
        var total: Double = 0

        do {
            let snap = try await db.collection("payments")
                .whereField("bakerId", isEqualTo: bakerUID)
                .getDocuments()

            total = snap.documents.reduce(0) { runningTotal, doc in
                let data = doc.data()
                let status = (data["status"] as? String ?? "success").lowercased()
                let paidAt = (data["createdAt"] as? FirebaseFirestore.Timestamp)?.dateValue() ?? Date.distantPast
                guard status == "success",
                      paidAt >= thisMonthStart,
                      paidAt < nextMonthStart else {
                    return runningTotal
                }
                return runningTotal + parseMoneyValue(data["amount"])
            }
        } catch {
            print("BakerHome: earnings error – \(error.localizedDescription)")
        }

        if total >= 1_000_000 {
            earningsThisMonth = String(format: "LKR %.1fM", total / 1_000_000)
        } else if total >= 1_000 {
            earningsThisMonth = String(format: "LKR %.0fK", total / 1_000)
        } else {
            earningsThisMonth = String(format: "LKR %.0f", total)
        }
    }

    private func parseMoneyValue(_ value: Any?) -> Double {
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        if let value = value as? NSNumber { return value.doubleValue }
        if let value = value as? String {
            let cleaned = value.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            return Double(cleaned) ?? 0
        }
        return 0
    }
}
