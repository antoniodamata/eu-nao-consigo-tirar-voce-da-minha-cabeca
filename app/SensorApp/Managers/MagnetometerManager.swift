import Foundation
import Combine
import CoreMotion

class MagnetometerManager: ObservableObject {

    static let shared = MagnetometerManager()

    private let motionManager = CMMotionManager()

    @Published var x: Double = 0
    @Published var y: Double = 0
    @Published var z: Double = 0

    init() {

        guard motionManager.isMagnetometerAvailable else {
            print("Magnetômetro indisponível.")
            return
        }

        motionManager.magnetometerUpdateInterval = 1.0 / 30.0

        motionManager.startMagnetometerUpdates(to: .main) { [weak self] data, error in

            guard let field = data?.magneticField else { return }

            self?.x = field.x
            self?.y = field.y
            self?.z = field.z
        }
    }
}
//  MagnetometerManager.swift
//  SensorApp
//
//  Created by Antonio Candido on 16/07/26.
//

