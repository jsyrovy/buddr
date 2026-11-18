import Foundation

extension JSONDecoder {
    /// Reads the snake_case keys of every backend's JSON (`workspace_id`, `status_ms`, `updated_at`) into camelCase
    /// properties.
    static let snakeCase: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
}
