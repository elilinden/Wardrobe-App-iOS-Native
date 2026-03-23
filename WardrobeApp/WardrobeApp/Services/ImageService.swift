import Foundation
import UIKit
import Vision

class ImageService {

    static let shared = ImageService()
    private init() {}

    // MARK: - Background Removal using Vision

    func removeBackground(from image: UIImage) async -> UIImage {
        guard #available(iOS 17.0, *) else {
            return image // Fallback: return original on iOS 16
        }

        return await withCheckedContinuation { continuation in
            guard let cgImage = image.cgImage else {
                continuation.resume(returning: image)
                return
            }

            let request = VNGenerateForegroundInstanceMaskRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
                guard let result = request.results?.first else {
                    continuation.resume(returning: image)
                    return
                }

                let maskPixelBuffer = try result.generateScaledMaskForImage(
                    forInstances: result.allInstances,
                    from: handler
                )

                let ciImage = CIImage(cvPixelBuffer: maskPixelBuffer)
                let originalCI = CIImage(cgImage: cgImage)

                let filter = CIFilter(name: "CIBlendWithMask")!
                filter.setValue(originalCI, forKey: kCIInputImageKey)
                filter.setValue(CIImage(color: .clear).cropped(to: originalCI.extent), forKey: kCIInputBackgroundImageKey)
                filter.setValue(ciImage, forKey: kCIInputMaskImageKey)

                let context = CIContext()
                if let outputImage = filter.outputImage,
                   let outputCG = context.createCGImage(outputImage, from: originalCI.extent) {
                    continuation.resume(returning: UIImage(cgImage: outputCG))
                } else {
                    continuation.resume(returning: image)
                }
            } catch {
                continuation.resume(returning: image)
            }
        }
    }

    // MARK: - Image Saving

    func saveItemPhoto(_ image: UIImage, fileName: String) throws -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let photosDir = documentsPath.appendingPathComponent("ItemPhotos")

        try FileManager.default.createDirectory(at: photosDir, withIntermediateDirectories: true)

        let fileURL = photosDir.appendingPathComponent(fileName)
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            throw ImageError.compressionFailed
        }
        try data.write(to: fileURL)
        return fileURL
    }

    func saveAvatarPhoto(_ image: UIImage, fileName: String) throws -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let avatarDir = documentsPath.appendingPathComponent("AvatarPhotos")

        try FileManager.default.createDirectory(at: avatarDir, withIntermediateDirectories: true)

        let fileURL = avatarDir.appendingPathComponent(fileName)
        guard let data = image.jpegData(compressionQuality: 0.9) else {
            throw ImageError.compressionFailed
        }
        try data.write(to: fileURL)
        return fileURL
    }

    func saveTryOnRender(_ image: UIImage, fileName: String) throws -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let rendersDir = documentsPath.appendingPathComponent("TryOnRenders")

        try FileManager.default.createDirectory(at: rendersDir, withIntermediateDirectories: true)

        let fileURL = rendersDir.appendingPathComponent(fileName)
        guard let data = image.jpegData(compressionQuality: 0.9) else {
            throw ImageError.compressionFailed
        }
        try data.write(to: fileURL)
        return fileURL
    }

    func loadImage(from url: URL) -> UIImage? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    // MARK: - Collage Generation

    func generateFlatLayCollage(items: [UIImage], size: CGSize = CGSize(width: 600, height: 800)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.systemBackground.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let count = items.count
            guard count > 0 else { return }

            let columns = count <= 2 ? count : min(3, count)
            let rows = (count + columns - 1) / columns
            let itemWidth = size.width / CGFloat(columns)
            let itemHeight = size.height / CGFloat(rows)
            let padding: CGFloat = 8

            for (index, image) in items.enumerated() {
                let col = index % columns
                let row = index / columns
                let rect = CGRect(
                    x: CGFloat(col) * itemWidth + padding,
                    y: CGFloat(row) * itemHeight + padding,
                    width: itemWidth - padding * 2,
                    height: itemHeight - padding * 2
                )
                image.draw(in: rect)
            }
        }
    }
}

enum ImageError: LocalizedError {
    case compressionFailed

    var errorDescription: String? {
        "Failed to process image."
    }
}
