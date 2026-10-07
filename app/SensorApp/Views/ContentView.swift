import SwiftUI
import UIKit

struct ContentView: View {

    @StateObject private var motion = MotionManager.shared
    @StateObject private var rede = WebSocketManager.shared

    @StateObject private var activity = ActivityManager.shared
    @StateObject private var pedometer = PedometerManager.shared

    @StateObject private var location = LocationManager.shared
    @StateObject private var magnetometer = MagnetometerManager.shared
    @StateObject private var barometer = BarometerManager.shared
    @StateObject private var proximity = ProximityManager.shared
    @StateObject private var battery = BatteryManager.shared
    @StateObject private var orientation = OrientationManager.shared
    @StateObject private var brightness = BrightnessManager.shared
    @StateObject private var volume = VolumeManager.shared
    @StateObject private var microphone = MicrophoneManager.shared
    @StateObject private var headphones = HeadphonesManager.shared

    @State private var manterAcordado = true

    var body: some View {

        ScrollView {

            VStack(alignment: .leading, spacing: 16) {

                conexao

                Divider()

                Text("Accelerometer")
                    .font(.headline)

                Text("X: \(motion.state.accelerationX)")
                Text("Y: \(motion.state.accelerationY)")
                Text("Z: \(motion.state.accelerationZ)")

                Divider()

                Text("Atividade")
                    .font(.headline)

                Text("\(activity.activity) — confiança \(activity.confidence)")
                Text("Pitch: \(motion.state.pitch)")
                Text("Roll: \(motion.state.roll)")
                Text("Yaw: \(motion.state.yaw)")

                Divider()

                Text("Pedômetro")
                    .font(.headline)

                Text("Passos: \(pedometer.steps)")
                Text("Distância: \(Int(pedometer.distance)) m")
                Text("Andares subidos: \(pedometer.floorsAscended)")
                Text("Andares descidos: \(pedometer.floorsDescended)")
                Text("Cadência: \(pedometer.cadence, specifier: "%.2f") passos/s")

                Divider()

                Text("GPS")
                    .font(.headline)

                Text("Latitude: \(location.latitude)")
                Text("Longitude: \(location.longitude)")
                Text("Altitude: \(location.altitude)")
                Text("Velocidade: \(location.speed)")
                Text("Curso: \(location.course)")

                Divider()

                Text("Magnetometer")
                    .font(.headline)

                Text("X: \(magnetometer.x)")
                Text("Y: \(magnetometer.y)")
                Text("Z: \(magnetometer.z)")

                Divider()

                Text("Barômetro")
                    .font(.headline)

                Text("Pressão: \(barometer.pressure)")
                Text("Altitude relativa: \(barometer.relativeAltitude)")

                Divider()

                Text("Proximidade")
                    .font(.headline)

                Text(proximity.isNear ? "Perto" : "Longe")

                Divider()

                Text("Bateria")
                    .font(.headline)

                Text("Nível: \(Int(battery.level * 100)) %")
                Text("Estado: \(battery.state)")

                Divider()

                Text("Orientação")
                    .font(.headline)

                Text(orientation.orientation)

                Divider()

                Text("Brilho")
                    .font(.headline)

                Text("\(Int(brightness.brightness * 100)) %")

                Divider()

                Text("Volume")
                    .font(.headline)

                Text("\(volume.volume)")

                Divider()

                Text("Microfone")
                    .font(.headline)

                Text("Nível: \(microphone.level)")

                Divider()

                Text("Fones")
                    .font(.headline)

                Text(headphones.connected ? "Conectados" : "Desconectados")

            }
            .padding()
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = manterAcordado
            rede.conectar()
        }
        .onChange(of: manterAcordado) { _, novo in
            UIApplication.shared.isIdleTimerDisabled = novo
        }
    }

    // ------------------------------------------------------------ conexão

    private var conexao: some View {

        VStack(alignment: .leading, spacing: 12) {

            Text("não consigo tirar você da minha cabeça")
                .font(.title2)

            HStack(spacing: 8) {

                Circle()
                    .fill(corDoStatus)
                    .frame(width: 9, height: 9)

                Text(rede.status.descricao)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(rede.enviados) enviados")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }

            TextField("10.0.0.42:8000", text: $rede.endereco)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .font(.system(.body, design: .monospaced))
                .onSubmit { rede.conectar() }

            HStack(spacing: 12) {

                Button("Conectar") { rede.conectar() }
                    .buttonStyle(.borderedProminent)

                Button("Parar") { rede.desconectar() }
                    .buttonStyle(.bordered)

                Spacer()

                Toggle("Tela ligada", isOn: $manterAcordado)
                    .labelsHidden()
                    .fixedSize()
            }

            if let url = rede.url {
                Text(url.absoluteString)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .monospaced()
            }
        }
    }

    private var corDoStatus: Color {
        switch rede.status {
        case .conectado:    return .green
        case .conectando:   return .yellow
        case .erro:         return .red
        case .desconectado: return .gray
        }
    }
}

#Preview {
    ContentView()
}
