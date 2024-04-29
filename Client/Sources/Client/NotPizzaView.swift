import SwiftUI
import PhotosUI
import UIKit
import PizzaDetection
import Common

@MainActor struct NotPizzaView: View {
    @State private var selecting = false
    @State private var savedPhoto: PhotosPickerItem?
    @State private var selectedPhoto: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            VStack {
                PhotosPicker(
                    selection: $selectedPhoto,
                    matching: .images,
                    preferredItemEncoding: .compatible
                ) {
                    Label("Select Photo", systemImage: "photo.fill")
                }
                .buttonStyle(.borderedProminent)
                .onChange(of: selectedPhoto) { old, new in
                    guard let new else { return }
                    savedPhoto = new
                    selectedPhoto = nil
                }

                if let savedPhoto {
                    SelectedPhotoView(photo: savedPhoto)
                        .id(savedPhoto)
                }
            }
            .padding()
            .frame(maxHeight: .infinity, alignment: .top)
            .navigationTitle("Not Pizza")
        }
    }
}

@MainActor private struct SelectedPhotoView: View {
    let photo: PhotosPickerItem

    private enum Phase {
        case loading
        case loaded(Image, Data)
        case error(String)
    }

    @State private var phase: Phase = .loading

    var body: some View {
        VStack {
            Group {
                switch phase {
                case .loading:
                    ProgressView()
                case .loaded(let image, _):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                case .error(let error):
                    Text("Load failed: \(error)")
                }
            }
            .frame(height: 300)
            .frame(maxWidth: .infinity)
            .background(Color.gray.quaternary)

            if case .loaded(_, let data) = phase {
                DetectorView(jpegData: data)
            }
        }
        .task {
            async let jpeg = photo.loadTransferable(type: JPEGData.self)
            async let image = photo.loadTransferable(type: Image.self)
            do {
                guard let image = try await image else {
                    phase = .error("Image load failed")
                    return
                }
                guard let jpeg = try await jpeg else {
                    phase = .error("jpeg load failed")
                    return
                }
                phase = .loaded(image, jpeg.data)
            } catch {
                phase = .error("\(error)")
            }
        }
    }
}

@MainActor private struct DetectorView: View {
    private enum Phase {
        case loading
        case detected(Bool)
        case error(String)
    }

    let jpegData: Data
    @State private var phase: Phase = .loading

    var body: some View {
        switch phase {
        case .loading:
            ProgressView()
                .task { await detect() }
        case .detected(true):
            Text("Verdict: **is pizza!**")
        case .detected(false):
            Text("Verdict: **not pizza**. womp womp.")
        case .error(let error):
            Text("Error: \(error)")
        }
    }

    private func detect() async {
        do {
            let verdict = try await GPTPizzaDetector.shared.detectPizza(image: jpegData)
            phase = .detected(verdict)
        } catch {
            phase = .error("\(error)")
        }
    }
}

private struct JPEGData: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .jpeg) {
            JPEGData(data: $0)
        }
        DataRepresentation(importedContentType: .png) {
            guard let data = UIImage(data: $0)?.jpegData(compressionQuality: 0.8) else {
                throw StringError("Bad image")
            }
            return JPEGData(data: data)
        }
    }
}

#Preview {
    NotPizzaView()
}
