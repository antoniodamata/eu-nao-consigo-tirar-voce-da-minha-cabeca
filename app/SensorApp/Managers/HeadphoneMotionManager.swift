import Foundation
import Combine
import CoreMotion

/// Com AirPods, para onde a cabeça dele está virada.
final class HeadphoneMotionManager: ObservableObject {

    static let shared = HeadphoneMotionManager()

    private let manager = CMHeadphoneMotionManager()

    @Published var headAvailable: Bool = false
    @Published var headPitch: Double = 0
    @Published var headRoll: Double = 0
    @Published var headYaw: Double = 0

    private init() {

        guard manager.isDeviceMotionAvailable else { return }

        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in

            guard let self = self, let motion = motion else {
                self?.headAvailable = false
                return
            }

            self.headAvailable = true
            self.headPitch = motion.attitude.pitch
            self.headRoll = motion.attitude.roll
            self.headYaw = motion.attitude.yaw
        }
    }

    deinit {
        manager.stopDeviceMotionUpdates()
    }
}
