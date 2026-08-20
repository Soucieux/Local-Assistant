import AVFoundation
import Foundation

/// Synchronizes writes made by the audio render callback to one private recording.
final class AudioRecordingBox: @unchecked Sendable {
    private var file: AVAudioFile?
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
        try? file?.write(from: buffer)
    }

    /// Releases the audio file so its captured samples are complete on disk.
    ///
    /// The recording is read back immediately after capture stops, so the writer must be
    /// closed first rather than left for a later deallocation.
    internal func close() {
        lock.lock()
        defer { lock.unlock() }
        file = nil
    }
}
