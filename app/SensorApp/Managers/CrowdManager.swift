import Foundation
import Combine
import CoreBluetooth
import Contacts

/// Contagens, nunca identidades.
///
/// Conta quantos aparelhos Bluetooth estão ao alcance e quantos nomes há na
/// agenda — sem guardar identificador, nome ou número de ninguém. O divíduo
/// é número: "há sete aparelhos perto dele" diz o que precisa ser dito sem
/// expor quem não consentiu.
final class CrowdManager: NSObject, ObservableObject, CBCentralManagerDelegate {

    static let shared = CrowdManager()

    /// Aparelhos distintos vistos na última janela.
    @Published var nearbyDevices: Int = 0

    /// Total de nomes guardados na agenda. Só o total.
    @Published var contactCount: Int = 0

    private var central: CBCentralManager?

    /// Guardamos apenas o hash do identificador, e só para não contar duas
    /// vezes o mesmo aparelho. A janela é esvaziada a cada trinta segundos.
    private var vistos: Set<Int> = []
    private var relogio: Timer?

    private override init() {
        super.init()

        central = CBCentralManager(delegate: self, queue: nil)

        relogio = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.nearbyDevices = self.vistos.count
            self.vistos.removeAll()
        }

        contarContatos()
    }

    // ---------------------------------------------------------- bluetooth

    func centralManagerDidUpdateState(_ central: CBCentralManager) {

        guard central.state == .poweredOn else { return }

        central.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {

        // hashValue, não o UUID. Serve para não contar duas vezes e para
        // mais nada — não dá para voltar ao aparelho a partir dele.
        vistos.insert(peripheral.identifier.hashValue)
    }

    // ---------------------------------------------------------- contatos

    private func contarContatos() {

        let store = CNContactStore()

        store.requestAccess(for: .contacts) { [weak self] permitido, _ in

            guard permitido else { return }

            var total = 0

            let pedido = CNContactFetchRequest(
                keysToFetch: [CNContactIdentifierKey as CNKeyDescriptor]
            )

            // Só incrementa. Nenhum nome é lido, guardado ou enviado.
            try? store.enumerateContacts(with: pedido) { _, _ in total += 1 }

            DispatchQueue.main.async {
                self?.contactCount = total
            }
        }
    }

    deinit {
        relogio?.invalidate()
        central?.stopScan()
    }
}
