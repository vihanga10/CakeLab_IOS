import SwiftUI

// MARK: - Crafter/Baker Home View
@MainActor
struct CrafterHomeView: View {
    let user: AppUser
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.white
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // MARK: - Header Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Good Morning")
                                .font(.urbanistRegular(14))
                                .foregroundColor(.cakeGrey)
                            
                            Text(user.name.isEmpty ? "Baker" : "Baker \(user.name)")
                                .font(.urbanistSemiBold(18))
                                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                            
                            Text("Manage your cakes and orders")
                                .font(.urbanistRegular(13))
                                .foregroundColor(.cakeGrey)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 24)
                        
                        // MARK: - Quick Stats
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                // Pending Orders
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("3")
                                        .font(.urbanistBold(28))
                                        .foregroundColor(.cakeBrown)
                                    
                                    Text("Pending Orders")
                                        .font(.urbanistRegular(12))
                                        .foregroundColor(.cakeGrey)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .background(Color.cakeBrown.opacity(0.08))
                                .cornerRadius(12)
                                
                                // Active Listings
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("7")
                                        .font(.urbanistBold(28))
                                        .foregroundColor(.cakeBrown)
                                    
                                    Text("Active Listings")
                                        .font(.urbanistRegular(12))
                                        .foregroundColor(.cakeGrey)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .background(Color.cakeBrown.opacity(0.08))
                                .cornerRadius(12)
                            }
                            
                            // Earnings card
                            HStack(alignment: .center, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("This Month Earnings")
                                        .font(.urbanistRegular(12))
                                        .foregroundColor(.cakeGrey)
                                    
                                    Text("Rs. 45,250")
                                        .font(.urbanistBold(20))
                                        .foregroundColor(.cakeBrown)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.system(size: 24))
                                    .foregroundColor(.cakeBrown)
                            }
                            .padding(16)
                            .background(Color(red: 0.94, green: 0.90, blue: 0.85))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 28)
                        
                        // MARK: - Quick Actions
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Quick Actions")
                                .font(.urbanistBold(16))
                                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                                .padding(.horizontal, 20)
                            
                            VStack(spacing: 10) {
                                ActionButton(
                                    icon: "plus.circle.fill",
                                    title: "Add New Cake Design",
                                    action: { print("Add new cake") }
                                )
                                
                                ActionButton(
                                    icon: "cart.fill",
                                    title: "View Pending Orders",
                                    action: { print("View orders") }
                                )
                                
                                ActionButton(
                                    icon: "chart.bar.fill",
                                    title: "Analytics & Reports",
                                    action: { print("Analytics") }
                                )
                                
                                ActionButton(
                                    icon: "person.circle.fill",
                                    title: "Profile & Settings",
                                    action: { print("Settings") }
                                )
                            }
                            .padding(.horizontal, 20)
                        }
                        .padding(.bottom, 28)
                        
                        // MARK: - Recent Orders
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Recent Orders")
                                    .font(.urbanistBold(16))
                                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                                
                                Spacer()
                                
                                Button {} label: {
                                    Text("See all")
                                        .font(.urbanistSemiBold(12))
                                        .foregroundColor(.cakeBrown)
                                }
                            }
                            .padding(.horizontal, 20)
                            
                            VStack(spacing: 10) {
                                ForEach([
                                    (order: "ORD-1001", customer: "Sarah Ahmed", cake: "3D Wedding Cake", status: "In Progress"),
                                    (order: "ORD-1002", customer: "John Smith", cake: "Chocolate Cupcakes", status: "Completed"),
                                    (order: "ORD-1003", customer: "Emma Wilson", cake: "Birthday Cake", status: "Pending Approval")
                                ], id: \.order) { order in
                                    RecentOrderCard(
                                        orderID: order.order,
                                        customer: order.customer,
                                        cake: order.cake,
                                        status: order.status
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        .padding(.bottom, 28)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
        }
    }
}

// MARK: - Action Button Component
struct ActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.cakeBrown)
                
                Text(title)
                    .font(.urbanistSemiBold(14))
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.cakeGrey)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color(red: 0.98, green: 0.98, blue: 0.98))
            .cornerRadius(12)
        }
    }
}

// MARK: - Recent Order Card Component
struct RecentOrderCard: View {
    let orderID: String
    let customer: String
    let cake: String
    let status: String
    
    var statusColor: Color {
        switch status {
        case "In Progress":
            return Color(red: 1.0, green: 0.6, blue: 0.2)
        case "Completed":
            return Color(red: 0.2, green: 0.8, blue: 0.4)
        case "Pending Approval":
            return Color(red: 0.8, green: 0.2, blue: 0.2)
        default:
            return .cakeGrey
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(orderID)
                        .font(.urbanistBold(14))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                    
                    Text(customer)
                        .font(.urbanistRegular(12))
                        .foregroundColor(.cakeGrey)
                }
                
                Spacer()
                
                Text(status)
                    .font(.urbanistSemiBold(10))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(statusColor)
                    .cornerRadius(8)
            }
            
            Text(cake)
                .font(.urbanistRegular(12))
                .foregroundColor(.cakeGrey)
        }
        .padding(12)
        .background(Color(red: 0.98, green: 0.98, blue: 0.98))
        .cornerRadius(12)
    }
}

#Preview {
    CrafterHomeView(user: AppUser.mockBaker)
}
