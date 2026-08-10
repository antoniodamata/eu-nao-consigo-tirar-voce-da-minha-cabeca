//import Foundation
import AVFoundation
import Combine

class HeadphonesManager: ObservableObject {

    static let shared = HeadphonesManager()

    @Published var connected = false

    init() {

        update()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateRoute),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }

    @objc func updateRoute() {
        update()
    }

    func update() {

        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs

        connected = outputs.contains {
            $0.portType == .headphones ||
            $0.portType == .bluetoothA2DP ||
            $0.portType == .bluetoothLE ||
            $0.portType == .bluetoothHFP
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
//  HeadphonesManager.swift
//  SensorApp
//
//  Created by Antonio Candido on 16/07/26.
//

