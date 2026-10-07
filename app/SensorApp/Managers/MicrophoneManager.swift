import Foundation
import AVFoundation
import Accelerate
import Combine

/// Ouve sem gravar.
///
/// O buffer do microfone é analisado em memória e descartado no mesmo
/// instante: nada é escrito em disco, nada é transcrito, nada sai do
/// aparelho além de três números. Saber que alguém falou, nunca o quê.
final class MicrophoneManager: ObservableObject {

    static let shared = MicrophoneManager()

    /// Potência média em dB, como antes.
    @Published var level: Float = 0

    /// Fração da energia que está na faixa da voz humana, de 0 a 1.
    @Published var voiceRatio: Float = 0

    /// Há fala por perto neste instante.
    @Published var speech: Bool = false

    private let engine = AVAudioEngine()

    private let tamanho = 2048
    private var fft: vDSP.FFT<DSPSplitComplex>?
    private var janela: [Float] = []

    // Faixa aproximada da fala humana.
    private let vozMin: Float = 300
    private let vozMax: Float = 3400

    // A partir de que fração da energia consideramos que há fala, e quão
    // alto ela precisa estar para não ser eco do próprio ambiente.
    private let limiarRazao: Float = 0.45
    private let limiarNivel: Float = -42

    private init() {

        let sessao = AVAudioSession.sharedInstance()

        try? sessao.setCategory(.playAndRecord, options: [.defaultToSpeaker, .mixWithOthers])
        try? sessao.setActive(true)

        let log2n = vDSP_Length(log2(Float(tamanho)))
        fft = vDSP.FFT(log2n: log2n, radix: .radix2, ofType: DSPSplitComplex.self)

        janela = vDSP.window(ofType: Float.self,
                             usingSequence: .hanningDenormalized,
                             count: tamanho,
                             isHalfWindow: false)

        let entrada = engine.inputNode
        let formato = entrada.outputFormat(forBus: 0)

        entrada.installTap(onBus: 0,
                           bufferSize: AVAudioFrameCount(tamanho),
                           format: formato) { [weak self] buffer, _ in
            self?.analisar(buffer, taxa: Float(formato.sampleRate))
        }

        engine.prepare()

        do {
            try engine.start()
        } catch {
            print("Microfone não pôde iniciar:", error.localizedDescription)
        }
    }

    private func analisar(_ buffer: AVAudioPCMBuffer, taxa: Float) {

        guard let canal = buffer.floatChannelData?[0] else { return }

        let n = min(Int(buffer.frameLength), tamanho)

        guard n == tamanho, let fft = fft else { return }

        var amostras = [Float](repeating: 0, count: tamanho)
        for i in 0..<tamanho { amostras[i] = canal[i] }

        // Nível, em dB, do mesmo jeito que antes.
        var quadratico: Float = 0
        vDSP_measqv(amostras, 1, &quadratico, vDSP_Length(tamanho))
        let db = 10 * log10f(max(quadratico, 1e-12))

        // Janela de Hanning antes da transformada, senão as bordas do
        // buffer viram frequência que não existe.
        vDSP.multiply(amostras, janela, result: &amostras)

        var real = [Float](repeating: 0, count: tamanho / 2)
        var imag = [Float](repeating: 0, count: tamanho / 2)
        var magnitudes = [Float](repeating: 0, count: tamanho / 2)

        real.withUnsafeMutableBufferPointer { r in
            imag.withUnsafeMutableBufferPointer { i in

                var saida = DSPSplitComplex(realp: r.baseAddress!, imagp: i.baseAddress!)

                amostras.withUnsafeBytes { bruto in
                    let complexos = bruto.bindMemory(to: DSPComplex.self)
                    vDSP_ctoz(complexos.baseAddress!, 2, &saida, 1, vDSP_Length(tamanho / 2))
                }

                fft.forward(input: saida, output: &saida)
                vDSP.absolute(saida, result: &magnitudes)
            }
        }

        // Quanta energia está na faixa da voz, contra o total.
        let resolucao = taxa / Float(tamanho)

        var energiaVoz: Float = 0
        var energiaTotal: Float = 0

        for k in 1..<magnitudes.count {

            let freq = Float(k) * resolucao
            let e = magnitudes[k] * magnitudes[k]

            energiaTotal += e

            if freq >= vozMin && freq <= vozMax {
                energiaVoz += e
            }
        }

        let razao = energiaTotal > 0 ? energiaVoz / energiaTotal : 0
        let temFala = razao > limiarRazao && db > limiarNivel

        DispatchQueue.main.async {
            self.level = db
            self.voiceRatio = razao
            self.speech = temFala
        }
    }

    deinit {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }
}
