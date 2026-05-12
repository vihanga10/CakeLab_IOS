import SwiftUI

// Defines the three supported font size levels for accessibility font scaling
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

    // Maps each font scale case to a SwiftUI DynamicTypeSize for system-wide text sizing
    var dynamicTypeSize: DynamicTypeSize {
        switch self {
        case .standard: return .large
        case .large: return .xLarge
        case .extraLarge: return .xxLarge
        }
    }
}

// Settings section view that groups all accessibility controls (contrast, font scale, voice assistant)
struct AccessibilitySettingsSection: View {
    // Persisted user preferences stored in AppStorage so they survive app restarts
    @AppStorage("accessibilityHighContrastEnabled") private var highContrastEnabled = false
    @AppStorage("accessibilityDarkModeEnabled") private var darkModeEnabled = false
    @AppStorage("accessibilityFontScale") private var fontScaleRawValue = AccessibilityFontScale.standard.rawValue
    @AppStorage("inAppVoiceEnabled") private var inAppVoiceEnabled = false

    // Converts the raw string stored in AppStorage to/from the AccessibilityFontScale enum
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
                .foregroundColor(.cakeSecondaryText)
                .padding(.horizontal, 4)

            VStack(spacing: 12) {
                // Card 1: Appearance — contains dark mode, contrast, and font scale controls
                accessibilityCard(title: "Appearance", icon: "moon.stars.fill") {
                    toggleRow(
                        title: "Dark Mode",
                        subtitle: "Use a darker app appearance.",
                        isOn: $darkModeEnabled
                    )

                    Divider().padding(.leading, 52)

                    toggleRow(
                        title: "High Contrast Mode",
                        subtitle: "Increase contrast across app screens.",
                        isOn: $highContrastEnabled
                    )

                    Divider().padding(.leading, 52)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Font Scaling")
                            .font(.urbanistMedium(14))
                            .foregroundColor(.cakePrimaryText)

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

                // Card 2: Voice Assistant — toggle to show/hide the floating speak-screen button
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

    // Reusable card container with a branded icon + title header and injected content below
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
                    .background(Color.cakeIconTile)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Text(title)
                    .font(.urbanistSemiBold(15))
                    .foregroundColor(.cakePrimaryText)
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 2)

            content()
        }
        .background(Color.cakeSurface.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.cakeStroke, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 10, y: 5)
    }

    // Reusable row with a title, subtitle description, and a toggle on the trailing side
    private func toggleRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.urbanistMedium(14))
                    .foregroundColor(.cakePrimaryText)

                Text(subtitle)
                    .font(.urbanistRegular(12))
                    .foregroundColor(.cakeTertiaryText)
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

// Floating circular button overlaid on screen; visible only when in-app voice is enabled
// Tapping it starts or stops reading the current screen aloud via SpeechManager
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
