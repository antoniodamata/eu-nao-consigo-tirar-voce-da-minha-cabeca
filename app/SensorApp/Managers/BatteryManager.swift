//import Foundation
import UIKit
import Combine

class BatteryManager: ObservableObject {

    static let shared = BatteryManager()

    @Published var level: Float = 0
    @Published var state: String = "Desconhecido"

    init() {

        UIDevice.current.isBatteryMonitoringEnabled = true

        update()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateBattery),
            name: UIDevice.batteryLevelDidChangeNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateBattery),
            name: UIDevice.batteryStateDidChangeNotification,
            object: nil
        )
    }

    @objc func updateBattery() {
        update()
    }

    private func update() {

        level = UIDevice.current.batteryLevel

        switch UIDevice.current.batteryState {

        case .charging:
            state = "Carregando"

        case .full:
            state = "Completa"

        case .unplugged:
            state = "Na bateria"

        default:
            state = "Desconhecido"
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
//  BatteryManager.swift
//  SensorApp
//
//  Created by Antonio Candido on 16/07/26.
//

