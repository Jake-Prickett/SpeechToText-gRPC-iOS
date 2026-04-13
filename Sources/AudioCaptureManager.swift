import AVFoundation
import Foundation

enum AudioCaptureError: Error, Sendable {
  case engineStartFailed(any Error)
  case noInputNode
}

@MainActor
final class AudioCaptureManager: Sendable {
  private let engine = AVAudioEngine()

  var audioStream: AsyncStream<Data> {
    AsyncStream { continuation in
      let inputNode = engine.inputNode
      let recordingFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: Constants.sampleRate,
        channels: 1,
        interleaved: true
      )!

      inputNode.installTap(
        onBus: 0,
        bufferSize: AVAudioFrameCount(Constants.sampleRate * 0.1),
        format: recordingFormat
      ) { buffer, _ in
        guard let channelData = buffer.int16ChannelData else { return }
        let frameCount = Int(buffer.frameLength)
        let data = Data(
          bytes: channelData[0],
          count: frameCount * MemoryLayout<Int16>.size
        )
        continuation.yield(data)
      }

      continuation.onTermination = { [weak self] _ in
        MainActor.assumeIsolated {
          self?.engine.inputNode.removeTap(onBus: 0)
        }
      }
    }
  }

  func start() throws {
    do {
      try engine.start()
    } catch {
      throw AudioCaptureError.engineStartFailed(error)
    }
  }

  func stop() {
    engine.stop()
    engine.inputNode.removeTap(onBus: 0)
  }
}
