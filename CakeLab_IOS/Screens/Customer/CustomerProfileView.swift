import SwiftUI

// MARK: - Customer Profile View
struct CustomerProfileView: View {
    let user: AppUser
    @State private var showSignOutAlert = false

    private let menuItems: [(icon: String, title: String, color: Color)] = [
        ("person.fill",           "Edit Profile",      Color(red: 93/255, green: 55/255, blue: 20/255)),
        ("mappin.circle.fill",    "My Addresses",      Color(red: 93/255, green: 55/255, blue: 20/255)),
        ("creditcard.fill",       "Payment Methods",   Color(red: 93/255, green: 55/255, blue: 20/255)),
        ("bell.badge.fill",       "Notifications",     Color(red: 93/255, green: 55/255, blue: 20/255)),
        ("questionmark.circle.fill", "Help & Support", Color(red: 93/255, green: 55/255, blue: 20/255)),
        ("doc.text.fill",         "Privacy Policy",    Color(red: 93/255, green: 55/255, blue: 20/255))
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.97, green: 0.97, blue: 0.97).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {

                        // ── Avatar & Name ──────────────────────────────────
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color(red: 0.90, green: 0.86, blue: 0.82))
                                    .frame(width: 90, height: 90)
                                Image(systemName: "person.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.cakeBrown)

                                // Edit button overlay
                                VStack {
                                    Spacer()
                                    HStack {
                                        Spacer()
                                        ZStack {
                                            Circle()
                                                .fill(Color.cakeBrown)
                                                .frame(width: 26, height: 26)
                                            Image(systemName: "camera.fill")
                                                .font(.system(size: 11))
                                                .foregroundColor(.white)
                                        }
                                        .offset(x: 4, y: 4)
                                    }
                                }
                                .frame(width: 90, height: 90)
                            }

                            Text(user.name.isEmpty ? "Vihanga Madushamini" : user.name)
                                .font(.urbanistBold(18))
                                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

                            Text(user.email)
                                .font(.urbanistRegular(13))
                                .foregroundColor(.cakeGrey)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                        .padding(.horizontal, 16)

                        // ── Menu Items ─────────────────────────────────────
                        VStack(spacing: 0) {
                            ForEach(Array(menuItems.enumerated()), id: \.offset) { idx, item in
                                Button {} label: {
                                    HStack(spacing: 14) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.cakeBrown.opacity(0.10))
                                                .frame(width: 38, height: 38)
                                            Image(systemName: item.icon)
                                                .font(.system(size: 16))
                                                .foregroundColor(.cakeBrown)
                                        }
                                        Text(item.title)
                                            .font(.urbanistMedium(14))
                                            .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.15))
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(Color(red: 0.7, green: 0.7, blue: 0.7))
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                }

                                if idx < menuItems.count - 1 {
                                    Divider()
                                        .padding(.leading, 68)
                                }
                            }
                        }
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                        .padding(.horizontal, 16)

                        // ── Sign Out ───────────────────────────────────────
                        Button { showSignOutAlert = true } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(red: 0.85, green: 0.2, blue: 0.2))
                                Text("Sign Out")
                                    .font(.urbanistSemiBold(15))
                                    .foregroundColor(Color(red: 0.85, green: 0.2, blue: 0.2))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color(red: 0.85, green: 0.2, blue: 0.2).opacity(0.08))
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color(red: 0.85, green: 0.2, blue: 0.2).opacity(0.3), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                    .padding(.top, 16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("My Profile")
                        .font(.urbanistBold(18))
                        .foregroundColor(Color(red: 93/255, green: 55/255, blue: 20/255))
                }
            }
            .alert("Sign Out", isPresented: $showSignOutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    try? AuthService().signOut()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }
}

#Preview {
    CustomerProfileView(user: AppUser.mock)
}
