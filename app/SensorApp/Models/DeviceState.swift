import Foundation
struct DeviceState: Codable {

    let timestamp: TimeInterval

    // Movimento
    let accelerationX: Double
    let accelerationY: Double
    let accelerationZ: Double

    // Postura do aparelho: distingue no bolso, na mão, encostado no ouvido
    let pitch: Double
    let roll: Double
    let yaw: Double

    // O que o próprio iOS acha que ele está fazendo
    let activity: String
    let activityConfidence: String

    // Contagem desde o início da performance
    let steps: Int
    let distance: Double
    let floorsAscended: Int
    let floorsDescended: Int
    let cadence: Double

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

    // Áudio — nada é gravado, só medido
    let volume: Float
    let microphoneLevel: Float
    let voiceRatio: Float
    let speech: Bool
    let headphonesConnected: Bool

    // Orientação da cabeça, quando há AirPods
    let headAvailable: Bool
    let headPitch: Double
    let headYaw: Double

    // Onde ele parou
    let visitState: String
    let minutesHere: Double
    let visitCount: Int

    // Ambiente do aparelho
    let thermalState: String
    let lowPowerMode: Bool
    let networkType: String
    let absoluteAltitude: Double

    // Contagens, nunca identidades
    let nearbyDevices: Int
    let contactCount: Int

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

