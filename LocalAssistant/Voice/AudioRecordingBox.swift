import AVFoundation
import Foundation

/// Synchronizes writes made by the audio render callback to one private recording.
final class AudioRecordingBox: @unchecked Sendable {
    private let file: AVAudioFile
    private let lock = NSLock()

    /// Creates a callback-safe wrapper around a private audio file.
    /// - Parameter file: Audio file opened for writing in the app container.
    internal init(file: AVAudioFile) {
        self.file = file
    }

    /// Appends one microphone buffer from the audio render callback.
    /// - Parameter buffer: Captured PCM audio.
    internal func write(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        defer { lock.unlock() }
        try? file.write(from: buffer)
    }
}
