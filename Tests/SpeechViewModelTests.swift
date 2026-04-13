import Testing
import Foundation
@testable import gRPC_Example

struct MockSpeechService: SpeechServiceProtocol {
  let transcripts: [String]

  init(transcripts: [String] = []) {
    self.transcripts = transcripts
  }

  func streamAudio(_ audioData: AsyncStream<Data>) -> AsyncStream<String> {
    AsyncStream { continuation in
      for transcript in transcripts {
        continuation.yield(transcript)
      }
      continuation.finish()
    }
  }
}

@MainActor
struct MockAudioCaptureManager: AudioCaptureManaging {
  var audioStream: AsyncStream<Data> {
    AsyncStream { $0.finish() }
  }

  func start() throws {}
  func stop() {}
}

@Suite("SpeechViewModel Tests")
struct SpeechViewModelTests {

  @Test("Initial state is not recording")
  @MainActor
  func initialState() {
    let viewModel = SpeechViewModel(
      speechService: MockSpeechService(),
      audioCaptureManager: MockAudioCaptureManager()
    )
    #expect(viewModel.isRecording == false)
    #expect(viewModel.transcribedText == "")
    #expect(viewModel.errorMessage == nil)
  }

  @Test("Toggle recording changes isRecording state")
  @MainActor
  func toggleRecordingUpdatesState() async throws {
    let viewModel = SpeechViewModel(
      speechService: MockSpeechService(transcripts: ["Hello"]),
      audioCaptureManager: MockAudioCaptureManager()
    )
    // Grant permission first (simulated by directly setting)
    viewModel.permissionGranted = true

    viewModel.toggleRecording()
    #expect(viewModel.isRecording == true)

    viewModel.toggleRecording()
    #expect(viewModel.isRecording == false)
  }

  @Test("Transcription updates flow from mock service")
  @MainActor
  func transcriptionUpdates() async throws {
    let viewModel = SpeechViewModel(
      speechService: MockSpeechService(transcripts: ["Hello", "Hello world"]),
      audioCaptureManager: MockAudioCaptureManager()
    )
    viewModel.permissionGranted = true

    viewModel.toggleRecording()

    // Wait for the async stream to deliver transcripts
    try await Task.sleep(for: .milliseconds(100))

    #expect(viewModel.transcribedText == "Hello world")
  }

  @Test("Stop cancels streaming task")
  @MainActor
  func stopCancelsTask() async throws {
    let viewModel = SpeechViewModel(
      speechService: MockSpeechService(transcripts: []),
      audioCaptureManager: MockAudioCaptureManager()
    )
    viewModel.permissionGranted = true

    viewModel.toggleRecording()
    #expect(viewModel.isRecording == true)

    viewModel.toggleRecording()
    #expect(viewModel.isRecording == false)
  }
}
