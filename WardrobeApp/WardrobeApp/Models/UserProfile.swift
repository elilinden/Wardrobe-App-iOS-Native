import Foundation
import SwiftData

@Model
final class StylePreferences {
    var dressesFor: String // work, casual, going_out, mix
    var excludedColors: [String]
    var styleDescription: String // minimal, classic, streetwear, etc.
    var decisionTime: String // under_1_min, few_minutes, like_exploring
    var morningNotificationPref: String // notify, check_manually, no

    init(
        dressesFor: String = "mix",
        excludedColors: [String] = [],
        styleDescription: String = "classic",
        decisionTime: String = "under_1_min",
        morningNotificationPref: String = "check_manually"
    ) {
        self.dressesFor = dressesFor
        self.excludedColors = excludedColors
        self.styleDescription = styleDescription
        self.decisionTime = decisionTime
        self.morningNotificationPref = morningNotificationPref
    }
}

@Model
final class UserProfile {
    @Attribute(.unique) var id: UUID
    var stylePreferences: StylePreferences?
    var avatarPhotoFileNames: [String]
    var monthlyRenderCount: Int
    var monthlyRenderResetDate: Date
    var hasUnlimitedRenders: Bool
    var weatherSensitivity: Float
    var reWearGapDays: Int
    var notificationsEnabled: Bool
    var notificationHour: Int
    var notificationMinute: Int
    var eveningReminderEnabled: Bool
    var eveningReminderHour: Int
    var eveningReminderMinute: Int
    var iCloudSyncEnabled: Bool
    var hasCompletedOnboarding: Bool

    var avatarPhotoURLs: [URL] {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let avatarDir = documentsPath.appendingPathComponent("AvatarPhotos")
        return avatarPhotoFileNames.map { avatarDir.appendingPathComponent($0) }
    }

    var canRender: Bool {
        if hasUnlimitedRenders { return true }
        checkAndResetMonthlyCount()
        return monthlyRenderCount < 30
    }

    var rendersRemaining: Int {
        if hasUnlimitedRenders { return Int.max }
        checkAndResetMonthlyCount()
        return max(0, 30 - monthlyRenderCount)
    }

    func incrementRenderCount() {
        checkAndResetMonthlyCount()
        monthlyRenderCount += 1
    }

    private func checkAndResetMonthlyCount() {
        let calendar = Calendar.current
        let now = Date()
        if !calendar.isDate(monthlyRenderResetDate, equalTo: now, toGranularity: .month) {
            monthlyRenderCount = 0
            monthlyRenderResetDate = now
        }
    }

    init() {
        self.id = UUID()
        self.stylePreferences = StylePreferences()
        self.avatarPhotoFileNames = []
        self.monthlyRenderCount = 0
        self.monthlyRenderResetDate = Date()
        self.hasUnlimitedRenders = false
        self.weatherSensitivity = 0.5
        self.reWearGapDays = 14
        self.notificationsEnabled = false
        self.notificationHour = 7
        self.notificationMinute = 0
        self.eveningReminderEnabled = false
        self.eveningReminderHour = 21
        self.eveningReminderMinute = 0
        self.iCloudSyncEnabled = true
        self.hasCompletedOnboarding = false
    }
}
