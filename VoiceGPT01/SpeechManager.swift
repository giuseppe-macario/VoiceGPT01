import Foundation
import Speech
import AVFoundation
import Combine

/// Gestisce la trascrizione vocale (Speech-to-Text) e la lettura vocale (Text-to-Speech).
/// Espone proprietà `@Published` per aggiornare l'interfaccia utente in tempo reale.
class SpeechManager: NSObject, ObservableObject, SFSpeechRecognizerDelegate {
    
    // MARK: - Componenti interni

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "it-IT"))
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    private let synthesizer = AVSpeechSynthesizer()
    private var sentenceQueue: [String] = []

    // MARK: - Stato osservabile

    /// Trascrizione generata in tempo reale durante la registrazione.
    @Published var transcript: String = ""
    
    /// Indica se la registrazione vocale è in corso.
    @Published var isRecording: Bool = false
    
    /// Indica se il sintetizzatore sta leggendo ad alta voce.
    @Published var isSpeaking: Bool = false
    
    /// Indica se la lettura vocale è attualmente in pausa.
    @Published var isPaused: Bool = false

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - Registrazione

    /// Avvia la registrazione vocale e la trascrizione automatica.
    func startRecording() {
        transcript = ""
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        guard let recognitionRequest = recognitionRequest else { return }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        audioEngine.prepare()
        try? audioEngine.start()

        recognitionTask = recognizer?.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                DispatchQueue.main.async {
                    self.transcript = result.bestTranscription.formattedString
                }
            }
        }

        isRecording = true
    }

    /// Termina la registrazione e conclude la trascrizione.
    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        isRecording = false
    }

    // MARK: - Lettura vocale (TTS)

    /// Accoda una o più frasi da leggere ad alta voce.
    /// - Parameters:
    ///   - sentences: Array di stringhe da leggere.
    ///   - rate: Velocità della voce sintetica (valori consigliati: 0.04–0.5).
    func enqueue(sentences: [String], rate: Float = 0.04) {
        guard !sentences.isEmpty else { return }
        sentenceQueue.append(contentsOf: sentences)
        startNextIfNeeded(rate: rate)
    }

    /// Ferma immediatamente la lettura vocale e svuota la coda.
    func stopSpeaking() {
        sentenceQueue.removeAll()
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    /// Mette in pausa o riprende la lettura vocale.
    func togglePauseSpeaking() {
        if synthesizer.isSpeaking && !isPaused {
            synthesizer.pauseSpeaking(at: .immediate)
            isPaused = true
        } else if isPaused {
            synthesizer.continueSpeaking()
            isPaused = false
        }
    }

    // MARK: - Helpers privati

    /// Se il sintetizzatore non sta parlando, avvia la prossima frase nella coda.
    private func startNextIfNeeded(rate: Float) {
        guard !synthesizer.isSpeaking, !sentenceQueue.isEmpty else { return }

        let raw = sentenceQueue.removeFirst()
        let utterance = AVSpeechUtterance(string: raw)
        utterance.voice = AVSpeechSynthesisVoice(identifier: "com.apple.voice.premium.it-IT.Federica")
        utterance.volume = 0.12
        utterance.rate = rate
        utterance.postUtteranceDelay = 2.7
        synthesizer.speak(utterance)
        isSpeaking = true
    }
}

extension SpeechManager: AVSpeechSynthesizerDelegate {
    
    /// Chiamato automaticamente quando una frase è stata letta per intero.
    /// Se ci sono altre frasi nella coda, avvia la successiva.
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let rate = utterance.rate
        let manager = self
        DispatchQueue.main.async {
            manager.isSpeaking = false
            manager.startNextIfNeeded(rate: rate)
        }
    }
}
