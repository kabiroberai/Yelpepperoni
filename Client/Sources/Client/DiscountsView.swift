import SwiftUI
import StoreKit
import Common

@MainActor struct DiscountsView: View {
    @State private var viewModel = DiscountsViewModel()

    var body: some View {
        NavigationStack {
            VStack {
                switch viewModel.phase {
                case .notStarted, .loading:
                    ProgressView()
                case .failure(let error):
                    Text("Error: \(error)")
                case .notPurchased:
                    StoreView(ids: ["com.kabiroberai.Yelpepperoni.pro"])
                case .purchased:
                    UnlockedDiscountsView()
                }
            }
            .navigationTitle("Discounts")
            .onAppear {
                viewModel.onAppear()
            }
        }
    }
}

@Observable @MainActor private final class DiscountsViewModel {
    enum Phase {
        case notStarted
        case loading
        case notPurchased
        case purchased
        case failure(Error)
    }

    var phase = Phase.notStarted

    func onAppear() {
//        hook()

        guard case .notStarted = phase else { return }
        phase = .loading

        Task {
            for await result in StoreKit.Transaction.updates {
                Task {
                    guard case let .verified(transaction) = result else { return }
                    try await APIClient.shared.unlockPro(receipt: result.jwsRepresentation)
                    await transaction.finish()
                }
            }
        }

        Task {
            do {
                try await updateStatus()
                for await _ in StoreKit.Transaction.updates {
                    try await updateStatus()
                }
            } catch {
                phase = .failure(error)
            }
        }
    }

    private func updateStatus() async throws {
        let products = try await Product.products(for: ["com.kabiroberai.Yelpepperoni.pro"])
        guard let product = products.first else {
            throw StringError("Product not found")
        }
        switch await product.currentEntitlement {
        case nil:
            phase = .notPurchased
        case .unverified(_, let error):
            throw StringError("verification failed: \(error)")
        default:
            phase = .purchased
        }
    }
}