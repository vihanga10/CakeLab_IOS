import SwiftUI

enum AccessibilityFontScale: String, CaseIterable, Identifiable {
    case standard
    case large
    case extraLarge

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: return "Standard"
        case .large: return "Large"
        case .extraLarge: return "XL"
        }
    }

    var dynamicTypeSize: DynamicTypeSize {
        switch self {
        case .standard: return .large
        case .large: return .xLarge
        case .extraLarge: return .xxLarge
        }
    }
}

struct AccessibilitySettingsSection: View {
    @AppStorage("accessibilityHighContrastEnabled") private var highContrastEnabled = false
    @AppStorage("accessibilityFontScale") private var fontScaleRawValue = AccessibilityFontScale.standard.rawValue
    @AppStorage("inAppVoiceEnabled") private var inAppVoiceEnabled = false

    private var fontScaleBinding: Binding<AccessibilityFontScale> {
        Binding(
            get: {
                AccessibilityFontScale(rawValue: fontScaleRawValue) ?? .standard
            },
            set: { newValue in
                fontScaleRawValue = newValue.rawValue
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Accessibility")
                .font(.urbanistMedium(16))
                .foregroundColor(Color(hex: "676767"))
                .padding(.horizontal, 4)

            VStack(spacing: 12) {
                accessibilityCard(title: "Contrast", icon: "circle.lefthalf.filled") {
                    toggleRow(
                        title: "High Contrast Mode",
                        subtitle: "Increase contrast across app screens.",
                        isOn: $highContrastEnabled
                    )

                    Divider().padding(.leading, 52)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Font Scaling")
                            .font(.urbanistMedium(14))
                            .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

                        Picker("Font Scaling", selection: fontScaleBinding) {
                            ForEach(AccessibilityFontScale.allCases) { scale in
                                Text(scale.title).tag(scale)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                }

                accessibilityCard(title: "Voice Assistant", icon: "speaker.wave.2.fill") {
                    toggleRow(
                        title: "Speak Screen button",
                        subtitle: "Show a floating button that reads the current screen aloud.",
                        isOn: $inAppVoiceEnabled
                    )
                }
            }
        }
    }

    private func accessibilityCard<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(hex: "5D3714"))
                    .frame(width: 32, height: 32)
                    .background(Color(hex: "EFEAE2"))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Text(title)
                    .font(.urbanistSemiBold(15))
                    .foregroundColor(Color(hex: "1A1A1A"))
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 2)

            content()
        }
        .background(Color.white.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 10, y: 5)
    }

    private func toggleRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.urbanistMedium(14))
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

                Text(subtitle)
                    .font(.urbanistRegular(12))
                    .foregroundColor(Color(hex: "7B7B7B"))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(.cakeBrown)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
    }
}

struct FloatingSpeakButton: View {
    @AppStorage("inAppVoiceEnabled") private var inAppVoiceEnabled = false
    @ObservedObject private var speechManager = SpeechManager.shared

    var body: some View {
        if inAppVoiceEnabled {
            Button {
                speechManager.toggleSpeakScreen()
            } label: {
                Image(systemName: speechManager.isSpeaking ? "stop.square.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 58, height: 58)
                    .background(Color(hex: "5D3714"))
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(speechManager.isSpeaking ? "Stop reading screen" : "Speak screen")
        }
    }
}
