import SwiftUI
import Common

@MainActor struct HomeView: View {
    @State private var authManager = AuthManager.shared
    @State private var viewModel = HomeViewModel()

    var body: some View {
        NavigationStack {
            HomeContent(viewModel: viewModel)
                .navigationTitle("Pizzerias")
                .toolbar {
                    ToolbarItem {
                        Button("Log Out") {
                            authManager.logOut()
                        }
                    }
                }
        }
    }
}

@MainActor private struct HomeContent: View {
    let viewModel: HomeViewModel

    var body: some View {
        VStack {
            switch viewModel.result {
            case nil:
                ProgressView()
            case .failure(let error):
                Text("Error: \(error)")
            case .success(let pizzerias):
                List(pizzerias) { pizzeria in
                    NavigationLink {
                        DetailView(pizzeria: pizzeria)
                    } label: {
                        HStack {
                            PhotoView(photo: pizzeria.photos[0])
                                .frame(width: 44, height: 44)
                                .clipShape(Circle())

                            VStack(alignment: .leading) {
                                Text(verbatim: pizzeria.name)
                                    .font(.headline)

                                Text(verbatim: pizzeria.address)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text("\(pizzeria.rating, format: .number.precision(.fractionLength(1))) / 5")
                        }
                    }
                }
            }
        }
        .task { await viewModel.fetch() }
    }
}

@MainActor @Observable private final class HomeViewModel {
    var result: Result<[Pizzeria], Error>?

    init(result: Result<[Pizzeria], Error>? = nil) {
        self.result = result
    }

    func fetch() async {
        guard result == nil else { return }
        do {
            result = .success(try await APIClient.shared.getPizzerias())
        } catch {
            result = .failure(error)
        }
    }
}

#Preview {
    HomeContent(
        viewModel: HomeViewModel(result: .success([
            Pizzeria(
                id: "1",
                name: "My Pizzeria",
                address: "1 Pizza St",
                rating: 4.5,
                photos: [
                    Pizzeria.Photo(
                        id: "abc",
                        filename: "foo.png",
                        description: "abc"
                    )
                ]
            ),
            Pizzeria(
                id: "2",
                name: "My Pizzeria",
                address: "1 Pizza St",
                rating: 4.5,
                photos: [
                    Pizzeria.Photo(
                        id: "def",
                        filename: "foo.png",
                        description: "abc"
                    )
                ]
            )
        ]))
    )
}
