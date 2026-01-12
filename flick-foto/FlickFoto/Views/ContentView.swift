import SwiftUI
import Photos

/// Main content view handling permissions and displaying the photo stack
struct ContentView: View {
    @StateObject private var photoManager = PhotoLibraryManager()
    @State private var photos: [StackPhoto] = []
    @State private var isLoading = false
    @State private var config = FlickConfiguration.default

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color.gray.opacity(0.2), Color.gray.opacity(0.4)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Content based on authorization status
            switch photoManager.authorizationStatus {
            case .notDetermined:
                requestAccessView

            case .restricted:
                restrictedAccessView

            case .denied:
                deniedAccessView

            case .authorized, .limited:
                if isLoading {
                    loadingView
                } else {
                    photoStackView
                }

            @unknown default:
                requestAccessView
            }
        }
        .task {
            await checkAndLoadPhotos()
        }
    }

    // MARK: - Permission Views

    private var requestAccessView: some View {
        VStack(spacing: 24) {
            Image(systemName: "photo.stack")
                .font(.system(size: 64))
                .foregroundColor(.gray)

            Text("Flick Foto")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("We need access to your photos to get started.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: {
                Task {
                    await photoManager.requestAuthorization()
                    await checkAndLoadPhotos()
                }
            }) {
                Text("Allow Access")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
    }

    private var restrictedAccessView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("Access Restricted")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Photo access is restricted on this device.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private var deniedAccessView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(.red)

            Text("Access Denied")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Please enable photo access in Settings to use Flick Foto.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: openSettings) {
                Text("Open Settings")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Loading photos...")
                .font(.body)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Photo Stack

    private var photoStackView: some View {
        VStack {
            // Header with count
            HStack {
                Text("\(photos.count) photos remaining")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top)

            Spacer()

            // The main photo stack
            PhotoStackView(
                photos: $photos,
                config: config,
                onFlick: handleFlick
            )

            Spacer()

            // Action hints
            HStack {
                Label("Delete", systemImage: "arrow.down")
                    .font(.caption)
                    .foregroundColor(.red.opacity(0.7))

                Spacer()

                Label("Favorite", systemImage: "arrow.up")
                    .font(.caption)
                    .foregroundColor(.green.opacity(0.7))
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Actions

    private func checkAndLoadPhotos() async {
        // Check if we need to request authorization
        if photoManager.authorizationStatus == .notDetermined {
            return // Wait for user to tap button
        }

        guard photoManager.hasAccess else { return }

        isLoading = true

        // Fetch photos
        let fetchedPhotos = photoManager.fetchRecentPhotos(limit: 50)

        // Load images for visible cards first, then the rest
        let visibleCount = config.visibleCardCount
        let visiblePhotos = Array(fetchedPhotos.prefix(visibleCount))
        let remainingPhotos = Array(fetchedPhotos.dropFirst(visibleCount))

        // Load visible photos first
        let loadedVisible = await photoManager.loadImages(for: visiblePhotos)
        photos = loadedVisible + remainingPhotos
        isLoading = false

        // Load remaining photos in background
        if !remainingPhotos.isEmpty {
            let loadedRemaining = await photoManager.loadImages(for: remainingPhotos)
            // Update only the remaining photos (visible ones already set)
            for loadedPhoto in loadedRemaining {
                if let index = photos.firstIndex(where: { $0.id == loadedPhoto.id }) {
                    photos[index] = loadedPhoto
                }
            }
        }
    }

    private func handleFlick(photo: StackPhoto, direction: FlickDirection) {
        // Log the action (POC - no actual photo library modification)
        print("\(direction.emoji) \(direction.actionName) photo: \(photo.id)")
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
