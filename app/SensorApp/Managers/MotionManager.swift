import Foundation
import CoreMotion
import Combine

class MotionManager: ObservableObject {

    private let motionManager = CMMotionManager()

    @Published var state = SensorState(
        timestamp: 0,

        accelerationX: 0,
        accelerationY: 0,
        accelerationZ: 0,

        gravityX: 0,
        gravityY: 0,
        gravityZ: 0,

        rotationX: 0,
        rotationY: 0,
        rotationZ: 0,

        pitch: 0,
        roll: 0,
        yaw: 0
    )

    private let hub = SensorHub.shared

    static let shared = MotionManager()

    private init() {

        guard motionManager.isDeviceMotionAvailable else {
            print("Device Motion não disponível")
            return
        }

        motionManager.deviceMotionUpdateInterval = 0.1

        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in

            guard let self = self else { return }
            guard let motion = motion else { return }

            let newState = SensorState(

                timestamp: Date().timeIntervalSince1970,

                accelerationX: motion.userAcceleration.x,
                accelerationY: motion.userAcceleration.y,
                accelerationZ: motion.userAcceleration.z,

                gravityX: motion.gravity.x,
                gravityY: motion.gravity.y,
                gravityZ: motion.gravity.z,

                rotationX: motion.rotationRate.x,
                rotationY: motion.rotationRate.y,
                rotationZ: motion.rotationRate.z,

                pitch: motion.attitude.pitch,
                roll: motion.attitude.roll,
                yaw: motion.attitude.yaw
            )

            self.state = newState

            self.hub.update(motion: newState)

        }
    }

    deinit {
        motionManager.stopDeviceMotionUpdates()
    }
}
