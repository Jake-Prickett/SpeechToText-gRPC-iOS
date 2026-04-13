# Speech-To-Text gRPC iOS Example

## Description

This application demonstrates bidirectional gRPC streaming to convert live microphone audio into text using Google's Cloud Speech-to-Text API. Built with gRPC Swift v2 (async/await), SwiftUI, and Swift 6 strict concurrency.

Check out the [Medium Article](https://medium.com/macoclock/bidirectional-streaming-with-grpc-swift-d11496ea0b3) for background on the original implementation.

## Technologies

* [gRPC Swift v2](https://github.com/grpc/grpc-swift-2) — async/await-based gRPC framework
* [gRPC Swift NIO Transport](https://github.com/grpc/grpc-swift-nio-transport) — HTTP/2 transport layer
* [gRPC Swift Protobuf](https://github.com/grpc/grpc-swift-protobuf) — protobuf serialization for gRPC Swift
* [Google Speech-To-Text API](https://cloud.google.com/speech-to-text)

## Requirements

* Xcode 16+
* iOS 18.0+
* Swift 6
* A Google Cloud API key with Speech-to-Text enabled

## Acquiring an API Key
This project requires a Google Cloud API Key. Please [register](https://cloud.google.com/apis/docs/getting-started) and [create an API key](https://cloud.google.com/docs/authentication/api-keys) in order to consume the API.

## Project Setup
1. Clone the repository
2. Navigate to the root directory
3. Run `make protos` to pull the most recent .proto files from the googleapis repository
4. Run `make generate` to build the protoc v2 plugins and generate Swift interfaces
5. Open the `.xcodeproj`
6. Open `Sources/Constants.swift` and assign your Google Cloud API Key to the `apiKey` variable
7. Run the application!

## Architecture

* **SpeechService** — actor-based gRPC client using `withGRPCClient` for bidirectional streaming
* **AudioCaptureManager** — `AVAudioEngine`-based audio capture exposing `AsyncStream<Data>`
* **SpeechViewModel** — `@Observable @MainActor` view model bridging audio capture and transcription
* **SpeechToTextView** — SwiftUI view with live transcription display and record/stop button

## Running Tests

```bash
xcodebuild -project SpeechToText-gRPC-iOS.xcodeproj \
  -scheme SpeechToText-gRPC-iOS \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  test
```

## Helpful Links
* [Getting Started with Speech APIs](https://cloud.google.com/speech-to-text/docs/quickstart)
