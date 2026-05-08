import AVFoundation
import Combine
import UIKit

@MainActor
final class SpeechManager: NSObject, ObservableObject {
    static let shared = SpeechManager()

    @Published private(set) var isSpeaking = false

    private let synthesizer = AVSpeechSynthesizer()

    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    func toggleSpeakScreen() {
        if synthesizer.isSpeaking || isSpeaking {
            stopSpeaking()
            return
        }

        speak(visibleScreenText())
    }

    func speak(_ text: String) {
        let readableText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let utteranceText = readableText.isEmpty ? "No readable content found on this screen." : readableText

        configurePlaybackSession()

        let utterance = AVSpeechUtterance(string: utteranceText)
        utterance.voice = AVSpeechSynthesisVoice(language: Locale.current.identifier)
            ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0

        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    private func configurePlaybackSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true, options: [])
        } catch {
            print("Speech audio session failed: \(error.localizedDescription)")
        }
    }

    private func visibleScreenText() -> String {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) else {
            return ""
        }

        var collectedText: [String] = []
        var seenText = Set<String>()

        collectReadableText(from: window, into: &collectedText, seenText: &seenText)

        return collectedText.joined(separator: ". ")
    }

    private func collectReadableText(from view: UIView, into output: inout [String], seenText: inout Set<String>) {
        guard !view.isHidden, view.alpha > 0.01 else { return }

        appendReadableText(from: view, into: &output, seenText: &seenText)

        view.subviews.forEach { subview in
            collectReadableText(from: subview, into: &output, seenText: &seenText)
        }
    }

    private func appendReadableText(from view: UIView, into output: inout [String], seenText: inout Set<String>) {
        if let text = readableText(for: view), !seenText.contains(text) {
            output.append(text)
            seenText.insert(text)
        }

        if let accessibilityElements = view.accessibilityElements {
            accessibilityElements.forEach { element in
                collectReadableText(from: element, into: &output, seenText: &seenText)
            }
            return
        }

        let elementCount = view.accessibilityElementCount()
        guard elementCount != NSNotFound, elementCount > 0 else { return }

        for index in 0..<elementCount {
            if let element = view.accessibilityElement(at: index) {
                collectReadableText(from: element, into: &output, seenText: &seenText)
            }
        }
    }

    private func collectReadableText(from element: Any, into output: inout [String], seenText: inout Set<String>) {
        if let view = element as? UIView {
            collectReadableText(from: view, into: &output, seenText: &seenText)
            return
        }

        if let text = readableText(for: element), !seenText.contains(text) {
            output.append(text)
            seenText.insert(text)
        }
    }

    private func readableText(for view: UIView) -> String? {
        let rawText: String?

        switch view {
        case let label as UILabel:
            rawText = label.text
        case let button as UIButton:
            rawText = button.currentTitle ?? button.accessibilityLabel
        case let textField as UITextField:
            rawText = textField.text?.isEmpty == false ? textField.text : textField.placeholder
        case let textView as UITextView:
            rawText = textView.text
        case let segmentedControl as UISegmentedControl:
            rawText = selectedSegmentTitle(from: segmentedControl)
        default:
            rawText = view.isAccessibilityElement ? view.accessibilityLabel : nil
        }

        return rawText?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
            .nilIfEmpty
    }

    private func readableText(for element: Any) -> String? {
        guard let accessibilityElement = element as? NSObject else { return nil }

        return accessibilityElement.accessibilityLabel?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
            .nilIfEmpty
    }

    private func selectedSegmentTitle(from segmentedControl: UISegmentedControl) -> String? {
        guard segmentedControl.selectedSegmentIndex >= 0 else { return segmentedControl.accessibilityLabel }
        return segmentedControl.titleForSegment(at: segmentedControl.selectedSegmentIndex)
    }
}

extension SpeechManager: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
