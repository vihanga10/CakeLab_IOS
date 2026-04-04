import SwiftUI

// MARK: - Reusable Auth Text Field
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
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboardType)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
            }
            .font(.urbanistRegular(15))
            .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

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
        .background(Color.white)
        .overlay(
            Capsule()
                .stroke(Color(red: 0.75, green: 0.75, blue: 0.75), lineWidth: 1.2)
        )
        .clipShape(Capsule())
    }
}

// MARK: - Role Selector  (I'm a Customer / I'm a Crafter)
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
struct ORDivider: View {
    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color(red: 0.8, green: 0.8, blue: 0.8))
                .frame(height: 1)
            Text("OR")
                .font(.urbanistRegular(13))
                .foregroundColor(.cakeGrey)
                .fixedSize()
            Rectangle()
                .fill(Color(red: 0.8, green: 0.8, blue: 0.8))
                .frame(height: 1)
        }
    }
}

// MARK: - Social Buttons (Google + Apple)
struct SocialButtons: View {
    var body: some View {
        HStack(spacing: 24) {
            Spacer()
            // Google — use image asset
            socialCircle {
                Image("google")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
            }
            // Apple
            socialCircle {
                Image(systemName: "apple.logo")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.black)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private func socialCircle<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(width: 52, height: 52)
            .background(Color.white)
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
        let r = min(cornerRadius, min(rect.width, rect.height) / 2)
        var path = Path()
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
