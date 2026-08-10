//import Foundation
import UIKit
import Combine

class ProximityManager: ObservableObject {

    static let shared = ProximityManager()

    @Published var isNear = false

    init() {

        UIDevice.current.isProximityMonitoringEnabled = true

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(proximityChanged),
            name: UIDevice.proximityStateDidChangeNotification,
            object: nil
        )

        isNear = UIDevice.current.proximityState
    }

    @objc func proximityChanged() {
        isNear = UIDevice.current.proximityState
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
//  ProximityManager.swift
//  SensorApp
//
//  Created by Antonio Candido on 16/07/26.
//

