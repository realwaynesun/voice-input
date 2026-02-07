import Foundation

protocol TextProcessor {
    func process(_ text: String, language: String?) async throws -> String
}
