import Foundation

enum FileStorage {
    private static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static var itemPhotosDirectory: URL {
        documentsDirectory.appendingPathComponent("ItemPhotos")
    }

    static var avatarPhotosDirectory: URL {
        documentsDirectory.appendingPathComponent("AvatarPhotos")
    }

    static var tryOnRendersDirectory: URL {
        documentsDirectory.appendingPathComponent("TryOnRenders")
    }

    static func itemPhotoURL(fileName: String) -> URL {
        itemPhotosDirectory.appendingPathComponent(fileName)
    }

    static func avatarPhotoURL(fileName: String) -> URL {
        avatarPhotosDirectory.appendingPathComponent(fileName)
    }

    static func tryOnRenderURL(fileName: String) -> URL {
        tryOnRendersDirectory.appendingPathComponent(fileName)
    }

    static func ensureDirectoryExists(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    static func deleteFile(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    static func deleteDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
