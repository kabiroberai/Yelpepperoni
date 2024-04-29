import SwiftUI
import Common

@MainActor struct UnlockedDiscountsView: View {
    @State private var viewModel = UnlockedDiscountsViewModel()

    var body: some View {
        VStack {
            switch viewModel.phase {
            case .notStarted, .loading:
                ProgressView()
            case .failed(let error):
                Text("Error: \(error)")
            case .loaded(let discounts):
                DiscountsListView(discounts: discounts)
            }
        }
        .onAppear {
            viewModel.onAppear()
        }
    }
}

@MainActor private struct DiscountsListView: View {
    let discounts: [Discount]
    var body: some View {
        List(discounts) { discount in
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: discount.title)
                    .font(.title3)

                Text(verbatim: discount.code)
                    .foregroundStyle(.black)
                    .bold()
                    .padding(8)
                    .background {
                        RoundedRectangle(cornerRadius: 4)
                            .foregroundStyle(.green)
                    }
            }
        }
    }
}

@MainActor @Observable final class UnlockedDiscountsViewModel {
    enum Phase {
        case notStarted
        case loading
        case failed(Error)
        case loaded([Discount])
    }

    var phase = Phase.notStarted

    func onAppear() {
        guard case .notStarted = phase else { return }
        phase = .loading

        Task {
            do {
                let discounts = try await APIClient.shared.getDiscounts()
                phase = .loaded(discounts)
            } catch {
                phase = .failed(error)
            }
        }
    }
}

#Preview {
    DiscountsListView(discounts: [
        Discount(id: "1", title: "50% off ALL pizzas!", code: "50-OFF")
    ])
}
