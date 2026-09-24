import Foundation

/// Names and integrity values for locally installed inference assets.
internal enum ModelConstants {
    internal enum Chat {
        internal static let filename = "Qwen3-4B-Q4_K_M.gguf"
        internal static let sha256 = "7485fe6f11af29433bc51cab58009521f205840f5b4ae3a32fa7f92e8534fdf5"
        internal static let role = "chat"
    }

    internal enum Embedding {
        internal static let filename = "Qwen3-Embedding-0.6B-Q8_0.gguf"
        internal static let sha256 = "06507c7b42688469c4e7298b0a1e16deff06caf291cf0a5b278c308249c3e439"
        internal static let role = "embedding"
        internal static let queryPrefix = "Instruct: Retrieve files relevant to the request\nQuery: "
        internal static let documentPrefix = "Represent this file passage for retrieval: "
    }

    internal enum Speech {
        internal static let directoryName = "openai_whisper-small"
        internal static let role = "speech"

        /// Tokenizer files the speech runtime reads from the installed model directory.
        ///
        /// Without them the runtime has no way to turn audio into text offline, so voice
        /// input is not installed even though the Core ML model directory is present.
        internal static let requiredTokenizerFiles = ["tokenizer.json", "tokenizer_config.json"]
    }
}
