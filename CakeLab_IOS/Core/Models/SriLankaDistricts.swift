import Foundation

enum SriLankaDistricts {
    static let all: [String] = [
        "Ampara", "Anuradhapura", "Badulla", "Batticaloa", "Colombo", "Galle", "Gampaha", "Hambantota", "Jaffna", "Kalutara", "Kandy", "Kegalle", "Kilinochchi", "Kurunegala", "Mannar", "Matale", "Matara", "Monaragala", "Mullaitivu", "Nuwara Eliya", "Polonnaruwa", "Puttalam", "Ratnapura", "Trincomalee", "Vavuniya"
    ]

    static func canonical(_ value: String?) -> String? {
        guard let trimmed = cleaned(value), !trimmed.isEmpty else { return nil }
        let normalizedValue = normalizedDistrictToken(from: trimmed)
        return all.first { normalize($0) == normalizedValue }
    }

    static func detect(in value: String?) -> String? {
        guard let trimmed = cleaned(value), !trimmed.isEmpty else { return nil }
        let normalizedValue = normalize(trimmed)

        return all.first { district in
            let normalizedDistrict = normalize(district)
            return normalizedValue.contains(normalizedDistrict)
                || normalizedValue.contains("\(normalizedDistrict) district")
        }
    }

    static func displayLocation(address: String?, city: String?) -> String {
        let trimmedAddress = cleaned(address) ?? ""
        let resolvedCity = canonical(city) ?? detect(in: city) ?? cleaned(city) ?? ""

        guard !trimmedAddress.isEmpty else { return resolvedCity }
        guard !resolvedCity.isEmpty else { return trimmedAddress }

        if normalize(trimmedAddress).contains(normalize(resolvedCity)) {
            return trimmedAddress
        }

        return "\(trimmedAddress), \(resolvedCity)"
    }

    static func geocodingQuery(address: String?, city: String?) -> String {
        let display = displayLocation(address: address, city: city)
        if display.isEmpty {
            return "Sri Lanka"
        }
        if normalize(display).contains("sri lanka") {
            return display
        }
        return "\(display), Sri Lanka"
    }

    private static func normalizedDistrictToken(from value: String) -> String {
        var normalizedValue = normalize(value)
        if normalizedValue.hasSuffix(" district") {
            normalizedValue.removeLast(" district".count)
        }
        return normalizedValue
    }

    private static func cleaned(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func normalize(_ value: String) -> String {
        value
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}