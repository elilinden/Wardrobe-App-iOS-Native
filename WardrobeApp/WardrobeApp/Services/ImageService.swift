import Foundation
import UIKit
import Vision

actor ImageService {
    static let shared = ImageService()

    // MARK: - Background Removal

    func removeBackground(from image: UIImage) async -> UIImage {
        guard #available(iOS 17.0, *), let cgImage = image.cgImage else {
            return image
        }

        do {
            let request = VNGenerateForegroundInstanceMaskRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try handler.perform([request])

            guard let result = request.results?.first else { return image }

            let mask = try result.generateScaledMaskForImage(
                forInstances: result.allInstances,
                from: handler
            )

            let ciMask = CIImage(cvPixelBuffer: mask)
            let ciOriginal = CIImage(cgImage: cgImage)
            let ciClear = CIImage(color: .clear).cropped(to: ciOriginal.extent)

            guard let blendFilter = CIFilter(name: "CIBlendWithMask") else { return image }
            blendFilter.setValue(ciOriginal, forKey: kCIInputImageKey)
            blendFilter.setValue(ciClear, forKey: kCIInputBackgroundImageKey)
            blendFilter.setValue(ciMask, forKey: kCIInputMaskImageKey)

            let context = CIContext()
            guard let output = blendFilter.outputImage,
                  let outputCG = context.createCGImage(output, from: ciOriginal.extent) else {
                return image
            }
            return UIImage(cgImage: outputCG)
        } catch {
            return image
        }
    }

    // MARK: - Save (nonisolated — no mutable actor state needed)

    nonisolated func saveItemPhoto(_ image: UIImage, fileName: String) throws {
        try FileStorage.ensureDirectoryExists(FileStorage.itemPhotosDirectory)
        let url = FileStorage.itemPhotoURL(fileName: fileName)
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            throw ImageServiceError.compressionFailed
        }
        try data.write(to: url)
    }

    nonisolated func saveAvatarPhoto(_ image: UIImage, fileName: String) throws {
        try FileStorage.ensureDirectoryExists(FileStorage.avatarPhotosDirectory)
        let url = FileStorage.avatarPhotoURL(fileName: fileName)
        guard let data = image.jpegData(compressionQuality: 0.9) else {
            throw ImageServiceError.compressionFailed
        }
        try data.write(to: url)
    }

    nonisolated func saveTryOnRender(_ image: UIImage) throws -> String {
        try FileStorage.ensureDirectoryExists(FileStorage.tryOnRendersDirectory)
        let fileName = "\(UUID().uuidString).jpg"
        let url = FileStorage.tryOnRenderURL(fileName: fileName)
        guard let data = image.jpegData(compressionQuality: 0.9) else {
            throw ImageServiceError.compressionFailed
        }
        try data.write(to: url)
        return fileName
    }

    // MARK: - Collage

    nonisolated func generateFlatLayCollage(
        items: [WardrobeItem],
        size: CGSize = CGSize(width: 600, height: 800)
    ) -> UIImage {
        let images = items.compactMap { ImageCache.shared.load(from: $0.photoURL) }
        guard !images.isEmpty else {
            return UIImage()
        }

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.systemBackground.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            let columns = images.count <= 2 ? images.count : min(3, images.count)
            let rows = (images.count + columns - 1) / columns
            let itemW = size.width / CGFloat(columns)
            let itemH = size.height / CGFloat(rows)
            let pad: CGFloat = 8

            for (i, image) in images.enumerated() {
                let col = i % columns
                let row = i / columns
                let rect = CGRect(
                    x: CGFloat(col) * itemW + pad,
                    y: CGFloat(row) * itemH + pad,
                    width: itemW - pad * 2,
                    height: itemH - pad * 2
                )
                image.draw(in: rect)
            }
        }
    }
}

enum ImageServiceError: LocalizedError {
    case compressionFailed

    var errorDescription: String? { "Failed to process image." }
}
