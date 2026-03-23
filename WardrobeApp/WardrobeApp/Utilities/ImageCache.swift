import UIKit

final class ImageCache {
    static let shared = ImageCache()

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 200
        cache.totalCostLimit = 100 * 1024 * 1024 // 100 MB
    }

    func load(from url: URL) -> UIImage? {
        let key = url.absoluteString as NSString

        if let cached = cache.object(forKey: key) {
            return cached
        }

        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else {
            return nil
        }

        cache.setObject(image, forKey: key)
        return image
    }

    func invalidate(for url: URL) {
        cache.removeObject(forKey: url.absoluteString as NSString)
    }

    func clearAll() {
        cache.removeAllObjects()
    }
}
