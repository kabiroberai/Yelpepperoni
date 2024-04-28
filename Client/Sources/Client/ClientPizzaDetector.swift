import PizzaDetection
import Foundation

typealias PizzaDetector = GPTPizzaDetector

final class SecurePizzaDetector {
    static let shared = SecurePizzaDetector()

    private init() {}

    func detectPizza(image: Data) async throws -> Bool {
        false
    }
}
