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
    @Published var didReset         = false
    @Published var email: String = ""
    
    private let authService = AuthService()

    func changePassword() {
        errorMessage = nil
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
    @State private var showFullScreen = false
    @State private var showSuccessAlert = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Color.clear
            .ignoresSafeArea()
            .fullScreenCover(isPresented: $showFullScreen, onDismiss: {
                dismiss()
            }) {
                resetPasswordContent
            }
        .onAppear {
            vm.email = email
            if !showFullScreen {
                showFullScreen = true
            }
        }
        .onChange(of: vm.didReset) { _, didReset in
            if didReset {
                showSuccessAlert = true
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
                            showFullScreen = false
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.cakeBrown)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, geo.safeAreaInsets.top + 8)
                    .padding(.bottom, 12)

                    VStack(alignment: .center, spacing: 0) {
                        Image("password")
                            .resizable()
                            .scaledToFit()
                            .frame(height: min(geo.size.height * 0.24, 180))
                            .padding(.bottom, 20)

                        VStack(alignment: .leading, spacing: 0) {
                            Text("RESET PASSWORD")
                                .font(.urbanistBold(24))
                                .foregroundColor(.cakeBrown)

                            Spacer().frame(height: 4)

                            Text("Keep your account safe and secure")
                                .font(.urbanistRegular(13))
                                .foregroundColor(.cakeGrey)

                            Spacer().frame(height: 20)

                            fieldLabel("Current Password")
                            AuthTextField(placeholder: "••••••••••",
                                          text: $vm.currentPassword,
                                          isSecure: !showCurrent,
                                          trailingIcon: showCurrent ? "eye" : "eye.slash") {
                                showCurrent.toggle()
                            }

                            Spacer().frame(height: 12)

                            fieldLabel("New Password")
                            AuthTextField(placeholder: "••••••••••",
                                          text: $vm.newPassword,
                                          isSecure: !showNew,
                                          trailingIcon: showNew ? "eye" : "eye.slash") {
                                showNew.toggle()
                            }

                            Spacer().frame(height: 12)

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
                            }

                            Spacer(minLength: 18)

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
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.bottom, max(geo.safeAreaInsets.bottom, 16))
                }
            }
        }
        .alert("Password Changed Successfully", isPresented: $showSuccessAlert) {
            Button("OK") {
                onPasswordChanged()
                showFullScreen = false
            }
        } message: {
            Text("Successfully password changed. Please go to the sign in page to sign in.")
        }
    }

    private func fieldLabel(_ label: String) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.urbanistSemiBold(14))
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
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
