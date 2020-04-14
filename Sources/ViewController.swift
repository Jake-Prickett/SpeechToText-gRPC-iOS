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

class ViewController: UIViewController, StreamDelegate {

    private lazy var recordButton: UIButton = {
        var button = UIButton()
        button.setTitle("Record", for: .normal)
        button.setImage(UIImage(systemName: "mic"), for: .normal)
        button.backgroundColor = .darkGray
        button.layer.cornerRadius = 10
        button.clipsToBounds = true
        button.addTarget(self, action: #selector(recordTapped), for: .touchUpInside)
        return button
    }()

    private lazy var textView: UITextView = {
        var textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = false
        textView.textColor = .white
        textView.textAlignment = .left
        textView.font = UIFont.systemFont(ofSize: 30)
        return textView
    }()

    private var isRecording: Bool = false
    private var audioData = Data()

    private let speechService: SpeechService
    private let audioStreamManager: AudioStreamManager

    init(speechService: SpeechService,
         audioStreamManager: AudioStreamManager) {
        self.speechService = speechService
        self.audioStreamManager = audioStreamManager
        
        super.init(nibName: nil, bundle: nil)
    }

    convenience init() {
        self.init(speechService: SpeechService(),
                  audioStreamManager: AudioStreamManager.shared)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black
        title = "gRPC Speech To Text"

        audioStreamManager.delegate = self

        let recordingSession = AVAudioSession.sharedInstance()

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
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
        isRecording.toggle()
    }

    func startRecording() {
        audioData = Data()
        audioStreamManager.start()

        UIView.animate(withDuration: 0.02) { [weak self] in
            self?.recordButton.backgroundColor = .red
        }
    }

    func stopRecording() {
        audioStreamManager.stop()
        speechService.stopStreaming()

        UIView.animate(withDuration: 0.02) { [weak self] in
            self?.recordButton.backgroundColor = .darkGray
        }
    }

    func process(_ data: Data) {

        audioData.append(data)

        let chunkSize : Int = Int(0.1 * Double(SAMPLE_RATE) * 2 )

        if audioData.count > chunkSize {
            speechService.stream(audioData) { [weak self] response in
                guard let self = self else { return }

                DispatchQueue.main.async {
                    UIView.transition(
                        with: self.textView,
                        duration: 0.25,
                        options: .transitionCrossDissolve,
                        animations: {
                            guard let text = response.results.first?.alternatives.first?.transcript else { return }
                            if self.textView.text != text {
                                self.textView.text = text
                            }
                        },
                        completion: nil
                    )
                }
            }
        }
    }

}
