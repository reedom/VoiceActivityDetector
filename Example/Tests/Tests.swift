// https://github.com/Quick/Quick

import Quick
import Nimble
import AVFoundation
import VoiceActivityDetector

class VoiceActivityDetectorSpec: QuickSpec {
  lazy var zeroData = Data(count: 2880)
  lazy var zero = zeroData.withUnsafeBytes { $0.baseAddress!.assumingMemoryBound(to: Int16.self) }

  override func spec() {
    describe("agressiveness") {
      it("should accept any of predefined value") {
        let detector = VoiceActivityDetector()!
        detector.agressiveness = .veryAggressive
        expect(detector.agressiveness) == .veryAggressive
        detector.agressiveness = .aggressive
        expect(detector.agressiveness) == .aggressive
        detector.agressiveness = .lowBitRate
        expect(detector.agressiveness) == .lowBitRate
        detector.agressiveness = .quality
        expect(detector.agressiveness) == .quality
      }
    }

    describe("sampleRate") {
      it("should accept known sample rates") {
        let detector = VoiceActivityDetector()!
        detector.sampleRate = 48000
        expect(detector.sampleRate) == 48000
        detector.sampleRate = 32000
        expect(detector.sampleRate) == 32000
        detector.sampleRate = 16000
        expect(detector.sampleRate) == 16000
        detector.sampleRate = 8000
        expect(detector.sampleRate) == 8000
      }

      #if targetEnvironment(simulator)
      it("should signal assert with unknown sample rates") {
        let detector = VoiceActivityDetector()!
        expect { detector.sampleRate = 8001 }.to(throwAssertion())
      }
      #endif
    }

    describe("detect") {
      it("detects") {
        let detector = VoiceActivityDetector()!
        detector.sampleRate = 8000
        expect(detector.detect(frames: self.zero, count: 80)) == .inActiveVoice
        expect(detector.detect(frames: self.zero, lengthInMilliSec: 10)) == .inActiveVoice
      }

      #if targetEnvironment(simulator)
      it("should fail with inacceptable frame count") {
        let detector = VoiceActivityDetector()!
        expect { _ = detector.detect(frames: self.zero, count: 81) }.to(throwAssertion())
      }
      #endif
    }

    describe("detect(sampleBuffer, ...)") {
      it("does") {
        let settings: [String : Any] = [
          AVFormatIDKey: Int(kAudioFormatLinearPCM),
          AVLinearPCMBitDepthKey: 16,
          AVLinearPCMIsBigEndianKey: false,
          AVLinearPCMIsFloatKey: false,
          AVLinearPCMIsNonInterleaved: false,
          AVNumberOfChannelsKey: 1,
          AVSampleRateKey: 8000,
        ]
        let path = Bundle.main.path(forResource: "3722", ofType: "mp3")!
        let reader = try! AudioTrackReader(audioPath: path, timeRange: nil, settings: settings)

        CMSampleBufferInvalidate(reader.next()!) // skip the first iteration
        let sampleBuffer = reader.next()!

        expect(sampleBuffer).notTo(beNil())

        let detector = VoiceActivityDetector()!
        guard let activities = detector.detect(sampleBuffer: sampleBuffer, byEachMilliSec: 10, duration: 30) else {
          fail()
          return
        }

        let presentationTimeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        expect(presentationTimeStamp.seconds) > 0

        expect(activities.count) == 3
        expect(activities[2].timestamp) == 20
        expect(activities[2].presentationTimestamp.seconds) == presentationTimeStamp.seconds + 0.020
        CMSampleBufferInvalidate(sampleBuffer)
      }
    }
  }
}

