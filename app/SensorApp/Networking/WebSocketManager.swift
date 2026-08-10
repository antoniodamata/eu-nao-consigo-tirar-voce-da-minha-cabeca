import Foundation
import Combine

final class WebSocketManager: ObservableObject {

    static let shared = WebSocketManager()

    enum Status: Equatable {
        case desconectado
        case conectando
        case conectado
        case erro(String)

        var descricao: String {
            switch self {
            case .desconectado: return "desconectado"
            case .conectando:   return "conectando…"
            case .conectado:    return "conectado"
            case .erro(let m):  return m
            }
        }
    }

    @Published private(set) var status: Status = .desconectado
    @Published private(set) var enviados: Int = 0

    /// Endereço do servidor. Aceita "10.0.0.42:8000" ou "wss://meuservidor.com/ws".
    @Published var endereco: String {
        didSet {
            UserDefaults.standard.set(endereco, forKey: Self.chaveEndereco)
        }
    }

    private static let chaveEndereco = "servidor.endereco"
    private static let enderecoPadrao = "10.0.0.42:8000"

    private var socket: URLSessionWebSocketTask?
    private var tentativas = 0
    private var reconexaoAgendada = false
    private var querConectar = false

    private init() {
        endereco = UserDefaults.standard.string(forKey: Self.chaveEndereco)
            ?? Self.enderecoPadrao
    }

    // ------------------------------------------------------------ endereço

    /// Monta a URL final a partir do que a pessoa digitou.
    var url: URL? {

        let texto = endereco.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !texto.isEmpty else { return nil }

        var completo = texto

        if !completo.contains("://") {
            completo = "ws://" + completo
        }

        guard var partes = URLComponents(string: completo) else { return nil }

        if partes.path.isEmpty || partes.path == "/" {
            partes.path = "/ws"
        }

        guard let host = partes.host, !host.isEmpty else { return nil }

        return partes.url
    }

    // ------------------------------------------------------------ conexão

    func conectar() {

        querConectar = true

        guard let url = url else {
            atualizar(.erro("endereço inválido"))
            return
        }

        fecharSocket()

        atualizar(.conectando)

        let task = URLSession.shared.webSocketTask(with: url)
        socket = task
        task.resume()

        receber()
        confirmar(task)
    }

    func desconectar() {
        querConectar = false
        tentativas = 0
        fecharSocket()
        atualizar(.desconectado)
    }

    private func fecharSocket() {
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
    }

    /// O URLSessionWebSocketTask não avisa quando conecta.
    /// Um ping que volta é a confirmação de que o canal está de pé.
    private func confirmar(_ task: URLSessionWebSocketTask) {

        task.sendPing { [weak self] erro in

            guard let self = self else { return }
            guard task === self.socket else { return }

            if let erro = erro {
                self.falhou(erro)
            } else {
                self.tentativas = 0
                self.atualizar(.conectado)
            }
        }
    }

    // ------------------------------------------------------------ envio

    func send(_ state: DeviceState) {

        guard let task = socket else { return }

        let message = URLSessionWebSocketTask.Message.string(state.toJSON())

        task.send(message) { [weak self] erro in

            guard let self = self else { return }

            // Se este socket já foi descartado, o erro dele não interessa.
            guard task === self.socket else { return }

            if let erro = erro {
                self.falhou(erro)
            } else {
                DispatchQueue.main.async { self.enviados += 1 }
            }
        }
    }

    // ------------------------------------------------------------ recepção

    private func receber() {

        guard let task = socket else { return }

        task.receive { [weak self] resultado in

            guard let self = self else { return }

            // Cancelar um socket faz o receive dele falhar. Sem esta guarda,
            // esse erro agendaria uma reconexão que cancelaria o socket novo,
            // e assim por diante — o laço que enchia o terminal.
            guard task === self.socket else { return }

            switch resultado {

            case .success:
                self.receber()

            case .failure(let erro):
                self.falhou(erro)
            }
        }
    }

    // ------------------------------------------------------------ falhas

    private func falhou(_ erro: Error) {

        guard querConectar else { return }

        atualizar(.erro(Self.legivel(erro)))
        agendarReconexao()
    }

    private func agendarReconexao() {

        guard querConectar, !reconexaoAgendada else { return }
        guard status != .conectado else { return }

        reconexaoAgendada = true
        tentativas += 1

        let espera = min(pow(2.0, Double(tentativas)), 20.0)

        DispatchQueue.main.asyncAfter(deadline: .now() + espera) { [weak self] in

            guard let self = self else { return }

            self.reconexaoAgendada = false

            if self.querConectar {
                self.conectar()
            }
        }
    }

    private static func legivel(_ erro: Error) -> String {

        let ns = erro as NSError

        switch ns.code {
        case NSURLErrorCannotConnectToHost:   return "servidor não responde"
        case NSURLErrorNotConnectedToInternet: return "sem rede"
        case NSURLErrorTimedOut:              return "tempo esgotado"
        case NSURLErrorNetworkConnectionLost: return "conexão perdida"
        case NSURLErrorAppTransportSecurityRequiresSecureConnection:
            return "bloqueado pelo ATS"
        default:
            return ns.localizedDescription.lowercased()
        }
    }

    private func atualizar(_ novo: Status) {
        DispatchQueue.main.async { self.status = novo }
    }
}
