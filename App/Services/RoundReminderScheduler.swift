import Foundation
import UserNotifications

extension Notification.Name {
    static let roundDataDidChange = Notification.Name("roundDataDidChange")
    static let roundMayBeFinished = Notification.Name("roundMayBeFinished")
    static let roundReminderOpenRound = Notification.Name("roundReminderOpenRound")
}

final class RoundReminderScheduler: @unchecked Sendable {
    static let shared = RoundReminderScheduler()

    static let categoryIdentifier = "round-stale-reminder"
    static let finishRoundActionIdentifier = "finish-round"
    static let keepPlayingActionIdentifier = "keep-playing"
    static let roundIDUserInfoKey = "roundID"

    private let center: UNUserNotificationCenter
    private var didConfigureCategories = false

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    var staleRoundDelaySeconds: TimeInterval {
        ProcessInfo.processInfo.environment["ROUND_STALE_REMINDER_DELAY_SECONDS"]
            .flatMap(TimeInterval.init) ?? 28_800
    }

    var keepPlayingReminderDelaySeconds: TimeInterval {
        ProcessInfo.processInfo.environment["ROUND_KEEP_PLAYING_REMINDER_DELAY_SECONDS"]
            .flatMap(TimeInterval.init) ?? 3_600
    }

    func configureNotificationActions() {
        guard didConfigureCategories == false else {
            return
        }

        let finishAction = UNNotificationAction(
            identifier: Self.finishRoundActionIdentifier,
            title: "Finish Round",
            options: [.destructive]
        )
        let keepPlayingAction = UNNotificationAction(
            identifier: Self.keepPlayingActionIdentifier,
            title: "Keep Playing",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: Self.categoryIdentifier,
            actions: [finishAction, keepPlayingAction],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([category])
        didConfigureCategories = true
    }

    func scheduleStaleRoundReminder(for round: GolfRound, now: Date = Date()) async {
        let fireDate = round.startedAt.addingTimeInterval(staleRoundDelaySeconds)
        await scheduleReminder(for: round, delay: max(1, fireDate.timeIntervalSince(now)))
    }

    func scheduleKeepPlayingReminder(for round: GolfRound) async {
        await scheduleReminder(for: round, delay: max(1, keepPlayingReminderDelaySeconds))
    }

    func scheduleBoundaryExitReminder(for round: GolfRound) async {
        await scheduleReminder(
            for: round,
            delay: 1,
            body: "You appear to have left the round area. Finish \(round.name)?"
        )
    }

    func cancelReminder(for roundID: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationIdentifier(for: roundID)])
        center.removeDeliveredNotifications(withIdentifiers: [Self.notificationIdentifier(for: roundID)])
    }

    func isStale(_ round: GolfRound, now: Date = Date()) -> Bool {
        now.timeIntervalSince(round.startedAt) >= staleRoundDelaySeconds
    }

    static func roundID(from userInfo: [AnyHashable: Any]) -> UUID? {
        guard let rawID = userInfo[roundIDUserInfoKey] as? String else {
            return nil
        }

        return UUID(uuidString: rawID)
    }

    static func notificationIdentifier(for roundID: UUID) -> String {
        "round-stale-\(roundID.uuidString)"
    }

    private func scheduleReminder(
        for round: GolfRound,
        delay: TimeInterval,
        body: String? = nil
    ) async {
        guard isSchedulingEnabled else {
            return
        }

        configureNotificationActions()

        do {
            guard try await requestAuthorization() else {
                return
            }

            let content = UNMutableNotificationContent()
            content.title = "Still Playing?"
            content.body = body ?? "Do you want to finish \(round.name)?"
            content.sound = .default
            content.categoryIdentifier = Self.categoryIdentifier
            content.userInfo = [Self.roundIDUserInfoKey: round.id.uuidString]

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
            let request = UNNotificationRequest(
                identifier: Self.notificationIdentifier(for: round.id),
                content: content,
                trigger: trigger
            )

            cancelReminder(for: round.id)
            try await add(request)
        } catch {
            return
        }
    }

    private var isSchedulingEnabled: Bool {
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-reset-data") {
            return ProcessInfo.processInfo.environment["ROUND_REMINDER_TESTING_ENABLED"] == "1"
        }

        return true
    }

    private func requestAuthorization() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            center.requestAuthorization(options: [.alert, .sound]) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    private func add(_ request: UNNotificationRequest) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            center.add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}
