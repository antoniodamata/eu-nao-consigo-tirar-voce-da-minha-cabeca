import Foundation
import UIKit
import Combine
import AVFoundation

class VolumeManager: ObservableObject {

    static let shared = VolumeManager()

    @Published var volume: Float = AVAudioSession.sharedInstance().outputVolume

    init() {

        try? AVAudioSession.sharedInstance().setActive(true)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateVolume),
            name: NSNotification.Name("AVSystemController_SystemVolumeDidChangeNotification"),
            object: nil
        )
    }

    @objc func updateVolume() {
        volume = AVAudioSession.sharedInstance().outputVolume
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}//
//  VolumeManager.swift
//  SensorApp
//
//  Created by Antonio Candido on 16/07/26.
//

