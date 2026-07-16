import Foundation

class WebSocketManager {

    private var socket: URLSessionWebSocketTask?

    init() {

        guard let url = URL(string: "ws://10.0.0.42:8000/ws") else {
            print("URL inválida.")
            return
        }

        socket = URLSession.shared.webSocketTask(with: url)

        socket?.resume()

        receive()

        print("WebSocket iniciado.")

    }

    func send(_ state: SensorState) {

        let message = URLSessionWebSocketTask.Message.string(
            state.toJSON()
        )

        socket?.send(message) { error in

            if let error = error {

                print("Erro ao enviar:", error)

            }

        }

    }

    private func receive() {

        socket?.receive { [weak self] result in

            switch result {

            case .success(let message):

                print("Recebido:", message)

                // Continua escutando
                self?.receive()

            case .failure(let error):

                print("Erro WebSocket:", error)

            }

        }

    }

}
