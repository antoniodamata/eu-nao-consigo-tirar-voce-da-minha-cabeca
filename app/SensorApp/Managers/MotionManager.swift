import Foundation
import CoreMotion
import Observation

@Observable
class MotionManager {

    private let motionManager = CMMotionManager()
    let hub = SensorHub()

    var state = SensorState(
        timestamp: Date().timeIntervalSince1970,
        accelerationX: 0,
        accelerationY: 0,
        accelerationZ: 0
    )

    init() {
        start()
    }

    func start() {

        guard motionManager.isAccelerometerAvailable else {
            return
        }

        motionManager.accelerometerUpdateInterval = 0.1

        motionManager.startAccelerometerUpdates(to: .main) { data, error in

            guard let data else { return }

            self.state = SensorState(
                timestamp: Date().timeIntervalSince1970,
                accelerationX: data.acceleration.x,
                accelerationY: data.acceleration.y,
                accelerationZ: data.acceleration.z
            )

            self.hub.update(state: self.state)

            print(self.state.toJSON())

        }

    }

}
