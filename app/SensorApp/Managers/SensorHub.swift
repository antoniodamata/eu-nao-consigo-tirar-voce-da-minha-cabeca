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

            // Postura — já vinha calculada e era descartada aqui
            pitch: motion.pitch,
            roll: motion.roll,
            yaw: motion.yaw,

            // Classificação do próprio sistema
            activity: ActivityManager.shared.activity,
            activityConfidence: ActivityManager.shared.confidence,

            // Pedômetro
            steps: PedometerManager.shared.steps,
            distance: PedometerManager.shared.distance,
            floorsAscended: PedometerManager.shared.floorsAscended,
            floorsDescended: PedometerManager.shared.floorsDescended,
            cadence: PedometerManager.shared.cadence,

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
            voiceRatio: MicrophoneManager.shared.voiceRatio,
            speech: MicrophoneManager.shared.speech,
            headphonesConnected: HeadphonesManager.shared.connected,

            // Cabeça
            headAvailable: HeadphoneMotionManager.shared.headAvailable,
            headPitch: HeadphoneMotionManager.shared.headPitch,
            headYaw: HeadphoneMotionManager.shared.headYaw,

            // Paradas
            visitState: VisitManager.shared.visitState,
            minutesHere: VisitManager.shared.minutesHere,
            visitCount: VisitManager.shared.visitCount,

            // Ambiente
            thermalState: EnvironmentManager.shared.thermalState,
            lowPowerMode: EnvironmentManager.shared.lowPowerMode,
            networkType: EnvironmentManager.shared.networkType,
            absoluteAltitude: EnvironmentManager.shared.absoluteAltitude,

            // Contagens
            nearbyDevices: CrowdManager.shared.nearbyDevices,
            contactCount: CrowdManager.shared.contactCount
        )

        websocket.send(device)
    }
}
