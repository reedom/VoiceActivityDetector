//
//  VoiceActivityDetector.swift
//  VoiceActivityDetector
//
//  Created by HANAI tohru on 07/12/2019.
//  Copyright (c) 2019 HANAI tohru. All rights reserved.
//

import AVFoundation
import libfvad

/// VoiceActivityDetector(VAD).
///
/// `VoiceActivityDetector` uses the VAD engine of Google's WebRTC internally.
public class VoiceActivityDetector {
  /// VAD operating "aggressiveness" mode.
  ///
  /// A more aggressive (higher mode) VAD is more restrictive in reporting speech.
  /// Put in other words the probability of being speech when the VAD returns
  /// `VoiceActivity.activeVoice` is increased with increasing mode.
  /// As a consequence also the missed detection rate goes up.
  public enum DetectionAggressiveness: Int32 {
    case quality = 0
    case lowBitRate = 1
    case aggressive = 2
    case veryAggressive = 3
  }

  /// VOD decision result.
  public enum VoiceActivity: Int32 {
    case inActiveVoice = 0
    case activeVoice = 1
  }

  /// Acceptable durations.
  public enum Duration: Int {
    case msec10 = 10
    case msec20 = 20
    case msec30 = 30
  }

  let inst: OpaquePointer
  var _detectionAggressiveness = DetectionAggressiveness.quality
  var _sampleRate: Int = 8000

  /// Creates and initializes a VAD instance.
  ///
  /// - Returns: `nil` in case of a memory allocation error.
  public init?() {
    guard let inst = fvad_new() else { return nil }
    self.inst = inst
  }

  /// Creates and initializes a VAD instance.
  ///
  /// - Parameter sampleRate: Sample rate in Hz for VAD operations. Supports only 8000|16000|32000|48000.
  /// - Parameter agressiveness: VAD operating "aggressiveness" mode.
  /// - Returns: `nil` in case of a memory allocation error.
  public convenience init?(sampleRate: Int = 8000, agressiveness: DetectionAggressiveness = .quality) {
    self.init()
    self.sampleRate = sampleRate
    self.agressiveness = agressiveness
  }

  /// Creates and initializes a VAD instance.
  ///
  /// - Parameter agressiveness: VAD operating "aggressiveness" mode.
  /// - Returns: `nil` in case of a memory allocation error.
  public convenience init?(agressiveness: DetectionAggressiveness = .quality) {
    self.init()
    self.agressiveness = agressiveness
  }

  deinit {
    // Frees the dynamic memory of a specified VAD instance.
    fvad_free(inst)
  }

  /// Reinitializes a VAD instance, clearing all state and resetting mode and
  /// sample rate to defaults.
  public func reset() {
    fvad_reset(inst)
  }

  /// VAD operating "aggressiveness" mode.
  public var agressiveness: DetectionAggressiveness {
    get { return _detectionAggressiveness }
    set {
      guard fvad_set_mode(inst, newValue.rawValue) == 0 else {
        fatalError("Invalid value: \(newValue.rawValue)")
      }
      _detectionAggressiveness = newValue
    }
  }

  ///  Sample rate in Hz for VAD operations.
  ///
  ///  Valid values are 8000, 16000, 32000 and 48000. The default is 8000.
  ///  Note that internally all processing will be done 8000 Hz; input data in higher
  ///  sample rates will just be downsampled first.
  public var sampleRate: Int {
    get { return _sampleRate }
    set {
      guard fvad_set_sample_rate(inst, Int32(newValue)) == 0 else {
        assertionFailure("Invalid value: \(newValue), should be 8000|16000|32000|48000")
        return
      }
      _sampleRate = newValue
    }
  }

  ///  Calculates a VAD decision for an audio duration.
  ///
  /// - Parameter frames:  Array of signed 16-bit samples.
  /// - Parameter count:  Specify count of frames.
  ///                  Since internal processor supports only counts of 10, 20 or 30 ms,
  ///                  so for example at 8 kHz, `count` must be either 80, 160 or 240.
  /// - Returns:  VAD decision.
  public func detect(frames: UnsafePointer<Int16>, count: Int) -> VoiceActivity {
    switch fvad_process(inst, frames, count) {
    case 0:
      return .inActiveVoice
    case 1:
      return .activeVoice
    default:
      let validValues = [10, 20, 30]
        .map({ $0 * _sampleRate / 1000 })
        .map({ String(describing: $0) })
        .joined(separator: "|")
      assertionFailure("Invalid value \(count): should be \(validValues)")
      return .inActiveVoice
    }
  }

  ///  Calculates a VAD decision for an audio duration.
  ///
  /// - Parameter frames:  Array of signed 16-bit samples.
  /// - Parameter ms:  Specify processing duration in milliseconds.
  ///                  The internal processor supports only 10, 20 or 30 ms.
  /// - Returns:  VAD decision.
  public func detect(frames: UnsafePointer<Int16>, lengthInMilliSec ms: Int) -> VoiceActivity {
    let count = ms * _sampleRate / 1000
    switch fvad_process(inst, frames, count) {
    case 0:
      return .inActiveVoice
    case 1:
      return .activeVoice
    default:
      assertionFailure("Invalid value \(ms): should be 10|20|30")
      return .inActiveVoice
    }
  }
}

extension VoiceActivityDetector {
  public struct VoiceActivityInfo {
    public let timestamp: Int
    public let presentationTimestamp: CMTime
    public let voiceActivity: VoiceActivity
  }

  ///  Calculates VAD decisions among a sample buffer.
  ///
  /// - Parameter sampleBuffer:  An audio buffer to be inspected.
  ///                            The data format should be signed 16-bit PCM
  ///                            and its sample rate should equals to `sampleRate`.
  /// - Parameter ms:  Specify processing duration in milliseconds each.
  ///                  The internal processor supports only 10, 20 or 30 ms.
  /// - Parameter offset:  Offset time in milliseconds from where to start VAD.
  /// - Parameter duration:  Total VAD duration in milliseconds.
  /// - Returns:  VAD decision information.
  public func detect(sampleBuffer: CMSampleBuffer,
                     byEachMilliSec ms: Int,
                     offset: Int = 0,
                     duration: Int? = nil) -> [VoiceActivityInfo]? {
    guard let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
      return nil
    }

    let sampleBytes = CMSampleBufferGetSampleSize(sampleBuffer, at: 0)
    assert(sampleBytes == 2, "Invalid sample format")

    let offsetBytes = (offset == 0) ? 0 : (offset * _sampleRate * sampleBytes / 1000)
    var bufferBytes = 0
    var bufferPointer: UnsafeMutablePointer<Int8>?
    let ret = CMBlockBufferGetDataPointer(dataBuffer,
                                          atOffset: offsetBytes,
                                          lengthAtOffsetOut: &bufferBytes,
                                          totalLengthOut: nil,
                                          dataPointerOut: &bufferPointer)
    guard ret == kCMBlockBufferNoErr, bufferPointer != nil else {
      // FIXME how to pass the faileure information to the caller, an exception or Result<>?
      return nil
    }

    let sampleCount = bufferBytes / 2
    return bufferPointer!.withMemoryRebound(to: Int16.self, capacity: sampleCount) { (buffer) in
      let availableDuration = (sampleCount * 1000) / _sampleRate

      let times: Int
      if let duration = duration {
        times = min(duration, availableDuration) / ms
      } else {
        times = availableDuration / ms
      }

      let sampleCountPerUnit = ms * _sampleRate / 1000
      let timeDelta = CMTimeMake(value: Int64(ms), timescale: 1000)

      var timestamp = offset
      var presentationTimestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
      return (0 ..< times).map { i in
        let voiceActivity = detect(frames: buffer + i * sampleCountPerUnit, count: sampleCountPerUnit)
        let info = VoiceActivityInfo(timestamp: timestamp,
                                     presentationTimestamp: presentationTimestamp,
                                     voiceActivity: voiceActivity)
        timestamp += ms
        presentationTimestamp = CMTimeAdd(presentationTimestamp, timeDelta)
        return info
      }
    }
  }
}
