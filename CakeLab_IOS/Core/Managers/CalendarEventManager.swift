import Foundation
import EventKit

final class CalendarEventManager {
    static let shared = CalendarEventManager()

    private let eventStore = EKEventStore()
    private let defaults = UserDefaults.standard

    private init() {}

    enum CalendarError: LocalizedError, Equatable {
        case accessDenied
        case calendarSourceUnavailable
        case saveFailed

        var errorDescription: String? {
            switch self {
            case .accessDenied:
                return "Calendar access is denied. Please enable Calendar permission in Settings."
            case .calendarSourceUnavailable:
                return "No writable calendar source was found on this device."
            case .saveFailed:
                return "Failed to save the event to Calendar."
            }
        }
    }

    @discardableResult
    func addOrUpdateDeliveryEvent(
        appUserID: String,
        appUserName: String,
        orderID: String,
        eventTitle: String,
        startDate: Date,
        endDate: Date? = nil,
        location: String?,
        notes: String?
    ) async throws -> String {
        try await ensureAccessGranted()

        let calendar = try ensureCalendar(for: appUserID, appUserName: appUserName)
        let eventKey = eventIdentifierKey(appUserID: appUserID, orderID: orderID)

        let event: EKEvent
        if let existingID = defaults.string(forKey: eventKey),
           let existingEvent = eventStore.event(withIdentifier: existingID) {
            event = existingEvent
        } else {
            event = EKEvent(eventStore: eventStore)
        }

        event.calendar = calendar
        event.title = eventTitle
        event.startDate = startDate
        event.endDate = endDate ?? startDate.addingTimeInterval(60 * 60)
        event.location = location
        event.notes = notes
        event.alarms = [
            EKAlarm(relativeOffset: -60 * 60),
            EKAlarm(relativeOffset: -24 * 60 * 60)
        ]

        do {
            try eventStore.save(event, span: .thisEvent, commit: true)
            if let identifier = event.eventIdentifier {
                defaults.set(identifier, forKey: eventKey)
                return identifier
            }
            throw CalendarError.saveFailed
        } catch {
            throw CalendarError.saveFailed
        }
    }

    private func ensureAccessGranted() async throws {
        let status = EKEventStore.authorizationStatus(for: .event)

        if #available(iOS 17.0, *) {
            switch status {
            case .fullAccess, .writeOnly:
                return
            case .notDetermined:
                let granted = try await eventStore.requestFullAccessToEvents()
                guard granted else { throw CalendarError.accessDenied }
            case .denied, .restricted:
                throw CalendarError.accessDenied
            @unknown default:
                throw CalendarError.accessDenied
            }
        } else {
            switch status {
            case .authorized:
                return
            case .notDetermined:
                let granted = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
                    eventStore.requestAccess(to: .event) { granted, error in
                        if let error {
                            continuation.resume(throwing: error)
                            return
                        }
                        continuation.resume(returning: granted)
                    }
                }
                guard granted else { throw CalendarError.accessDenied }
            case .denied, .restricted:
                throw CalendarError.accessDenied
            @unknown default:
                throw CalendarError.accessDenied
            }
        }
    }

    private func ensureCalendar(for appUserID: String, appUserName: String) throws -> EKCalendar {
        let key = calendarIdentifierKey(appUserID: appUserID)

        if let existingID = defaults.string(forKey: key),
           let existingCalendar = eventStore.calendar(withIdentifier: existingID) {
            return existingCalendar
        }

        let idSuffix = String(appUserID.prefix(6))
        let displayName = appUserName.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseTitle = displayName.isEmpty ? "User" : displayName
        let calendarTitle = "CakeLab - \(baseTitle) [\(idSuffix)]"

        if let existingByName = eventStore.calendars(for: .event).first(where: { $0.title == calendarTitle }) {
            defaults.set(existingByName.calendarIdentifier, forKey: key)
            return existingByName
        }

        guard let source = preferredSource() else {
            throw CalendarError.calendarSourceUnavailable
        }

        let calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar.title = calendarTitle
        calendar.source = source

        try eventStore.saveCalendar(calendar, commit: true)
        defaults.set(calendar.calendarIdentifier, forKey: key)
        return calendar
    }

    private func preferredSource() -> EKSource? {
        if let defaultSource = eventStore.defaultCalendarForNewEvents?.source {
            return defaultSource
        }

        return eventStore.sources.first {
            $0.sourceType == .calDAV ||
            $0.sourceType == .local ||
            $0.sourceType == .exchange
        }
    }

    private func calendarIdentifierKey(appUserID: String) -> String {
        "calendar_identifier_\(appUserID)"
    }

    private func eventIdentifierKey(appUserID: String, orderID: String) -> String {
        "calendar_event_\(appUserID)_\(orderID)"
    }
}
