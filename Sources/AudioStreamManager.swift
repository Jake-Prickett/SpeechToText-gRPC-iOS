//
//  AudioStreamManager.swift
//  SpeechToText-gRPC-iOS
//
//  Created by Prickett, Jacob (J.A.) on 4/13/20.
//  Copyright © 2020 Prickett, Jacob (J.A.). All rights reserved.
//

/* NOTE: Implementation based off of Google's for Audio Streaming:

 https://github.com/GoogleCloudPlatform/ios-docs-samples/blob/master/speech/Swift/Speech-gRPC-Streaming/Speech/AudioController.swift

 */

import Foundation
import AVFoundation

protocol StreamDelegate: AnyObject {
    func processAudio(_ data: Data)
}

class AudioStreamManager {

    var remoteIOUnit: AudioComponentInstance?
    weak var delegate: StreamDelegate?

    static var shared = AudioStreamManager()

    deinit {
        if let remoteIOUnit = remoteIOUnit {
            AudioComponentInstanceDispose(remoteIOUnit)
        }
    }

    func configure(sampleRate: Double) {

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.record)
        try? session.setPreferredIOBufferDuration(10)

        // Describe the RemoteIO unit
        var audioComponentDescription = AudioComponentDescription()
        audioComponentDescription.componentType = kAudioUnitType_Output;
        audioComponentDescription.componentSubType = kAudioUnitSubType_RemoteIO;
        audioComponentDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
        audioComponentDescription.componentFlags = 0;
        audioComponentDescription.componentFlagsMask = 0;

        // Get the RemoteIO unit
        guard let remoteIOComponent = AudioComponentFindNext(nil, &audioComponentDescription) else {
            return
        }
        AudioComponentInstanceNew(remoteIOComponent, &remoteIOUnit)

        let bus1 : AudioUnitElement = 1
        var oneFlag : UInt32 = 1

        guard let remoteIOUnit = remoteIOUnit else { return }
        // Configure the RemoteIO unit for input
        AudioUnitSetProperty(remoteIOUnit,
                             kAudioOutputUnitProperty_EnableIO,
                             kAudioUnitScope_Input,
                             bus1,
                             &oneFlag,
                             UInt32(MemoryLayout<UInt32>.size));

        // Set format for mic input (bus 1) on RemoteIO's output scope
        var asbd = AudioStreamBasicDescription()
        asbd.mSampleRate = Double(sampleRate)
        asbd.mFormatID = kAudioFormatLinearPCM
        asbd.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked
        asbd.mBytesPerPacket = 2
        asbd.mFramesPerPacket = 1
        asbd.mBytesPerFrame = 2
        asbd.mChannelsPerFrame = 1
        asbd.mBitsPerChannel = 16
        AudioUnitSetProperty(remoteIOUnit,
                             kAudioUnitProperty_StreamFormat,
                             kAudioUnitScope_Output,
                             bus1,
                             &asbd,
                             UInt32(MemoryLayout<AudioStreamBasicDescription>.size))

        // Set the recording callback
        var callbackStruct = AURenderCallbackStruct()
        callbackStruct.inputProc = recordingCallback
        callbackStruct.inputProcRefCon = nil
        AudioUnitSetProperty(remoteIOUnit,
                             kAudioOutputUnitProperty_SetInputCallback,
                             kAudioUnitScope_Global,
                             bus1,
                             &callbackStruct,
                             UInt32(MemoryLayout<AURenderCallbackStruct>.size))

        // Initialize the RemoteIO unit
        AudioUnitInitialize(remoteIOUnit)
    }

    func start() {
        configure(sampleRate: Constants.kSampleRate)
        guard let remoteIOUnit = remoteIOUnit else { return }
        AudioOutputUnitStart(remoteIOUnit)
    }

    func stop() {
        guard let remoteIOUnit = remoteIOUnit else { return }
        AudioOutputUnitStop(remoteIOUnit)
    }
}

func recordingCallback(
    inRefCon:UnsafeMutableRawPointer,
    ioActionFlags:UnsafeMutablePointer<AudioUnitRenderActionFlags>,
    inTimeStamp:UnsafePointer<AudioTimeStamp>,
    inBusNumber:UInt32,
    inNumberFrames:UInt32,
    ioData:UnsafeMutablePointer<AudioBufferList>?
) -> OSStatus {

    var status = noErr

    let channelCount : UInt32 = 1

    var bufferList = AudioBufferList()
    bufferList.mNumberBuffers = channelCount
    let buffers = UnsafeMutableBufferPointer<AudioBuffer>(start: &bufferList.mBuffers,
                                                          count: Int(bufferList.mNumberBuffers))
    buffers[0].mNumberChannels = 1
    buffers[0].mDataByteSize = inNumberFrames * 2
    buffers[0].mData = nil

    // get the recorded samples
    guard let remoteIOUnit = AudioStreamManager.shared.remoteIOUnit else { fatalError() }
    status = AudioUnitRender(remoteIOUnit,
                             ioActionFlags,
                             inTimeStamp,
                             inBusNumber,
                             inNumberFrames,
                             UnsafeMutablePointer<AudioBufferList>(&bufferList))
    if (status != noErr) {
        return status;
    }

    guard let bytes = buffers[0].mData else { fatalError() }
    let data = Data(bytes:  bytes, count: Int(buffers[0].mDataByteSize))
    DispatchQueue.main.async {
        AudioStreamManager.shared.delegate?.processAudio(data)
    }

    return noErr
}
