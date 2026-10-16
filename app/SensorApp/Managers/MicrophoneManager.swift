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

    /// Potência média em dB.
    @Published var level: Float = 0

    /// Fração da energia que está na faixa da voz humana, de 0 a 1.
    @Published var voiceRatio: Float = 0

    /// Há fala por perto neste instante.
    @Published var speech: Bool = false

    private let engine = AVAudioEngine()

    private let tamanho = 2048
    private let metade = 1024

    private var fft: vDSP.FFT<DSPSplitComplex>?

    // Buffers pré-alocados: o tap dispara muitas vezes por segundo e alocar
    // arrays a cada chamada seria desperdício dentro de callback de áudio.
    private var janela: [Float] = []
    private var amostras: [Float] = []
    private var janelado: [Float] = []
    private var realEntrada: [Float] = []
    private var imagEntrada: [Float] = []
    private var realSaida: [Float] = []
    private var imagSaida: [Float] = []
    private var magnitudes: [Float] = []

    // Faixa aproximada da fala humana.
    private let vozMin: Float = 300
    private let vozMax: Float = 3400

    private let limiarRazao: Float = 0.45
    private let limiarNivel: Float = -42

    private init() {

        let sessao = AVAudioSession.sharedInstance()

        try? sessao.setCategory(.playAndRecord,
                                options: [.defaultToSpeaker, .mixWithOthers])
        try? sessao.setActive(true)

        let log2n = vDSP_Length(log2(Float(tamanho)))
        fft = vDSP.FFT(log2n: log2n, radix: .radix2, ofType: DSPSplitComplex.self)

        janela = vDSP.window(ofType: Float.self,
                             usingSequence: .hanningDenormalized,
                             count: tamanho,
                             isHalfWindow: false)

        amostras    = [Float](repeating: 0, count: tamanho)
        janelado    = [Float](repeating: 0, count: tamanho)
        realEntrada = [Float](repeating: 0, count: metade)
        imagEntrada = [Float](repeating: 0, count: metade)
        realSaida   = [Float](repeating: 0, count: metade)
        imagSaida   = [Float](repeating: 0, count: metade)
        magnitudes  = [Float](repeating: 0, count: metade)

        let entrada = engine.inputNode
        let formato = entrada.outputFormat(forBus: 0)

        guard formato.sampleRate > 0 else {
            print("Microfone sem formato válido.")
            return
        }

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

        guard let canal = buffer.floatChannelData?[0], let fft = fft else { return }

        // O AVAudioEngine trata bufferSize como sugestão e costuma entregar
        // outro tamanho. Em vez de recusar, pegamos o que couber e
        // completamos com zeros — recusar faria o detector nunca rodar.
        let disponivel = min(Int(buffer.frameLength), tamanho)

        guard disponivel > 0 else { return }

        for i in 0..<disponivel { amostras[i] = canal[i] }
        if disponivel < tamanho {
            for i in disponivel..<tamanho { amostras[i] = 0 }
        }

        // Nível em dB, sobre as amostras cruas.
        var quadratico: Float = 0
        vDSP_measqv(amostras, 1, &quadratico, vDSP_Length(disponivel))
        let db = 10 * log10f(max(quadratico, 1e-12))

        // Janela de Hanning antes da transformada, senão as bordas do buffer
        // viram frequência que não existe. Saída em array separado: o vDSP
        // não garante nada quando entrada e saída são o mesmo buffer.
        vDSP.multiply(amostras, janela, result: &janelado)

        var razao: Float = 0

        janelado.withUnsafeBufferPointer { entradaBruta in

            entradaBruta.baseAddress!.withMemoryRebound(
                to: DSPComplex.self, capacity: metade
            ) { complexos in

                realEntrada.withUnsafeMutableBufferPointer { re in
                imagEntrada.withUnsafeMutableBufferPointer { ie in
                realSaida.withUnsafeMutableBufferPointer { rs in
                imagSaida.withUnsafeMutableBufferPointer { ims in

                    var entradaSplit = DSPSplitComplex(
                        realp: re.baseAddress!, imagp: ie.baseAddress!
                    )
                    var saidaSplit = DSPSplitComplex(
                        realp: rs.baseAddress!, imagp: ims.baseAddress!
                    )

                    vDSP_ctoz(complexos, 2, &entradaSplit, 1, vDSP_Length(metade))

                    // Entrada e saída distintas, de propósito.
                    fft.forward(input: entradaSplit, output: &saidaSplit)

                    vDSP.absolute(saidaSplit, result: &magnitudes)
                }}}}
            }
        }

        // Quanta energia está na faixa da voz, contra o total.
        let resolucao = taxa / Float(tamanho)

        var energiaVoz: Float = 0
        var energiaTotal: Float = 0

        for k in 1..<metade {

            let freq = Float(k) * resolucao
            let e = magnitudes[k] * magnitudes[k]

            energiaTotal += e

            if freq >= vozMin && freq <= vozMax {
                energiaVoz += e
            }
        }

        razao = energiaTotal > 0 ? energiaVoz / energiaTotal : 0

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
