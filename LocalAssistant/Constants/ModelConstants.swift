import Foundation

/// Names and integrity values for locally installed inference assets.
enum ModelConstants {
    enum Chat {
        static let filename = "Qwen3-4B-Q4_K_M.gguf"
        static let sha256 = "7485fe6f11af29433bc51cab58009521f205840f5b4ae3a32fa7f92e8534fdf5"
        static let role = "chat"
    }

    enum Embedding {
        static let filename = "Qwen3-Embedding-0.6B-Q8_0.gguf"
        static let sha256 = "06507c7b42688469c4e7298b0a1e16deff06caf291cf0a5b278c308249c3e439"
        static let role = "embedding"
        static let queryPrefix = "Instruct: Retrieve files relevant to the request\nQuery: "
        static let documentPrefix = "Represent this file passage for retrieval: "
    }

    enum Speech {
        static let directoryName = "openai_whisper-small"
        static let role = "speech"
    }
}
