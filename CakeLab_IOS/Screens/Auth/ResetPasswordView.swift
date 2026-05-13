import SwiftUI
import Combine

// MARK: - Reset Password ViewModel
@MainActor
final class ResetPasswordViewModel: ObservableObject {
    @Published var currentPassword   = ""
    @Published var newPassword      = ""
    @Published var confirmPassword  = ""
    @Published var isLoading        = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var didReset         = false
    @Published var email: String = ""
    
    private let authService = AuthService()

    func changePassword() {
        errorMessage = nil
        successMessage = nil
        guard !currentPassword.isEmpty else { errorMessage = "Please enter your current password."; return }
        guard !newPassword.isEmpty else { errorMessage = "Please enter a new password."; return }
        guard newPassword.count >= 6 else { errorMessage = "Password must be at least 6 characters."; return }
        guard newPassword == confirmPassword else { errorMessage = "Passwords do not match."; return }
        
        isLoading = true
        
        Task {
            do {
                print("🔐 DEBUG: Changing password for email: \(email)")
                
                // Update password with re-authentication
                try await authService.updatePassword(
                    newPassword: newPassword,
                    currentEmail: email,
                    currentPassword: currentPassword
                )
                
                print("✅ DEBUG: Password updated successfully")
                
                successMessage = "Password changed. Please sign in again."
                didReset = true
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
                print("❌ ERROR: Password update failed - \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Reset Password View
@MainActor
struct ResetPasswordView: View {

    let email: String
    let onPasswordChanged: () -> Void
    @StateObject private var vm      = ResetPasswordViewModel()
    @State private var showCurrent   = false
    @State private var showNew       = false
    @State private var showConfirm   = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        resetPasswordContent
            .onAppear {
                vm.email = email
            }
            .onChange(of: vm.didReset) { _, didReset in
                guard didReset else { return }

                Task {
                    await NotificationManager.scheduleLocalNotification(
                        title: "Password Changed",
                        body: "Your CakeLab password was updated successfully.",
                        identifier: "password-changed-\(email.lowercased())",
                        replacePrevious: true
                    )

                    try? await Task.sleep(nanoseconds: 600_000_000)
                    dismiss()
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    onPasswordChanged()
                }
            }
    }

    private var resetPasswordContent: some View {
        GeometryReader { geo in
            ZStack {
                Color.white
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.cakeBrown)
                        }
                        .accessibilityLabel("Back")
                        Spacer()
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 16)
                    .padding(.bottom, 24)

                    ScrollView {
                        VStack(alignment: .center, spacing: 0) {
                            Image("password")
                                .resizable()
                                .scaledToFit()
                                .padding(20)
                                .frame(
                                    width: min(geo.size.width - 40, 350),
                                    height: min(max(geo.size.height * 0.30, 220), 300)
                                )
                                .padding(.bottom, 28)

                            VStack(alignment: .leading, spacing: 0) {
                                Text("RESET PASSWORD")
                                    .font(.urbanistBold(24))
                                    .foregroundColor(.cakeBrown)

                                Spacer().frame(height: 4)

                                Text("Keep your account safe and secure")
                                    .font(.urbanistRegular(13))
                                    .foregroundColor(.cakeGrey)

                                Spacer().frame(height: 24)

                                fieldLabel("Current Password")
                                AuthTextField(placeholder: "••••••••••",
                                              text: $vm.currentPassword,
                                              isSecure: !showCurrent,
                                              trailingIcon: showCurrent ? "eye" : "eye.slash") {
                                    showCurrent.toggle()
                                }

                                Spacer().frame(height: 14)

                                fieldLabel("New Password")
                                AuthTextField(placeholder: "••••••••••",
                                              text: $vm.newPassword,
                                              isSecure: !showNew,
                                              trailingIcon: showNew ? "eye" : "eye.slash") {
                                    showNew.toggle()
                                }

                                Spacer().frame(height: 14)

                                fieldLabel("Confirm Password")
                                AuthTextField(placeholder: "••••••••••",
                                              text: $vm.confirmPassword,
                                              isSecure: !showConfirm,
                                              trailingIcon: showConfirm ? "eye" : "eye.slash") {
                                    showConfirm.toggle()
                                }

                                if let err = vm.errorMessage {
                                    Text(err)
                                        .font(.urbanistRegular(12))
                                        .foregroundColor(.red)
                                        .padding(.top, 10)
                                } else if let success = vm.successMessage {
                                    Text(success)
                                        .font(.urbanistRegular(12))
                                        .foregroundColor(Color(red: 0.2, green: 0.6, blue: 0.3))
                                        .padding(.top, 10)
                                }

                                Spacer().frame(height: 24)

                                Button { vm.changePassword() } label: {
                                    ZStack {
                                        if vm.isLoading { ProgressView().tint(.white) }
                                        else {
                                            Text("Change Password")
                                                .font(.urbanistSemiBold(17))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 54)
                                    .background(Color.cakeBrown)
                                    .clipShape(Capsule())
                                }
                                .disabled(vm.isLoading || vm.didReset)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 28)
                        }
                        .padding(.bottom, max(geo.safeAreaInsets.bottom, 24))
                    }
                }
            }
        }
    }

    private func fieldLabel(_ label: String) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.urbanistSemiBold(14))
                .foregroundColor(.cakePrimaryText)
            Text("*")
                .font(.urbanistBold(14))
                .foregroundColor(.red)
        }
        .padding(.bottom, 8)
    }
}

// MARK: - Preview
#Preview {
    NavigationStack { ResetPasswordView(email: "test@example.com", onPasswordChanged: {}) }
}
