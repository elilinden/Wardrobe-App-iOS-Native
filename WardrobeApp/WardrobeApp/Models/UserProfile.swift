import Foundation
import SwiftData

@Model
final class StylePreferences {
    var dressesFor: String
    var excludedColors: [String]
    var styleDescription: String
    var decisionTime: String
    var morningNotificationPref: String

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
    var thumbsDownOutfitSets: [[String]] // stored as arrays of UUID strings

    // MARK: Computed Properties

    var avatarPhotoURLs: [URL] {
        avatarPhotoFileNames.map { FileStorage.avatarPhotoURL(fileName: $0) }
    }

    var hasAvatarPhotos: Bool {
        !avatarPhotoFileNames.isEmpty
    }

    var canRender: Bool {
        if hasUnlimitedRenders { return true }
        refreshMonthlyCountIfNeeded()
        return monthlyRenderCount < DS.monthlyRenderLimit
    }

    var rendersRemaining: Int {
        if hasUnlimitedRenders { return Int.max }
        refreshMonthlyCountIfNeeded()
        return max(0, DS.monthlyRenderLimit - monthlyRenderCount)
    }

    var rendersUsedText: String {
        if hasUnlimitedRenders { return "Unlimited" }
        return "\(monthlyRenderCount) of \(DS.monthlyRenderLimit)"
    }

    var thumbsDownHistory: Set<Set<UUID>> {
        Set(thumbsDownOutfitSets.map { set in
            Set(set.compactMap { UUID(uuidString: $0) })
        })
    }

    // MARK: Init

    init() {
        self.id = UUID()
        self.stylePreferences = StylePreferences()
        self.avatarPhotoFileNames = []
        self.monthlyRenderCount = 0
        self.monthlyRenderResetDate = Date()
        self.hasUnlimitedRenders = false
        self.weatherSensitivity = 0.5
        self.reWearGapDays = DS.defaultReWearGapDays
        self.notificationsEnabled = false
        self.notificationHour = 7
        self.notificationMinute = 0
        self.eveningReminderEnabled = false
        self.eveningReminderHour = 21
        self.eveningReminderMinute = 0
        self.iCloudSyncEnabled = true
        self.hasCompletedOnboarding = false
        self.thumbsDownOutfitSets = []
    }

    // MARK: Actions

    func incrementRenderCount() {
        refreshMonthlyCountIfNeeded()
        monthlyRenderCount += 1
    }

    func addThumbsDown(itemIDs: Set<UUID>) {
        let strings = itemIDs.map(\.uuidString)
        thumbsDownOutfitSets.append(strings)
    }

    private func refreshMonthlyCountIfNeeded() {
        let calendar = Calendar.current
        if !calendar.isDate(monthlyRenderResetDate, equalTo: Date(), toGranularity: .month) {
            monthlyRenderCount = 0
            monthlyRenderResetDate = Date()
        }
    }

    func cleanupAllPhotos() {
        for url in avatarPhotoURLs {
            ImageCache.shared.invalidate(for: url)
        }
        FileStorage.deleteDirectory(FileStorage.itemPhotosDirectory)
        FileStorage.deleteDirectory(FileStorage.avatarPhotosDirectory)
        FileStorage.deleteDirectory(FileStorage.tryOnRendersDirectory)
    }
}
