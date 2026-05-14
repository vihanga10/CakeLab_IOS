import SwiftUI
import UIKit

// MARK: - Reusable Auth Text Field

/// A styled text field used across all auth screens (login, sign-up, reset password).
/// Supports both plain and secure entry, an optional trailing icon button (e.g. eye toggle),
/// and custom keyboard types.
struct AuthTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var trailingIcon: String? = nil
    var onTrailingTap: (() -> Void)? = nil

    var body: some View {
        HStack {
            Group {
                if isSecure {
                    // Use SecureField so the OS masks characters as the user types
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboardType)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
            }
            .font(.urbanistRegular(15))
            .foregroundColor(.cakePrimaryText)

            // Optional icon button on the right — commonly used for show/hide password
            if let icon = trailingIcon {
                Button(action: { onTrailingTap?() }) {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(.cakeGrey)
                }
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 54)
        .background(Color.cakeSurface)
        .overlay(
            Capsule()
                .stroke(Color(red: 0.75, green: 0.75, blue: 0.75), lineWidth: 1.2)
        )
        .clipShape(Capsule())
    }
}

// MARK: - Role Selector  (I'm a Customer / I'm a Crafter)

// Lets the user pick whether they are signing up as a Customer or a Crafter (baker).
// The selected role is highlighted with the brand warm-sand color.
struct RoleSelector: View {
    @Binding var selected: UserRole?

    var body: some View {
        HStack(spacing: 12) {
            roleButton(label: "I'm a Customer", role: .customer)
            roleButton(label: "I'm a Crafter",  role: .baker)
        }
    }

    private func roleButton(label: String, role: UserRole) -> some View {
        Button {
            selected = role
        } label: {
            Text(label)
                .font(.urbanistSemiBold(14))
                .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.15))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    // Warm-sand tint for the active role; neutral grey for the inactive one
                    selected == role
                        ? Color(red: 212/255, green: 196/255, blue: 176/255).opacity(0.55)
                        : Color(red: 0.93, green: 0.93, blue: 0.93)
                )
                .clipShape(Capsule())
                .animation(.easeInOut(duration: 0.2), value: selected)
        }
    }
}

// MARK: - OR Divider

// Horizontal rule with an "OR" label used to separate email/password auth from social sign-in.
struct ORDivider: View {
    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color(red: 0.8, green: 0.8, blue: 0.8))
                .frame(height: 1)
            Text("OR")
                .font(.urbanistRegular(13))
                .foregroundColor(.cakeGrey)
                .fixedSize() // prevents the label from stretching and pushing the lines off-screen
            Rectangle()
                .fill(Color(red: 0.8, green: 0.8, blue: 0.8))
                .frame(height: 1)
        }
    }
}

// MARK: - Social Buttons (Google + Apple)

// Row of circular icon buttons for third-party sign-in options.
// Callbacks are optional so screens that don't support a provider can simply omit it.
struct SocialButtons: View {
    var onGoogleTap: (() -> Void)? = nil
    var onAppleTap: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 24) {
            Spacer()
            // Google — uses a custom image asset from the asset catalogue
            Button {
                onGoogleTap?()
            } label: {
                socialCircle {
                    Image("google")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                }
            }
            .buttonStyle(.plain)
            // Apple — SF Symbol kept black to match Apple HIG branding requirements
            Button {
                onAppleTap?()
            } label: {
                socialCircle {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.black)
                }
            }
            .buttonStyle(.plain)
            Spacer()
        }
    }

    // Wraps any icon in a uniformly sized circle with a subtle border, matching the auth card surface.
    @ViewBuilder
    private func socialCircle<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(width: 52, height: 52)
            .background(Color.cakeSurface)
            .overlay(
                Circle().stroke(Color(red: 0.8, green: 0.8, blue: 0.8), lineWidth: 1.2)
            )
            .clipShape(Circle())
    }
}

// MARK: - TopRoundedRectangle (private copy for Auth screens)
// Named TopRoundedRectangle2 to avoid collision with the one in OnboardingPageView
struct TopRoundedRectangle2: Shape {
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        // Clamp so the radius never exceeds half the shortest side
        let r = min(cornerRadius, min(rect.width, rect.height) / 2)
        var path = Path()

        // Start at bottom-left and draw counter-clockwise, rounding only the top two corners
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        path.addArc(center: CGPoint(x: rect.minX + r, y: rect.minY + r),
                    radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - r, y: rect.minY + r),
                    radius: r, startAngle: .degrees(270), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - UIApplication helpers for presenting auth flows

extension UIApplication {
    // Returns the topmost presented view controller, used to present Google Sign-In on top of any current UI.
    var authTopViewController: UIViewController? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .rootViewController?
            .topPresentedViewController
    }

    // Returns the key window, required as the presentation anchor for Sign in with Apple.
    var authPresentationAnchor: UIWindow? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
    }
}

private extension UIViewController {
    // Recursively walks the presentation/navigation/tab stack to find the visible view controller.
    var topPresentedViewController: UIViewController {
        if let presentedViewController {
            return presentedViewController.topPresentedViewController
        }
        if let navigationController = self as? UINavigationController,
           let visibleViewController = navigationController.visibleViewController {
            return visibleViewController.topPresentedViewController
        }
        if let tabBarController = self as? UITabBarController,
           let selectedViewController = tabBarController.selectedViewController {
            return selectedViewController.topPresentedViewController
        }
        return self
    }
}
