import Foundation

/// Junta as leituras de todos os managers num único DeviceState e envia.
final class SensorHub {

    static let shared = SensorHub()

    private let websocket = WebSocketManager.shared

    /// O MotionManager dispara a 10 Hz, mas o servidor só precisa do estado
    /// duas vezes por segundo. Isto poupa rede e bateria.
    private let intervaloEnvio: TimeInterval = 0.5

    private var ultimoEnvio: TimeInterval = 0

    private init() {}

    func update(motion: SensorState) {

        let agora = Date().timeIntervalSince1970

        guard agora - ultimoEnvio >= intervaloEnvio else { return }

        ultimoEnvio = agora

        let device = DeviceState(

            timestamp: motion.timestamp,

            // Movimento
            accelerationX: motion.accelerationX,
            accelerationY: motion.accelerationY,
            accelerationZ: motion.accelerationZ,

            // Localização
            latitude: LocationManager.shared.latitude,
            longitude: LocationManager.shared.longitude,
            altitude: LocationManager.shared.altitude,
            speed: LocationManager.shared.speed,
            course: LocationManager.shared.course,
            heading: LocationManager.shared.heading,

            // Magnetômetro
            magneticX: MagnetometerManager.shared.x,
            magneticY: MagnetometerManager.shared.y,
            magneticZ: MagnetometerManager.shared.z,

            // Barômetro
            pressure: BarometerManager.shared.pressure,
            relativeAltitude: BarometerManager.shared.relativeAltitude,

            // Bateria
            batteryLevel: BatteryManager.shared.level,
            batteryState: BatteryManager.shared.state,

            // Tela
            brightness: Double(BrightnessManager.shared.brightness),

            // Proximidade
            proximity: ProximityManager.shared.isNear,

            // Orientação
            orientation: OrientationManager.shared.orientation,

            // Áudio
            volume: VolumeManager.shared.volume,
            microphoneLevel: MicrophoneManager.shared.level,
            headphonesConnected: HeadphonesManager.shared.connected
        )

        websocket.send(device)
    }
}
