import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2
import GRPCProtobuf
import Logging

protocol SpeechServiceProtocol: Sendable {
  func streamAudio(_ audioData: AsyncStream<Data>) -> AsyncStream<String>
}

actor SpeechService: SpeechServiceProtocol {
  private let logger = Logger(label: "com.demo.speech-grpc")

  nonisolated func streamAudio(_ audioData: AsyncStream<Data>) -> AsyncStream<String> {
    precondition(
      !Constants.apiKey.isEmpty,
      "Please refer to the README on how to configure your API Key properly."
    )
    return AsyncStream<String> { continuation in
      let task = Task {
        do {
          try await withGRPCClient(
            transport: try .http2NIOPosix(
              target: .dns(host: "speech.googleapis.com", port: 443),
              transportSecurity: .tls
            )
          ) { client in
            let speech = Google_Cloud_Speech_V1_Speech.Client(wrapping: client)

            try await speech.streamingRecognize(
              metadata: ["x-goog-api-key": "\(Constants.apiKey)"]
            ) { writer in
              // First message: streaming config
              let configRequest = Google_Cloud_Speech_V1_StreamingRecognizeRequest.with {
                $0.streamingConfig = .with {
                  $0.config = .with {
                    $0.encoding = .linear16
                    $0.sampleRateHertz = Int32(Constants.sampleRate)
                    $0.languageCode = "en-US"
                    $0.enableAutomaticPunctuation = true
                    $0.metadata = .with {
                      $0.interactionType = .dictation
                      $0.microphoneDistance = .nearfield
                      $0.recordingDeviceType = .smartphone
                    }
                  }
                }
              }
              try await writer.write(configRequest)

              // Subsequent messages: audio data
              for await chunk in audioData {
                let audioRequest = Google_Cloud_Speech_V1_StreamingRecognizeRequest.with {
                  $0.audioContent = chunk
                }
                try await writer.write(audioRequest)
              }
            } onResponse: { response in
              for try await message in response.messages {
                guard let result = message.results.first,
                      let transcript = result.alternatives.first?.transcript
                else { continue }
                continuation.yield(transcript)
              }
            }
          }
          continuation.finish()
        } catch {
          continuation.finish()
        }
      }

      continuation.onTermination = { _ in
        task.cancel()
      }
    }
  }
}
