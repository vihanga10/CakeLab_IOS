import Foundation
import EventKit

// Manages creating, updating, and persisting delivery-related calendar events for each user
final class CalendarEventManager {
    // Singleton so calendar access and event store are shared across the app
    static let shared = CalendarEventManager()

    private let eventStore = EKEventStore()   // EventKit store used for all calendar read/write operations
    private let defaults = UserDefaults.standard   // Stores calendar and event identifiers for reuse across sessions

    private init() {}

    // Typed errors thrown during calendar permission checks and event save operations
    enum CalendarError: LocalizedError, Equatable {
        case accessDenied             // User has denied or restricted calendar permission
        case calendarSourceUnavailable // No writable calendar source (iCloud, local, Exchange) found
        case saveFailed               // EventKit failed to persist the event

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

    // Creates a new delivery event or updates the existing one for the given order
    // Returns the EventKit event identifier so callers can reference it later
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

        // Reuse the existing event if one was previously saved for this order; otherwise create a new one
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
        event.endDate = endDate ?? startDate.addingTimeInterval(60 * 60)   // Defaults to 1-hour duration
        event.location = location
        event.notes = notes
        // Adds two reminders: 1 hour before and 24 hours before the delivery
        event.alarms = [
            EKAlarm(relativeOffset: -60 * 60),
            EKAlarm(relativeOffset: -24 * 60 * 60)
        ]

        do {
            try eventStore.save(event, span: .thisEvent, commit: true)
            // Persist the event identifier so it can be looked up and updated on future calls
            if let identifier = event.eventIdentifier {
                defaults.set(identifier, forKey: eventKey)
                return identifier
            }
            throw CalendarError.saveFailed
        } catch {
            throw CalendarError.saveFailed
        }
    }

    // Checks current calendar permission and requests access if not yet determined
    // Uses the iOS 17+ full-access API when available; falls back to the legacy callback API
    private func ensureAccessGranted() async throws {
        let status = EKEventStore.authorizationStatus(for: .event)

        if #available(iOS 17.0, *) {
            switch status {
            case .fullAccess, .writeOnly:
                return   // Already authorized — proceed
            case .notDetermined:
                let granted = try await eventStore.requestFullAccessToEvents()
                guard granted else { throw CalendarError.accessDenied }
            case .denied, .restricted:
                throw CalendarError.accessDenied
            @unknown default:
                throw CalendarError.accessDenied
            }
        } else {
            // iOS 16 and below — uses callback-based requestAccess wrapped in async continuation
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
