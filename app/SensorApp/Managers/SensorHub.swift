import Foundation

class SensorHub {

    private let websocket = WebSocketManager()

    func update(state: SensorState) {

        websocket.send(state)

    }

}
