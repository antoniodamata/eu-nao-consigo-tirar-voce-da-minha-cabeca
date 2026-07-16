import Foundation

struct SensorState: Codable {

    let timestamp: TimeInterval

    let accelerationX: Double
    let accelerationY: Double
    let accelerationZ: Double

    func toJSON() -> String {

        let encoder = JSONEncoder()

        encoder.outputFormatting = .prettyPrinted

        guard let data = try? encoder.encode(self) else {
            return "{}"
        }

        return String(data: data, encoding: .utf8) ?? "{}"

    }

}
