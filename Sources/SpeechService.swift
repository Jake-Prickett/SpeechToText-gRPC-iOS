//
//  SpeechService.swift
//  SpeechToText-gRPC-iOS
//
//  Created by Prickett, Jacob (J.A.) on 4/13/20.
//  Copyright © 2020 Prickett, Jacob (J.A.). All rights reserved.
//

import GRPC
import Foundation
import Logging

typealias Request = Google_Cloud_Speech_V1_StreamingRecognizeRequest
typealias Response = Google_Cloud_Speech_V1_StreamingRecognizeResponse
typealias StreamingRecognizeCall = BidirectionalStreamingCall
typealias RecognitionConfig = Google_Cloud_Speech_V1_RecognitionConfig
typealias SpeechClient = Google_Cloud_Speech_V1_SpeechClient

final class SpeechService {
  // Track whether we are currently streaming or not
  enum State {
    case idle
    case streaming(StreamingRecognizeCall<Request, Response>)
  }
  
  // Generated SpeechClient for making calls
  private var client: SpeechClient
  
  // Track if we are streaming or not
  private var state: State = .idle
  
  // Attach logger for debug output
  private let logger: Logger = Logger(label: "com.demo.speech-grpc")
  
  init() {
    precondition(
      !Constants.apiKey.isEmpty,
      "Please refer to the README on how to configure your API Key properly."
    )
    
    // Make EventLoopGroup for the specific platform (NIOTSEventLoopGroup for iOS)
    // see https://github.com/grpc/grpc-swift/blob/master/docs/apple-platforms.md for more details
    let group = PlatformSupport.makeEventLoopGroup(loopCount: 1)
    
    // Create a connection secured with TLS to Google's speech service running on our `EventLoopGroup`
    let channel = ClientConnection
      .usingPlatformAppropriateTLS(for: group)
      .withBackgroundActivityLogger(logger)
      .connect(host: "speech.googleapis.com", port: 443)
    
    // Specify call options to be used for gRPC calls
    let callOptions = CallOptions(
      customMetadata: ["x-goog-api-key": Constants.apiKey]
    )
    
    // Now we have a client!
    self.client = SpeechClient(
      channel: channel,
      defaultCallOptions: callOptions
    )
  }
  
  func stream(
    _ data: Data,
    completion: ((Response) -> Void)? = nil
  ) {
    switch self.state {
    case .idle:
      // Initialize the bidirectional stream
      let call = self.client.streamingRecognize { response in
        // Message received from Server, execute provided closure from caller
        completion?(response)
      }
      
      self.state = .streaming(call)
      
      // Specify audio details
      let config: RecognitionConfig = .with {
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
      
      // Create streaming request
      let request: Request = .with {
        $0.streamingConfig = .with {
          $0.config = config
        }
      }
      
      // Send first message consisting of the streaming request details
      call.sendMessage(request, promise: nil)
      
      // Stream request to send that contains the audio details
      let streamAudioDataRequest: Request = .with {
        $0.audioContent = data
      }
      
      // Send audio data
      call.sendMessage(streamAudioDataRequest, promise: nil)
      
    case .streaming(let call):
      // Stream request to send that contains the audio details
      let streamAudioDataRequest: Request = .with {
        $0.audioContent = data
      }
      
      // Send audio data
      call.sendMessage(streamAudioDataRequest, promise: nil)
    }
  }
  
  func stopStreaming() {
    // Send end message to the stream
    switch self.state {
    case .idle:
      return
    case .streaming(let stream):
      stream.sendEnd(promise: nil)
      self.state = .idle
    }
  }
}
