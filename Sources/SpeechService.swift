//
//  SpeechService.swift
//  SpeechToText-gRPC-iOS
//
//  Created by Prickett, Jacob (J.A.) on 4/13/20.
//  Copyright © 2020 Prickett, Jacob (J.A.). All rights reserved.
//

import Foundation
import GRPC
import NIOTransportServices

let API_KEY = ""

final class SpeechService {

    private var client: Google_Cloud_Speech_V1_SpeechClient!
    private var call: BidirectionalStreamingCall<Google_Cloud_Speech_V1_StreamingRecognizeRequest, Google_Cloud_Speech_V1_StreamingRecognizeResponse>!
    private var isStreaming: Bool = false

    init() {
        let group = PlatformSupport.makeEventLoopGroup(loopCount: 1)

        var callOptions = CallOptions()
        callOptions.customMetadata.add(name: "X-Goog-Api-Key", value: API_KEY)
        callOptions.customMetadata.add(name: "X-Ios-Bundle-Identifier", value: "com.ford.SpeechToText-gRPC-iOS")

        let channel = ClientConnection
            .secure(group: group)
            .connect(host: "speech.googleapis.com", port: 443)

        client = Google_Cloud_Speech_V1_SpeechClient(channel: channel, defaultCallOptions: callOptions)
    }

    func stream(_ data: Data, completion: ((Google_Cloud_Speech_V1_StreamingRecognizeResponse)->Void)? = nil) {
        if !isStreaming {
            call = client.streamingRecognize { (response) in
                completion?(response)
            }

            isStreaming = true

            call.status.whenSuccess { status in
                if status.code == .ok {
                    print("Stream Successfully Finished")
                } else {
                    print("Stream Failed: \(status)")
                }
            }

            let config = Google_Cloud_Speech_V1_RecognitionConfig.with {
                $0.encoding = .linear16
                $0.sampleRateHertz = 16000
                $0.languageCode = "en-US"
                $0.metadata = Google_Cloud_Speech_V1_RecognitionMetadata.with {
                    $0.interactionType = .dictation
                    $0.microphoneDistance = .nearfield
                    $0.recordingDeviceType = .smartphone
                }
            }

            let streamConfig = Google_Cloud_Speech_V1_StreamingRecognitionConfig.with {
                $0.config = config
            }

            let request = Google_Cloud_Speech_V1_StreamingRecognizeRequest.with {
                $0.streamingConfig = streamConfig
            }


            _ = call.sendMessage(request)
        }

        let streamAudioDataRequest = Google_Cloud_Speech_V1_StreamingRecognizeRequest.with {
            $0.audioContent = data
        }
        _ = call.sendMessage(streamAudioDataRequest)
    }

    func stopStreaming() {
        _ = call.sendEnd()
        isStreaming.toggle()
    }

}
