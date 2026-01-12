import SwiftUI
import Photos

/// Manages access to the photo library and loading images
@MainActor
class PhotoLibraryManager: ObservableObject {
    /// Current authorization status
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined

    /// Whether we have sufficient access to show photos
    var hasAccess: Bool {
        authorizationStatus == .authorized || authorizationStatus == .limited
    }

    /// Image manager for loading photos
    private let imageManager = PHCachingImageManager()

    /// Configuration for stack photos
    private let config: FlickConfiguration

    init(config: FlickConfiguration = .default) {
        self.config = config
        self.authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    /// Request authorization to access photos
    func requestAuthorization() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        self.authorizationStatus = status
    }

    /// Fetch the most recent photos from the library
    /// - Parameter limit: Maximum number of photos to fetch (default 50)
    /// - Returns: Array of StackPhoto objects (images not yet loaded)
    func fetchRecentPhotos(limit: Int = 50) -> [StackPhoto] {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = limit
        fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)

        let fetchResult = PHAsset.fetchAssets(with: fetchOptions)

        var photos: [StackPhoto] = []
        fetchResult.enumerateObjects { asset, _, _ in
            photos.append(StackPhoto(asset: asset, config: self.config))
        }

        return photos
    }

    /// Load an image for a photo asset
    /// - Parameters:
    ///   - asset: The photo asset to load
    ///   - targetSize: Target size for the image (default is screen-appropriate)
    /// - Returns: The loaded UIImage, or nil if loading failed
    func loadImage(for asset: PHAsset, targetSize: CGSize? = nil) async -> UIImage? {
        let size = targetSize ?? CGSize(
            width: UIScreen.main.bounds.width * UIScreen.main.scale,
            height: UIScreen.main.bounds.height * UIScreen.main.scale
        )

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false

        return await withCheckedContinuation { continuation in
            imageManager.requestImage(
                for: asset,
                targetSize: size,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                // Only return the final image, not the degraded placeholder
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if !isDegraded {
                    continuation.resume(returning: image)
                }
            }
        }
    }

    /// Load images for multiple photos concurrently
    /// - Parameter photos: Array of StackPhoto objects to load images for
    /// - Returns: Array of StackPhoto objects with images loaded
    func loadImages(for photos: [StackPhoto]) async -> [StackPhoto] {
        await withTaskGroup(of: (String, UIImage?).self) { group in
            for photo in photos {
                group.addTask {
                    let image = await self.loadImage(for: photo.asset)
                    return (photo.id, image)
                }
            }

            var imageMap: [String: UIImage] = [:]
            for await (id, image) in group {
                if let image = image {
                    imageMap[id] = image
                }
            }

            return photos.map { photo in
                photo.withImage(imageMap[photo.id])
            }
        }
    }
}
