//import Foundation
import UIKit
import Combine

class BrightnessManager: ObservableObject {

    static let shared = BrightnessManager()

    @Published var brightness: CGFloat = UIScreen.main.brightness

    init() {

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateBrightness),
            name: UIScreen.brightnessDidChangeNotification,
            object: nil
        )
    }

    @objc func updateBrightness() {
        brightness = UIScreen.main.brightness
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
//  BrightnessManager.swift
//  SensorApp
//
//  Created by Antonio Candido on 16/07/26.
//

