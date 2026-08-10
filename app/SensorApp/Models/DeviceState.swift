import Foundation
struct DeviceState: Codable {

    let timestamp: TimeInterval

    // Movimento
    let accelerationX: Double
    let accelerationY: Double
    let accelerationZ: Double

    // Localização
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let speed: Double
    let course: Double
    let heading: Double

    // Campo magnético
    let magneticX: Double
    let magneticY: Double
    let magneticZ: Double

    // Atmosfera
    let pressure: Double
    let relativeAltitude: Double

    // Dispositivo
    let batteryLevel: Float
    let batteryState: String
    let brightness: Double
    let proximity: Bool
    let orientation: String

    // Áudio
    let volume: Float
    let microphoneLevel: Float
    let headphonesConnected: Bool

    func toJSON() -> String {

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        guard let data = try? encoder.encode(self) else {
            return "{}"
        }

        return String(data: data, encoding: .utf8) ?? "{}"

    }

}
//  DeviceState.swift
//  SensorApp
//
//  Created by Antonio Candido on 16/07/26.
//

