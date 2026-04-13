# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

iOS app demonstrating bidirectional gRPC streaming for real-time speech-to-text using Google's Cloud Speech API. Built with gRPC Swift v2 (async/await), SwiftUI, and Swift 6 strict concurrency. Captures microphone audio via AVAudioEngine and streams 100ms chunks to Google's API, displaying transcription results live.

## Build & Run

This is an Xcode project using Swift Package Manager for dependencies.

```bash
# Generate protobuf Swift files (required before first build)
make protos      # Downloads googleapis .proto files
make plugins     # Builds v2 protoc plugins from source
make generate    # Runs protoc to generate Swift bindings

# Clean generated files
make clean
```

Build and run via Xcode (Cmd+R). Requires:
- Xcode 16+, Swift 6, iOS 18.0+
- A Google Cloud API key set in `Sources/Constants.swift` (`Constants.apiKey`)
- Microphone permission (configured in Info.plist)

## Running Tests

```bash
xcodebuild -project SpeechToText-gRPC-iOS.xcodeproj \
  -scheme SpeechToText-gRPC-iOS \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  test
```

Tests use Swift Testing framework (`import Testing`, `@Test`, `#expect`). All hardware dependencies (audio, gRPC) are mocked via protocols.

## Architecture

Four main components with clear separation of concerns:

- **SpeechService** (`Sources/SpeechService.swift`) — Actor-based gRPC client using `withGRPCClient` for bidirectional streaming to `speech.googleapis.com:443`. Accepts `AsyncStream<Data>` of audio, returns `AsyncStream<String>` of transcripts. Conforms to `SpeechServiceProtocol` for testability.

- **AudioCaptureManager** (`Sources/AudioCaptureManager.swift`) — `@MainActor` class that captures microphone audio via `AVAudioEngine`. Exposes audio as `AsyncStream<Data>`. Conforms to `AudioCaptureManaging` protocol for testability.

- **SpeechViewModel** (`Sources/SpeechViewModel.swift`) — `@Observable @MainActor` view model that orchestrates audio capture and transcription. Owns the speech service and audio manager via protocol abstractions.

- **SpeechToTextView** (`Sources/SpeechToTextView.swift`) — SwiftUI view with live transcription display and record/stop button.

**Data flow:** Microphone → AudioCaptureManager (AVAudioEngine tap) → AsyncStream<Data> → SpeechService (gRPC bidirectional stream) → AsyncStream<String> → SpeechViewModel → SwiftUI view

## Dependencies (SPM)

- **grpc-swift-nio-transport** (>= 2.0.0) — HTTP/2 transport (brings in GRPCCore transitively)
- **grpc-swift-protobuf** (>= 2.0.0) — Protobuf serialization for gRPC Swift v2

Generated protobuf files live in `Sources/Generated/`.

## Key Patterns

- Protocol-based dependency injection (`SpeechServiceProtocol`, `AudioCaptureManaging`) for testability
- Actor isolation for `SpeechService` (inherently `Sendable`)
- `@MainActor` for UI-bound types (`AudioCaptureManager`, `SpeechViewModel`)
- `AsyncStream` for both audio data flow and transcript delivery
- `precondition` enforces API key configuration at stream time (not init, to support test host)
- Swift 6 strict concurrency (`SWIFT_STRICT_CONCURRENCY = complete`)
