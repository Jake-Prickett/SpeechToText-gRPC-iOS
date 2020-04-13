//
//  ViewController.swift
//  SpeechToText-gRPC-iOS
//
//  Created by Prickett, Jacob (J.A.) on 4/12/20.
//  Copyright © 2020 Prickett, Jacob (J.A.). All rights reserved.
//

import UIKit
import SnapKit
import GRPC
import AVFoundation

let SAMPLE_RATE: Double = 16000

protocol AudioControllerDelegate {
  func processSampleData(_ data:Data) -> Void
}

class AudioController {
  var remoteIOUnit: AudioComponentInstance? // optional to allow it to be an inout argument
  var delegate : AudioControllerDelegate!

  static var sharedInstance = AudioController()

  deinit {
    AudioComponentInstanceDispose(remoteIOUnit!);
  }

  func prepare(specifiedSampleRate: Int) -> OSStatus {

    var status = noErr

    let session = AVAudioSession.sharedInstance()
    do {
        try session.setCategory(.record)
      try session.setPreferredIOBufferDuration(10)
    } catch {
      return -1
    }

    var sampleRate = session.sampleRate
    print("hardware sample rate = \(sampleRate), using specified rate = \(specifiedSampleRate)")
    sampleRate = Double(specifiedSampleRate)

    // Describe the RemoteIO unit
    var audioComponentDescription = AudioComponentDescription()
    audioComponentDescription.componentType = kAudioUnitType_Output;
    audioComponentDescription.componentSubType = kAudioUnitSubType_RemoteIO;
    audioComponentDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    audioComponentDescription.componentFlags = 0;
    audioComponentDescription.componentFlagsMask = 0;

    // Get the RemoteIO unit
    let remoteIOComponent = AudioComponentFindNext(nil, &audioComponentDescription)
    status = AudioComponentInstanceNew(remoteIOComponent!, &remoteIOUnit)
    if (status != noErr) {
      return status
    }

    let bus1 : AudioUnitElement = 1
    var oneFlag : UInt32 = 1

    // Configure the RemoteIO unit for input
    status = AudioUnitSetProperty(remoteIOUnit!,
                                  kAudioOutputUnitProperty_EnableIO,
                                  kAudioUnitScope_Input,
                                  bus1,
                                  &oneFlag,
                                  UInt32(MemoryLayout<UInt32>.size));
    if (status != noErr) {
      return status
    }

    // Set format for mic input (bus 1) on RemoteIO's output scope
    var asbd = AudioStreamBasicDescription()
    asbd.mSampleRate = sampleRate
    asbd.mFormatID = kAudioFormatLinearPCM
    asbd.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked
    asbd.mBytesPerPacket = 2
    asbd.mFramesPerPacket = 1
    asbd.mBytesPerFrame = 2
    asbd.mChannelsPerFrame = 1
    asbd.mBitsPerChannel = 16
    status = AudioUnitSetProperty(remoteIOUnit!,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Output,
                                  bus1,
                                  &asbd,
                                  UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
    if (status != noErr) {
      return status
    }

    // Set the recording callback
    var callbackStruct = AURenderCallbackStruct()
    callbackStruct.inputProc = recordingCallback
    callbackStruct.inputProcRefCon = nil
    status = AudioUnitSetProperty(remoteIOUnit!,
                                  kAudioOutputUnitProperty_SetInputCallback,
                                  kAudioUnitScope_Global,
                                  bus1,
                                  &callbackStruct,
                                  UInt32(MemoryLayout<AURenderCallbackStruct>.size));
    if (status != noErr) {
      return status
    }

    // Initialize the RemoteIO unit
    return AudioUnitInitialize(remoteIOUnit!)
  }

  func start() -> OSStatus {
    return AudioOutputUnitStart(remoteIOUnit!)
  }

  func stop() -> OSStatus {
    return AudioOutputUnitStop(remoteIOUnit!)
  }
}

func recordingCallback(
  inRefCon:UnsafeMutableRawPointer,
  ioActionFlags:UnsafeMutablePointer<AudioUnitRenderActionFlags>,
  inTimeStamp:UnsafePointer<AudioTimeStamp>,
  inBusNumber:UInt32,
  inNumberFrames:UInt32,
  ioData:UnsafeMutablePointer<AudioBufferList>?) -> OSStatus {

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
  status = AudioUnitRender(AudioController.sharedInstance.remoteIOUnit!,
                           ioActionFlags,
                           inTimeStamp,
                           inBusNumber,
                           inNumberFrames,
                           UnsafeMutablePointer<AudioBufferList>(&bufferList))
  if (status != noErr) {
    return status;
  }

  let data = Data(bytes:  buffers[0].mData!, count: Int(buffers[0].mDataByteSize))
  DispatchQueue.main.async {
    AudioController.sharedInstance.delegate.processSampleData(data)
  }

  return noErr
}

class ViewController: UIViewController, AudioControllerDelegate {

    lazy var recordButton: UIButton = {
        var button = UIButton()
        button.setTitle("Record", for: .normal)
        button.setImage(UIImage(systemName: "mic"), for: .normal)
        button.backgroundColor = .darkGray
        button.layer.cornerRadius = 10
        button.clipsToBounds = true
        button.addTarget(self, action: #selector(recordTapped), for: .touchUpInside)
        return button
    }()

    lazy var textView: UITextView = {
        var textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = false
        textView.textColor = .white
        textView.textAlignment = .left
        textView.font = UIFont.systemFont(ofSize: 30)
        return textView
    }()

    private let speechService: SpeechService
    var isRecording: Bool = false
    var audioData = Data()

    init(speechService: SpeechService) {
        self.speechService = speechService
        
        super.init(nibName: nil, bundle: nil)
    }

    convenience init() {
        self.init(speechService: SpeechService())
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        title = "gRPC Speech To Text"

        AudioController.sharedInstance.delegate = self

        let recordingSession = AVAudioSession.sharedInstance()
        try? recordingSession.setCategory(.record)
        try? recordingSession.setPreferredIOBufferDuration(10)

        recordingSession.requestRecordPermission { [weak self] (allowed) in
            DispatchQueue.main.async {
                if allowed {
                    self?.setupRecordingLayout()
                } else {
                    self?.setupErrorLayout()
                }
            }
        }
    }

    func setupRecordingLayout() {
        view.addSubview(recordButton)
        recordButton.snp.makeConstraints { make in
            make.height.equalTo(50)
            make.left.equalTo(40)
            make.right.equalTo(-40)
            make.bottom.equalToSuperview().inset(100)
            make.centerX.equalToSuperview()
        }

        view.addSubview(textView)
        textView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.topMargin)
            make.left.right.equalToSuperview()
            make.bottom.equalTo(recordButton.snp.top)
        }
    }

    func setupErrorLayout() {

    }

    @objc
    func recordTapped() {
        toggle()
    }

    func startRecording() {
        audioData = Data()
        _ = AudioController.sharedInstance.prepare(specifiedSampleRate: Int(SAMPLE_RATE))
        _ = AudioController.sharedInstance.start()

        UIView.animate(withDuration: 0.02) { [weak self] in
            self?.recordButton.backgroundColor = .red
        }
    }

    func stopRecording() {
        _ = AudioController.sharedInstance.stop()
        speechService.stopStreaming()

        UIView.animate(withDuration: 0.02) { [weak self] in
            self?.recordButton.backgroundColor = .darkGray
        }
    }

    func toggle() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
        isRecording.toggle()
    }

    func processSampleData(_ data: Data) -> Void {
        audioData.append(data)

        // We recommend sending samples in 100ms chunks
        let chunkSize : Int /* bytes/chunk */ = Int(0.1 /* seconds/chunk */
            * Double(SAMPLE_RATE) /* samples/second */
            * 2 /* bytes/sample */);

        if (audioData.count > chunkSize) {
            speechService.stream(audioData) { [weak self] response in
                guard let self = self else { return }
                let finished = response.speechEventType == .endOfSingleUtterance
                print(response)

                DispatchQueue.main.async {
                    UIView.transition(with: self.textView, duration: 0.25, options: .transitionCrossDissolve, animations: {
                        guard let text = response.results.first?.alternatives.first?.transcript else { return }
                        if self.textView.text != text {
                            self.textView.text = text
                        }
                    }, completion: { (_) in
                         if finished { self.stopRecording(); self.isRecording.toggle() }
                    })


                }
            }
        }
    }

}
