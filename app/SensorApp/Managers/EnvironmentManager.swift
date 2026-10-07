import Foundation
import Combine
import UIKit
import CoreMotion
import Network

/// Estado do aparelho como corpo: temperatura, economia de energia, que
/// tipo de rede o carrega, a que altura do mar ele está.
final class EnvironmentManager: ObservableObject {

    static let shared = EnvironmentManager()

    @Published var thermalState: String = "normal"
    @Published var lowPowerMode: Bool = false
    @Published var networkType: String = "—"
    @Published var absoluteAltitude: Double = 0

    private let altimetro = CMAltimeter()
    private let monitor = NWPathMonitor()
    private var relogio: Timer?

    private init() {

        atualizarEnergia()

        NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.atualizarEnergia()
        }

        NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.atualizarEnergia()
        }

        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.networkType = Self.descreverRede(path)
            }
        }

        monitor.start(queue: DispatchQueue(label: "rede"))

        if #available(iOS 15.0, *),
           CMAltimeter.isAbsoluteAltitudeAvailable() {

            altimetro.startAbsoluteAltitudeUpdates(to: .main) { [weak self] dados, _ in
                guard let dados = dados else { return }
                self?.absoluteAltitude = dados.altitude
            }
        }

        // O estado térmico não notifica com frequência suficiente sozinho.
        relogio = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            self?.atualizarEnergia()
        }
    }

    private func atualizarEnergia() {

        let info = ProcessInfo.processInfo

        lowPowerMode = info.isLowPowerModeEnabled

        switch info.thermalState {
        case .nominal:  thermalState = "normal"
        case .fair:     thermalState = "morno"
        case .serious:  thermalState = "quente"
        case .critical: thermalState = "muito quente"
        @unknown default: thermalState = "—"
        }
    }

    private static func descreverRede(_ path: NWPath) -> String {

        guard path.status == .satisfied else { return "sem rede" }

        if path.usesInterfaceType(.wifi)          { return "wi-fi" }
        if path.usesInterfaceType(.cellular)      { return "celular" }
        if path.usesInterfaceType(.wiredEthernet) { return "cabo" }

        return "outra"
    }

    deinit {
        relogio?.invalidate()
        monitor.cancel()
        altimetro.stopAbsoluteAltitudeUpdates()
    }
}
