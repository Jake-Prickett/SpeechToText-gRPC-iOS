import AVFoundation
import Observation

@Observable
@MainActor
final class SpeechViewModel {
  var transcribedText = ""
  var isRecording = false
  var permissionGranted = false
  var errorMessage: String?

  private let speechService: any SpeechServiceProtocol
  private let audioCaptureManager: AudioCaptureManager
  private var streamingTask: Task<Void, Never>?

  init(
    speechService: any SpeechServiceProtocol = SpeechService(),
    audioCaptureManager: AudioCaptureManager = AudioCaptureManager()
  ) {
    self.speechService = speechService
    self.audioCaptureManager = audioCaptureManager
  }

  func requestPermission() async {
    permissionGranted = await AVAudioApplication.requestRecordPermission()
  }

  func toggleRecording() {
    if isRecording {
      stopRecording()
    } else {
      startRecording()
    }
  }

  private func startRecording() {
    transcribedText = ""
    errorMessage = nil

    do {
      let audioStream = audioCaptureManager.audioStream
      try audioCaptureManager.start()
      isRecording = true

      let transcripts = speechService.streamAudio(audioStream)
      streamingTask = Task {
        for await transcript in transcripts {
          self.transcribedText = transcript
        }
        self.isRecording = false
      }
    } catch {
      errorMessage = "Failed to start audio capture: \(error.localizedDescription)"
      isRecording = false
    }
  }

  private func stopRecording() {
    audioCaptureManager.stop()
    streamingTask?.cancel()
    streamingTask = nil
    isRecording = false
  }
}
