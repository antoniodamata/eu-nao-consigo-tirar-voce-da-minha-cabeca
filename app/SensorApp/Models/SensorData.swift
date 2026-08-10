import Foundation

struct SensorState: Codable {

    let timestamp: TimeInterval

    // aceleração linear
    let accelerationX: Double
    let accelerationY: Double
    let accelerationZ: Double

    // gravidade
    let gravityX: Double
    let gravityY: Double
    let gravityZ: Double

    // rotação
    let rotationX: Double
    let rotationY: Double
    let rotationZ: Double

    // orientação
    let pitch: Double
    let roll: Double
    let yaw: Double

    func toJSON() -> String {

        let encoder = JSONEncoder()

        encoder.outputFormatting = .prettyPrinted

        guard let data = try? encoder.encode(self) else {
            return "{}"
        }

        return String(data: data, encoding: .utf8) ?? "{}"

    }

}
