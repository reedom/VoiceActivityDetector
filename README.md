# WebRTC based voice activity detection

[![CI Status](https://img.shields.io/travis/reedom/VoiceActivityDetector.svg?style=flat)](https://travis-ci.org/reedom/VoiceActivityDetector)
[![Version](https://img.shields.io/cocoapods/v/VoiceActivityDetector.svg?style=flat)](https://cocoapods.org/pods/VoiceActivityDetector)
[![License](https://img.shields.io/cocoapods/l/VoiceActivityDetector.svg?style=flat)](https://cocoapods.org/pods/VoiceActivityDetector)
[![Platform](https://img.shields.io/cocoapods/p/VoiceActivityDetector.svg?style=flat)](https://cocoapods.org/pods/VoiceActivityDetector)

This is a Swift/Objective-C interface to the WebRTC Voice Activity Detector (VAD).

A VAD classifies a piece of audio data as being voiced or unvoiced. It can be useful for telephony and speech recognition.

The VAD that Google developed for the WebRTC project is reportedly one of the best available, being fast, modern and free.

## Sample data format

The VAD engine simply work only with singed 16 bit, single channel PCM.

Supported bitrates are:
- 8000Hz
- 16000Hz
- 32000Hz
- 48000Hz

Note that internally all processing will be done 8000Hz.
input data in higher sample rates will just be downsampled first.

## Usage

```swift
import VoiceActivityDetector

let voiceActivityDetector = VoiceActivityDetector(sampleRate: 8000,
                                                  agressiveness: .veryAggressive)

func didReceiveSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
  // activities: [VoiceActivityDetector.VoiceActivityInfo]?
  let activities = voiceActivityDetector(sampleBuffer: sampleBuffer, byEachMilliSec: 10)!

  // ...
}
```

For usage with a microphone, see [Example](Example/VoiceActivityDetector/ViewController.swift).
And against an audio file, see [Test code](Example/Tests/Tests.swift).

## API

### Constructors

```swift
init?()
convenience init?(sampleRate: Int = 8000, agressiveness: DetectionAgressiveness = .quality)
convenience init?(agressiveness: DetectionAgressiveness = .quality) {
```

Instanciate VoiceActivityDetector.

### Properties

```swift
var agressiveness: DetectionAgressiveness
```

VAD operating "aggressiveness" mode.

- `.quality`
  The default value; normal voice detection mode. Suitable for high bitrate, low-noise data.
  May classify noise as voice, too.
- `.lowBitRate`
  Detection mode optimised for low-bitrate audio.
- `.aggressive`
  Detection mode best suited for somewhat noisy, lower quality audio.
- `.veryAggressive`
  Detection mode with lowest miss-rate. Works well for most inputs.

```swift
var sampleRate: Int
```

Sample rate in Hz for VAD operations.  
Valid values are 8000, 16000, 32000 and 48000. The default is 8000.

Note that internally all processing will be done 8000Hz.
input data in higher sample rates will just be downsampled first.

### Functions

```swift
func reset()
```

Reinitializes a VAD instance, clearing all state and resetting mode and
sample rate to defaults.

```swift
func detect(frames: UnsafePointer<Int16>, count: Int) -> VoiceActivity
```

Calculates a VAD decision for an audio duration.

`frames` is an array of signed 16-bit samples.  
`count` specifies count of frames.
Since internal processor supports only counts of 10, 20 or 30 ms,
so for example at 8 kHz, `count` must be either 80, 160 or 240.

Returns a VAD decision.

```swift
func detect(frames: UnsafePointer<Int16>, lengthInMilliSec ms: Int) -> VoiceActivity
```

`ms` specifies processing duration in milliseconds.  
The should be either 10, 20 or 30 (ms).

```swift
  public func detect(sampleBuffer: CMSampleBuffer,
                     byEachMilliSec ms: Int,
                     offset: Int = 0,
                     duration: Int? = nil) -> [VoiceActivityInfo]? {
```
Calculates VAD decisions among a sample buffer.

`sampleBuffer` is an audio buffer to be inspected.  
`ms` specifies processing duration in milliseconds.  
`offset` controlls offset time in milliseconds from where to start VAD.  
`duration` controlls total VAD duration in milliseconds.  

Returns an array of VAD decision information.

- `timestamp: Int`
  Elapse time from the beginning of the sample buffer, in milliseconds.
- `presentationTimestamp: CMTime`
  This is `CMSampleBuffer.presentationTime` + `timestamp`, which may represent
  a timestamp in entire of a recording session.
- `voiceActivity: VoiceActivity`
  a VAD decision.



## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Installation

VoiceActivityDetector is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'VoiceActivityDetector'
```

## Author

reedom, tohru@reedom.com

## License

VoiceActivityDetector is available under the MIT license. See the LICENSE file for more info.
