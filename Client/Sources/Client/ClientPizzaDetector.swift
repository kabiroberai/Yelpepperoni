import PizzaDetection
import Foundation

typealias PizzaDetector = SecurePizzaDetector

final class SecurePizzaDetector {
    static let shared = SecurePizzaDetector()

    private init() {}

    func detectPizza(image: Data) async throws -> Bool {
        try await APIClient.shared.detectPizza(jpeg: image)
    }
}
