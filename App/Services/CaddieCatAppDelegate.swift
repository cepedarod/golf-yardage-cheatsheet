import UIKit
import UserNotifications

final class CaddieCatAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        RoundReminderScheduler.shared.configureNotificationActions()
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let roundID = RoundReminderScheduler.roundID(from: response.notification.request.content.userInfo) else {
            return
        }

        switch response.actionIdentifier {
        case RoundReminderScheduler.finishRoundActionIdentifier:
            await finishRound(roundID)
        case RoundReminderScheduler.keepPlayingActionIdentifier:
            await keepPlaying(roundID)
        case UNNotificationDefaultActionIdentifier:
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .roundMayBeFinished,
                    object: nil,
                    userInfo: [RoundReminderScheduler.roundIDUserInfoKey: roundID.uuidString]
                )
                NotificationCenter.default.post(name: .roundReminderOpenRound, object: nil)
            }
        default:
            break
        }
    }

    nonisolated private func finishRound(_ roundID: UUID) async {
        guard let repository = makeRepository() else {
            return
        }

        do {
            _ = try repository.endRound(id: roundID)
            RoundReminderScheduler.shared.cancelReminder(for: roundID)
            await MainActor.run {
                NotificationCenter.default.post(name: .roundDataDidChange, object: nil)
                NotificationCenter.default.post(name: .roundReminderOpenRound, object: nil)
            }
        } catch {
            return
        }
    }

    nonisolated private func keepPlaying(_ roundID: UUID) async {
        guard let repository = makeRepository(),
              let round = try? repository.loadData().rounds.first(where: { $0.id == roundID && $0.isCompleted == false }) else {
            return
        }

        await RoundReminderScheduler.shared.scheduleKeepPlayingReminder(for: round)
        await MainActor.run {
            NotificationCenter.default.post(name: .roundReminderOpenRound, object: nil)
        }
    }

    nonisolated private func makeRepository() -> GolfBagRepository? {
        guard let storeURL = try? FileGolfBagStore.defaultStoreURL() else {
            return nil
        }

        return GolfBagRepository(store: FileGolfBagStore(fileURL: storeURL))
    }
}
