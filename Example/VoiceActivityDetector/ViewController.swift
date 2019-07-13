//
//  ViewController.swift
//  VoiceActivityDetector
//
//  Created by reedom on 07/12/2019.
//  Copyright (c) 2019 reedom. All rights reserved.
//

import UIKit
import AVFoundation.AVFAudio
import VoiceActivityDetector

class ViewController: UIViewController {
  @IBOutlet var toggleButton: UIButton!
  @IBOutlet var stateLabel: UILabel!
  @IBOutlet var agressivenessLabel: UILabel!

  let voiceActivityDetectDuration = 30 // ms
  let voiceActivityDetector = VoiceActivityDetector(agressiveness: .quality)!
  var voiceActivity: VoiceActivityDetector.VoiceActivity? {
    didSet {
      guard oldValue != voiceActivity else { return }

      if let voiceActivity = voiceActivity {
        switch voiceActivity {
        case .activeVoice:
          stateLabel.textColor = .white
          stateLabel.backgroundColor = .red
          stateLabel.text = "Active"
        case .inActiveVoice:
          stateLabel.textColor = .black
          stateLabel.backgroundColor = .green
          stateLabel.text = "inactive"
        }
      } else {
        stateLabel.text = "---"
        stateLabel.textColor = .black
        stateLabel.backgroundColor = .white
      }
    }
  }

  var isMicrophoneActive = false
  var audioBuffers = [AudioQueueBufferRef]()
  var audioQueue: AudioQueueRef?

  var audioStreamDescription = AudioStreamBasicDescription(
    mSampleRate: 8000,
    mFormatID: kAudioFormatLinearPCM,
    mFormatFlags: kAudioFormatFlagIsSignedInteger,
    mBytesPerPacket: 2,
    mFramesPerPacket: 1,
    mBytesPerFrame: 2,
    mChannelsPerFrame: 1,
    mBitsPerChannel: 16,
    mReserved: 0)

  override func viewDidLoad() {
    super.viewDidLoad()
    agressivenessLabel.text = voiceActivityDetector.agressiveness.description
    #if targetEnvironment(simulator)
    toggleButton.isEnabled = false
    #else
    setupAudioRecording()
    #endif
  }

  @IBAction func didTapToggleSession() {
    if isMicrophoneActive {
      deactivateMicrophone()
      voiceActivity = nil
      toggleButton.setTitle("Aactivate Mic", for: .normal)
    } else {
      activateMicrophone()
      if isMicrophoneActive {
        toggleButton.setTitle("Deactivate Mic", for: .normal)
      }
    }
  }

  @IBAction func didChangeAgressivenessValue(_ sender: UISlider) {
    let i = Int32(round(sender.value))
    sender.value = Float(i)

    let agressiveness = VoiceActivityDetector.DetectionAgressiveness.init(rawValue: i)!
    voiceActivityDetector.agressiveness = agressiveness
    agressivenessLabel.text = agressiveness.description
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
}

extension ViewController {
  func setupAudioRecording() {
    let callback: AudioQueueInputCallback = { (
      inUserData: UnsafeMutableRawPointer?,
      inAQ: AudioQueueRef,
      inBuffer: AudioQueueBufferRef,
      inStartTime: UnsafePointer<AudioTimeStamp>,
      inNumberPacketDescriptions: UInt32,
      inPacketDescs: UnsafePointer<AudioStreamPacketDescription>?
      ) in
      guard let inUserData = inUserData else { return }

      let myself = Unmanaged<ViewController>.fromOpaque(inUserData).takeUnretainedValue()
      guard myself.isMicrophoneActive else { return }

      myself.didReceivceSampleBuffer(buffer: inBuffer.pointee)

      let err = AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, nil)
      if (err != noErr) {
        NSLog("AudioQueueEnqueueBuffer failed with error (\(err))");
        AudioQueueFreeBuffer(inAQ, inBuffer)
      }
    }

    let err = AudioQueueNewInput(&audioStreamDescription,
                                 callback,
                                 Unmanaged.passUnretained(self).toOpaque(),
                                 nil, nil, 0, &audioQueue)
    if err != noErr {
      fatalError("Unable to create new output audio queue (\(err))")
    }
  }

  func activateMicrophone() {
    guard let audioQueue = audioQueue else { return }

    let audioSession = AVAudioSession.sharedInstance()
    do {
      try audioSession.setCategory(AVAudioSession.Category.record)
      try audioSession.setActive(true)
      try audioSession.setPreferredSampleRate(audioStreamDescription.mSampleRate)

      enqueueBuffers()

      let err = AudioQueueStart(audioQueue, nil)
      if err == noErr {
        isMicrophoneActive = true
      } else {
        NSLog("AudioQueueStart failed with error (\(err))");
      }
    } catch {
      print(error.localizedDescription)
      dequeueBuffers()
    }
  }

  func deactivateMicrophone() {
    isMicrophoneActive = false
    guard let audioQueue = audioQueue else { return }

    let err = AudioQueueStop(audioQueue, true)
    if err != noErr {
      NSLog("AudioQueueStop failed with error (\(err))");
    }

    dequeueBuffers()
  }

  func enqueueBuffers() {
    guard let audioQueue = audioQueue else { return }

    let format = audioStreamDescription
    let bufferSize = UInt32(format.mSampleRate) * UInt32(format.mBytesPerFrame) / 1000 * UInt32(VoiceActivityDetector.Duration.msec30.rawValue)
    for _ in 0 ..< 3 {
      var buffer: AudioQueueBufferRef?
      var err = AudioQueueAllocateBuffer(audioQueue, bufferSize, &buffer)
      if (err != noErr) {
        NSLog("Failed to allocate buffer for audio recording (\(err))")
        continue
      }

      err = AudioQueueEnqueueBuffer(audioQueue, buffer!, 0, nil)
      if (err != noErr) {
        NSLog("Failed to enqueue buffer for audio recording (\(err))")
      }

      audioBuffers.append(buffer!)
    }
  }

  func dequeueBuffers() {
    guard let audioQueue = audioQueue else { return }
    while let buffer = audioBuffers.popLast() {
      AudioQueueFreeBuffer(audioQueue, buffer)
    }
  }
}

extension ViewController {

  func didReceivceSampleBuffer(buffer: AudioQueueBuffer) {
    let frames = buffer.mAudioData.assumingMemoryBound(to: Int16.self)
    var count = Int(buffer.mAudioDataByteSize) / MemoryLayout<Int16>.size
    let detectorFrameUnit = Int(audioStreamDescription.mSampleRate) * VoiceActivityDetector.Duration.msec10.rawValue / 1000
    count = count - (count % detectorFrameUnit)
    guard 0 < count else { return }

    let voiceActivity = voiceActivityDetector.detect(frames: frames, count: count)
    DispatchQueue.main.async {
      self.voiceActivity = voiceActivity
    }
  }
}

extension VoiceActivityDetector.DetectionAgressiveness {
  var description: String {
    switch self {
    case .quality:
      return "quality"
    case .lowBitRate:
      return "lowBitRate"
    case .aggressive:
      return "aggressive"
    case .veryAggressive:
      return "veryAggressive"
    }
  }
}
