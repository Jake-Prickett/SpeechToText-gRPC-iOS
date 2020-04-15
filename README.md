# Speech-To-Text gRPC iOS Example

## Description

This application is intended to demonstrate how to leverage gRPC to perform Bidirectional Streaming by converting streamed audio into text. 

## Technologies

* [gRPC Swift](https://github.com/grpc/grpc-swift)
* [SnapKit](https://github.com/SnapKit/SnapKit)
* [Google Speech-To-Text API](https://cloud.google.com/speech-to-text)

## Acquiring an API Key
This project requires a Google Cloud API Key. Please [register](https://cloud.google.com/apis/docs/getting-started) and [create an API key](https://cloud.google.com/docs/authentication/api-keys) in order to consume the API.

## Project Setup
1. Clone the repository
2. Navigate to the root directory and run `pod install`
3. Open the `.xworkspace`
4. Open the `Constants.swift` file and assign your generated Google Cloud API Key to the `kAPIKey` variable.
