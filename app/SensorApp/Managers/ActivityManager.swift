import Foundation
import CoreMotion
import Combine

/// O próprio iOS classifica o que a pessoa está fazendo. Aqui só pedimos
/// o resultado: parado, andando, correndo, de bicicleta, em veículo.
final class ActivityManager: ObservableObject {

    static let shared = ActivityManager()

    private let manager = CMMotionActivityManager()

    @Published var activity: String = "desconhecida"
    @Published var confidence: String = "—"

    private init() {

        guard CMMotionActivityManager.isActivityAvailable() else {
            print("Classificação de atividade não disponível.")
            return
        }

        manager.startActivityUpdates(to: .main) { [weak self] atividade in

            guard let self = self, let atividade = atividade else { return }

            self.activity = Self.descrever(atividade)
            self.confidence = Self.descreverConfianca(atividade.confidence)
        }
    }

    /// Vários sinalizadores podem estar ligados ao mesmo tempo. A ordem
    /// abaixo é de prioridade: quem se move mais ganha.
    private static func descrever(_ a: CMMotionActivity) -> String {

        if a.automotive { return "em veículo" }
        if a.cycling    { return "de bicicleta" }
        if a.running    { return "correndo" }
        if a.walking    { return "andando" }
        if a.stationary { return "parado" }

        return "desconhecida"
    }

    private static func descreverConfianca(_ c: CMMotionActivityConfidence) -> String {

        switch c {
        case .high:   return "alta"
        case .medium: return "média"
        case .low:    return "baixa"
        @unknown default: return "—"
        }
    }

    deinit {
        manager.stopActivityUpdates()
    }
}
