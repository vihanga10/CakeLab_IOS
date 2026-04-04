import SwiftUI
import Combine

// MARK: - Reset Password ViewModel
@MainActor
final class ResetPasswordViewModel: ObservableObject {
    @Published var newPassword      = ""
    @Published var confirmPassword  = ""
    @Published var isLoading        = false
    @Published var errorMessage: String?
    @Published var didReset         = false

    func changePassword() {
        errorMessage = nil
        guard !newPassword.isEmpty else { errorMessage = "Please enter a new password."; return }
        guard newPassword.count >= 6 else { errorMessage = "Password must be at least 6 characters."; return }
        guard newPassword == confirmPassword else { errorMessage = "Passwords do not match."; return }
        // TODO: call Firebase confirmPasswordReset(withCode:newPassword:)
        didReset = true
    }
}

// MARK: - Reset Password View
@MainActor
struct ResetPasswordView: View {

    @StateObject private var vm      = ResetPasswordViewModel()
    @State private var showNew       = false
    @State private var showConfirm   = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                Color.white.ignoresSafeArea()

                VStack(spacing: 0) {

                    // ── Back button ───────────────────────────────────────
                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.15))
                                .padding(10)
                                .background(Color(red: 0.94, green: 0.92, blue: 0.89))
                                .clipShape(Circle())
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, geo.safeAreaInsets.top + 4)

                    // ── Illustration (same as Forgot Password) ────────────
                    Image("password")
                        .resizable()
                        .scaledToFit()
                        .frame(height: geo.size.height * 0.34)
                        .padding(.horizontal, 16)

                    Spacer().frame(height: 4)

                    // ── Form ──────────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 0) {

                        Text("RESET PASSWORD")
                            .font(.urbanistBold(24))
                            .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

                        Spacer().frame(height: 5)

                        Text("Keep your account safe and secure")
                            .font(.urbanistRegular(13))
                            .foregroundColor(.cakeGrey)

                        Spacer().frame(height: 28)

                        // ── New Password ──────────────────────────────────
                        fieldLabel("New Password")
                        AuthTextField(placeholder: "••••••••••",
                                      text: $vm.newPassword,
                                      isSecure: !showNew,
                                      trailingIcon: showNew ? "eye" : "eye.slash") {
                            showNew.toggle()
                        }

                        Spacer().frame(height: 16)

                        // ── Confirm Password ──────────────────────────────
                        fieldLabel("Confirm Password")
                        AuthTextField(placeholder: "••••••••••",
                                      text: $vm.confirmPassword,
                                      isSecure: !showConfirm,
                                      trailingIcon: showConfirm ? "eye" : "eye.slash") {
                            showConfirm.toggle()
                        }

                        // ── Error ─────────────────────────────────────────
                        if let err = vm.errorMessage {
                            Text(err)
                                .font(.urbanistRegular(12))
                                .foregroundColor(.red)
                                .padding(.top, 8)
                        }

                        if vm.didReset {
                            Text("Password changed successfully!")
                                .font(.urbanistSemiBold(13))
                                .foregroundColor(Color(red: 0.2, green: 0.6, blue: 0.3))
                                .padding(.top, 8)
                        }

                        Spacer().frame(height: 32)

                        // ── Change Password button ────────────────────────
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
                    .padding(.horizontal, 24)

                    Spacer()
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .navigationBarHidden(true)
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
    NavigationStack { ResetPasswordView() }
}
