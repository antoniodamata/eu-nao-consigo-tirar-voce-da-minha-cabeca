import Foundation
import CoreMotion
import Combine

/// Passos, distância e andares desde o início da performance.
final class PedometerManager: ObservableObject {

    static let shared = PedometerManager()

    private let pedometer = CMPedometer()

    @Published var steps: Int = 0
    @Published var distance: Double = 0
    @Published var floorsAscended: Int = 0
    @Published var floorsDescended: Int = 0
    @Published var cadence: Double = 0

    private init() {

        guard CMPedometer.isStepCountingAvailable() else {
            print("Pedômetro não disponível.")
            return
        }

        // A contagem começa agora: é a performance, não o dia.
        pedometer.startUpdates(from: Date()) { [weak self] dados, erro in

            guard let self = self, let dados = dados else { return }

            DispatchQueue.main.async {
                self.steps = dados.numberOfSteps.intValue
                self.distance = dados.distance?.doubleValue ?? 0
                self.floorsAscended = dados.floorsAscended?.intValue ?? 0
                self.floorsDescended = dados.floorsDescended?.intValue ?? 0
                self.cadence = dados.currentCadence?.doubleValue ?? 0
            }
        }
    }

    deinit {
        pedometer.stopUpdates()
    }
}
