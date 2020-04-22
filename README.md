# Speech-To-Text gRPC iOS Example

## Description

This application demonstrates Bidirectional Streaming to convert streamed audio data into text and display the Server processing live using gRPC Swift, built on top of SwiftNIO.

Check out the [Medium Article](https://medium.com/macoclock/bidirectional-streaming-with-grpc-swift-d11496ea0b3)!

## Technologies

* [gRPC Swift](https://github.com/grpc/grpc-swift)
* [Google Speech-To-Text API](https://cloud.google.com/speech-to-text)
* [SnapKit](https://github.com/SnapKit/SnapKit)

## Acquiring an API Key
This project requires a Google Cloud API Key. Please [register](https://cloud.google.com/apis/docs/getting-started) and [create an API key](https://cloud.google.com/docs/authentication/api-keys) in order to consume the API.

## Project Setup
1. Clone the repository
2. Navigate to the root directory and run `pod install`
3. Open the `.xworkspace`
4. Open the `Constants.swift` file and assign your generated Google Cloud API Key to the `kAPIKey` variable.
