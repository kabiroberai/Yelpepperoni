import SwiftUI
import Common

@MainActor struct PhotoView: View {
    let photo: Pizzeria.Photo

    var body: some View {
        _PhotoView(photo: photo)
            .id(photo.id)
    }
}

@MainActor struct _PhotoView: View {
    @State private var viewModel: PhotoViewModel

    init(photo: Pizzeria.Photo) {
        _viewModel = State(wrappedValue: PhotoViewModel(photo: photo))
    }

    var body: some View {
        VStack {
            switch viewModel.phase {
            case .loading:
                ProgressView()
            case .failed(let error):
                Text("Error: \(error)")
            case .loaded(let image):
                image
                    .resizable()
            }
        }
        .task {
            await viewModel.load()
        }
    }
}

@Observable @MainActor final class PhotoViewModel {
    enum Phase {
        case loading
        case loaded(Image)
        case failed(Error)
    }

    let photo: Pizzeria.Photo
    var phase = Phase.loading

    private let files = FileManager.default

    init(photo: Pizzeria.Photo) {
        self.photo = photo
    }

    func load() async {
        guard case .loading = phase else { return }
        do {
            let url = try await downloadPizzeriaPhoto()
            guard let image = UIImage(contentsOfFile: url.path()) else {
                throw StringError("Bad image")
            }
            phase = .loaded(Image(uiImage: image))
        } catch {
            if Task.isCancelled { return }
            phase = .failed(error)
        }
    }

    private func downloadPizzeriaPhoto() async throws -> URL {
        let photosDirectory = URL.cachesDirectory.appending(path: "PizzeriaPhotos")
        try? files.createDirectory(at: photosDirectory, withIntermediateDirectories: true)

        let destination = photosDirectory.appending(path: photo.filename)
        #warning("TODO: (1) check for containment")

        try await APIClient.shared.downloadPizzeriaPhoto(photo, to: destination)
        return destination
    }
}

extension URL {
    func isContained(in parent: URL) -> Bool {
        let sanitizedParent = URL(filePath: parent.path(), directoryHint: .isDirectory).standardized
        let sanitizedPath   = URL(filePath: path().replacingOccurrences(of: "//", with: "/")).standardized
        return sanitizedPath.absoluteString.hasPrefix(sanitizedParent.absoluteString)
    }
}
