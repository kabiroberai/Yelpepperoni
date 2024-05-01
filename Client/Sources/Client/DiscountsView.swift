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
        guard case .notStarted = phase else { return }
        phase = .loading

        // NB: security flaws aside, this is NOT following IAP best-practices.
        // Read the docs (and/or talk to Josh/RevenueCat) for IAP advice.

        Task {
            for await result in StoreKit.Transaction.updates {
                Task {
                    guard case let .verified(transaction) = result else { return }
                    #warning("TODO: (1) unlock Pro")
                    await transaction.finish()
                    await updateStatus()
                }
            }
        }

        Task { await updateStatus() }
    }

    private func updateStatus() async {
        do {
            try await _updateStatus()
        } catch {
            phase = .failure(error)
        }
    }

    private func _updateStatus() async throws {
        let products = try await Product.products(for: ["com.kabiroberai.Yelpepperoni.pro"])
        guard let product = products.first else {
            throw StringError("Product not found")
        }
        switch await product.currentEntitlement {
        case nil:
            phase = .notPurchased
        case .unverified, .verified:
            phase = .purchased
        }
    }
}
