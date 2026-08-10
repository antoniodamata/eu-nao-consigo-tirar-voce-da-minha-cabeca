//import Foundation
import AVFoundation
import Combine

class MicrophoneManager: ObservableObject {

    static let shared = MicrophoneManager()

    @Published var level: Float = 0

    private var recorder: AVAudioRecorder?

    init() {

        let session = AVAudioSession.sharedInstance()

        try? session.setCategory(.playAndRecord, options: [.defaultToSpeaker])
        try? session.setActive(true)

        let url = URL(fileURLWithPath: "/dev/null")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatAppleLossless),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.min.rawValue
        ]

        recorder = try? AVAudioRecorder(url: url, settings: settings)

        recorder?.isMeteringEnabled = true
        recorder?.record()

        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            self.recorder?.updateMeters()
            self.level = self.recorder?.averagePower(forChannel: 0) ?? 0
        }
    }
}
//  MicrophoneManager.swift
//  SensorApp
//
//  Created by Antonio Candido on 16/07/26.
//

