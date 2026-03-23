import SwiftUI
import SwiftData

struct AvatarSetupScreen: View {
    var onContinue: (() -> Void)? = nil
    var onComplete: (() -> Void)? = nil
    @Environment(\.modelContext) private var modelContext
    @State private var photos: [AvatarSlot: UIImage] = [:]
    @State private var activeSlot: AvatarSlot?
    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    @State private var showInfo = false
    @State private var errorMessage: String?

    enum AvatarSlot: String, CaseIterable {
        case front = "Front"
        case slightLeft = "Slight Left"
        case slightRight = "Slight Right"

        var fileName: String {
            switch self {
            case .front: return "front.jpg"
            case .slightLeft: return "left.jpg"
            case .slightRight: return "right.jpg"
            }
        }
    }

    private var allCaptured: Bool {
        AvatarSlot.allCases.allSatisfy { photos[$0] != nil }
    }

    var body: some View {
        VStack(spacing: DS.spacingXL) {
            ProgressDots(step: 1, totalSteps: 4)
                .padding(.top, DS.spacingLG)

            VStack(spacing: DS.spacingSM) {
                Text("Build Your Avatar")
                    .font(.title.weight(.bold))

                HStack(spacing: DS.spacingXS) {
                    Text("Take 3 photos so we can show outfits on you.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button { showInfo = true } label: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack(spacing: DS.spacingLG) {
                ForEach(AvatarSlot.allCases, id: \.rawValue) { slot in
                    avatarSlot(slot)
                }
            }
            .padding(.horizontal, DS.spacingXL)

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .transition(.opacity)
            }

            Spacer()

            Button(action: saveAndContinue) {
                Text("Continue")
            }
            .buttonStyle(GlassButtonStyle())
            .disabled(!allCaptured)
            .opacity(allCaptured ? 1 : 0.5)
            .padding(.horizontal, DS.spacingXL)
            .padding(.bottom, 50)
        }
        .sheet(isPresented: $showCamera) {
            ImagePicker(image: $capturedImage, sourceType: .camera)
        }
        .onChange(of: capturedImage) { _, newImage in
            if let newImage, let slot = activeSlot {
                photos[slot] = newImage
                capturedImage = nil
            }
        }
        .alert("Why do we need this?", isPresented: $showInfo) {
            Button("Got it", role: .cancel) {}
        } message: {
            Text("These photos are used only for try-on renders. Stored locally on your device and iCloud. Never shared, never used for training.")
        }
    }

    private func avatarSlot(_ slot: AvatarSlot) -> some View {
        VStack(spacing: DS.spacingSM) {
            Button {
                activeSlot = slot
                showCamera = true
                Haptic.selection()
            } label: {
                ZStack {
                    if let image = photos[slot] {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .clipShape(RoundedRectangle(cornerRadius: DS.radiusLG))
                            .overlay {
                                RoundedRectangle(cornerRadius: DS.radiusLG)
                                    .strokeBorder(Color.accentColor, lineWidth: 2)
                            }
                    } else {
                        RoundedRectangle(cornerRadius: DS.radiusLG)
                            .fill(.ultraThinMaterial)
                            .overlay {
                                VStack(spacing: DS.spacingSM) {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 28))
                                        .foregroundStyle(.quaternary)
                                    Image(systemName: "camera.fill")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: DS.radiusLG)
                                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                            }
                    }
                }
                .aspectRatio(0.65, contentMode: .fit)
            }

            Text(slot.rawValue)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    private func saveAndContinue() {
        var fileNames: [String] = []

        for slot in AvatarSlot.allCases {
            guard let image = photos[slot] else { return }
            do {
                try ImageService.shared.saveAvatarPhoto(image, fileName: slot.fileName)
                fileNames.append(slot.fileName)
            } catch {
                errorMessage = "Failed to save photo."
                Haptic.error()
                return
            }
        }

        // Check if retaking (profile already exists)
        let descriptor = FetchDescriptor<UserProfile>()
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.avatarPhotoFileNames = fileNames
            AppLog.ui.info("Avatar photos retaken, \(fileNames.count) photos saved")
        } else {
            let profile = UserProfile()
            profile.avatarPhotoFileNames = fileNames
            modelContext.insert(profile)
            AppLog.ui.info("New avatar profile created with \(fileNames.count) photos")
        }

        do {
            try modelContext.save()
        } catch {
            AppLog.data.error("Failed to save avatar photos: \(error.localizedDescription)")
        }

        Haptic.success()
        if let onComplete {
            onComplete()
        } else {
            onContinue?()
        }
    }
}
