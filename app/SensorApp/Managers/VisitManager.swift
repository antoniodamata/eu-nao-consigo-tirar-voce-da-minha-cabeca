import Foundation
import Combine
import CoreLocation

/// O iOS avisa sozinho quando você chega e quando sai de um lugar onde
/// ficou parado. Não é o rastro contínuo: é a lista dos lugares onde você
/// permaneceu. É o gesto do "Address Book" — o registro das paradas.
final class VisitManager: NSObject, ObservableObject, CLLocationManagerDelegate {

    static let shared = VisitManager()

    private let manager = CLLocationManager()

    /// "chegou" enquanto está no lugar, "saiu" depois de partir.
    @Published var visitState: String = "—"

    /// Minutos desde que chegou ao lugar atual. Zero quando em trânsito.
    @Published var minutesHere: Double = 0

    /// Quantos lugares o sistema registrou desde que a performance começou.
    @Published var visitCount: Int = 0

    private var arrival: Date?
    private var relogio: Timer?

    private override init() {
        super.init()

        manager.delegate = self
        manager.startMonitoringVisits()

        relogio = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            guard let self = self, let chegada = self.arrival else { return }
            self.minutesHere = Date().timeIntervalSince(chegada) / 60
        }
    }

    func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {

        let distante = Date.distantPast

        // Uma visita sem data de partida significa que ele acabou de chegar.
        if visit.departureDate == distante || visit.departureDate > Date() {

            arrival = visit.arrivalDate == distante ? Date() : visit.arrivalDate
            visitState = "chegou"
            visitCount += 1
            minutesHere = 0

        } else {

            arrival = nil
            visitState = "saiu"
            minutesHere = 0
        }
    }

    deinit {
        relogio?.invalidate()
        manager.stopMonitoringVisits()
    }
}
