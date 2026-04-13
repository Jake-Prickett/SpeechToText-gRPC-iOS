# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

iOS app demonstrating bidirectional gRPC streaming for real-time speech-to-text using Google's Cloud Speech API. Built with gRPC Swift on SwiftNIO, it captures microphone audio and streams 100ms chunks to Google's API, displaying transcription results live.

## Build & Run

This is an Xcode project using Swift Package Manager for dependencies. No CocoaPods or Carthage.

```bash
# Generate protobuf Swift files (required before first build)
make protos      # Downloads googleapis .proto files
make generate    # Runs protoc to generate Swift bindings

# Clean generated files
make clean
```

Build and run via Xcode (Cmd+R). Requires:
- Xcode 11.3+, Swift 5.0, iOS 15.0+
- A Google Cloud API key set in `Sources/Constants.swift` (`Constants.apiKey`)
- Microphone permission (configured in Info.plist)

There are no test targets in this project.

## Architecture

Three main components with clear separation of concerns:

- **SpeechService** (`Sources/SpeechService.swift`) — gRPC client that manages a bidirectional stream to `speech.googleapis.com:443`. Handles TLS channel setup, streaming state (idle/active), and first-message config (LINEAR16, 16kHz, en-US). Uses typealiases over generated protobuf types.

- **AudioStreamManager** (`Sources/AudioStreamManager.swift`) — Singleton that captures microphone audio via RemoteIO Audio Unit. Configures audio session for recording (16-bit linear PCM, 16kHz, mono). Uses a C-style callback that dispatches to main thread via `StreamDelegate` protocol.

- **ViewController** (`Sources/ViewController.swift`) — Programmatic UI (no storyboards) using SnapKit for layout. Accepts SpeechService and AudioStreamManager via dependency injection. Implements StreamDelegate to receive audio chunks and forward them to SpeechService.

**Data flow:** Microphone → AudioStreamManager (callback) → ViewController (delegate) → SpeechService (gRPC stream) → Google API → completion closure → UI update

## Dependencies (SPM)

- **grpc-swift** (>= 1.0.0) — gRPC framework with SwiftNIO transport
- **SnapKit** (>= 5.0.0) — Auto-layout DSL

Generated protobuf files live in `Sources/` (e.g., `cloud_speech.grpc.swift`, `cloud_speech.pb.swift`).

## Key Patterns

- Dependency injection in ViewController constructor (with convenience default init)
- Delegation pattern for audio data flow (StreamDelegate)
- State enum in SpeechService tracks idle vs active streaming
- All UI updates dispatched to main thread
- `preconditionFailure` enforces API key configuration at init time
