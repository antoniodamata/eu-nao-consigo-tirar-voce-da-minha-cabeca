//import Foundation
import Combine
import CoreMotion

class BarometerManager: ObservableObject {

    static let shared = BarometerManager()

    private let altimeter = CMAltimeter()

    @Published var pressure: Double = 0
    @Published var relativeAltitude: Double = 0

    init() {

        guard CMAltimeter.isRelativeAltitudeAvailable() else {
            print("Barômetro não disponível.")
            return
        }

        altimeter.startRelativeAltitudeUpdates(to: .main) { data, error in

            guard let data = data else { return }

            self.pressure = data.pressure.doubleValue
            self.relativeAltitude = data.relativeAltitude.doubleValue
        }
    }
}
//  BarometerManager.swift
//  SensorApp
//
//  Created by Antonio Candido on 16/07/26.
//

