//
//  AudioTrackReader.swift
//  VoiceActivityDetector
//
//  Created by HANAI Tohru on 2019/07/12.
//  Copyright © 2019 CocoaPods. All rights reserved.
//

import AVFoundation

public protocol AudioDataReader: class {
  var isActive: Bool { get }
  func next() -> CMSampleBuffer?
}

public class AudioTrackReader: AudioDataReader {
  private let reader: AVAssetReader
  private let readerOutput: AVAssetReaderTrackOutput
  public private(set) var isActive: Bool

  public convenience init(audioPath: String, timeRange: CMTimeRange?, settings: [String : Any]) throws {
    let url = URL(fileURLWithPath: audioPath)
    try self.init(audioURL: url, timeRange: timeRange, settings: settings)
  }

  public convenience init(audioURL: URL, timeRange: CMTimeRange?, settings: [String : Any]) throws {
    let asset = AVAsset(url: audioURL)
    guard let track = asset.tracks.first else {
      fatalError()
    }
    try self.init(track: track, timeRange: timeRange, settings: settings)
  }

  public init(track: AVAssetTrack, timeRange: CMTimeRange?, settings: [String : Any]) throws {
    reader = try AVAssetReader(asset: track.asset!)

    if let timeRange = timeRange {
      reader.timeRange = timeRange
    }

    readerOutput = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
    guard reader.canAdd(readerOutput) else {
      fatalError()
    }
    reader.add(readerOutput)

    reader.startReading()
    isActive = true
  }

  public func next() -> CMSampleBuffer? {
    guard
      isActive,
      let sample = readerOutput.copyNextSampleBuffer(),
      CMSampleBufferIsValid(sample)
      else {
        isActive = false
        return nil
    }

    return sample
  }
}
