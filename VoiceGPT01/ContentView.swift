/// Interfaccia principale dell'app: l'utente può
/// 1. Registrare una domanda vocale (speech-to-text live)
/// 2. Inviare il testo a GPT (streaming, modello "gpt-4o")
/// 3. Visualizzare la risposta man mano che arriva
/// 4. Ascoltare la risposta con AVSpeechSynthesizer
/// 5. Mettere in pausa / riprendere la lettura toccando l'area di trascrizione
///

import SwiftUI
import AVFoundation

/// View principale dell'applicazione.
///
/// Si interfaccia con:
/// - `SpeechManager`: per la registrazione audio (STT) e la lettura vocale (TTS)
/// - `GPTService`: per ottenere risposte in streaming da GPT
///
/// L'interazione dell'utente avviene principalmente tramite un singolo pulsante.
struct ContentView: View {

    // MARK: - Stato

    /// Gestore di sintesi vocale e riconoscimento audio.
    @StateObject private var speechManager = SpeechManager()

    /// Risposta ricevuta da GPT, mostrata nella UI.
    @State private var responseText = ""

    /// Controlla se l'utente può premere il pulsante principale.
    @State private var isButtonDisabled = false

    /// Task asincrono che riceve il flusso GPT; serve un riferimento per cancellarlo.
    @State private var streamingTask: Task<Void, Never>? = nil

    // MARK: - View principale

    var body: some View {
        VStack(spacing: 16) {
            transcriptArea     // Area di trascrizione vocale
            responseArea       // Area di risposta GPT
            mainButtonArea     // Pulsante principale e zona tappabile
        }
        .padding()
        .onAppear(perform: configureAudio)
    }

    // MARK: - Sub-Views

    /// Mostra la trascrizione in tempo reale.
    /// Toccandola, l'utente può mettere in pausa o riprendere la lettura vocale.
    private var transcriptArea: some View {
        ZStack {
            Color.gray.opacity(0.1)
                .cornerRadius(12)
                .contentShape(Rectangle())
                .onTapGesture { speechManager.togglePauseSpeaking() }

            TextEditor(text: $speechManager.transcript)
                .disabled(true)
                .padding()
        }
        .frame(height: 120)
    }

    /// Area scrollabile che mostra la risposta testuale di GPT.
    private var responseArea: some View {
        ScrollView {
            Text(responseText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .frame(maxHeight: 240)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }

    /// Pulsante principale + area tappabile trasparente per gestire i 3 stati:
    /// - "Registra"
    /// - "Fine e invia"
    /// - "Ferma lettura"
    private var mainButtonArea: some View {
        VStack(spacing: 0) {
            Button(action: buttonTapped) {
                Text(buttonLabel())
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isButtonDisabled)

            Rectangle()
                .foregroundColor(.clear)
                .contentShape(Rectangle())
                .onTapGesture {
                    if !isButtonDisabled { buttonTapped() }
                }
        }
    }

    // MARK: - Logica dei pulsanti

    /// Gestisce i 3 stati principali del pulsante.
    private func buttonTapped() {
        Task { @MainActor in
            switch (speechManager.isSpeaking, speechManager.isRecording) {

            case (true, _):
                // Se stiamo leggendo, interrompi voce + streaming
                speechManager.stopSpeaking()
                streamingTask?.cancel()

            case (false, true):
                // Se stiamo registrando, ferma e invia richiesta
                await handleStopRecording()

            case (false, false):
                // Se siamo inattivi, inizia registrazione
                startRecording()
            }
        }
    }

    /// Ferma la registrazione, prepara e invia il prompt a GPT.
    private func handleStopRecording() async {
        isButtonDisabled = true
        speechManager.stopRecording()

        let prompt = speechManager.transcript.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !prompt.isEmpty else {
            responseText = "Nessuna domanda registrata."
            isButtonDisabled = false
            return
        }

        // Reset interfaccia e sintesi
        responseText = ""
        speechManager.stopSpeaking()
        streamingTask?.cancel()

        // Feedback vocale all'utente
        speechManager.enqueue(sentences: ["Attendo"], rate: 0.5)

        // Invia richiesta a GPT
        streamingTask = Task { await streamAnswer(for: prompt) }
    }

    /// Avvia la registrazione e riproduce "Registro" come conferma vocale.
    private func startRecording() {
        isButtonDisabled = true
        speechManager.stopSpeaking()
        speechManager.enqueue(sentences: ["Registro"], rate: 0.5)
        speechManager.startRecording()
        isButtonDisabled = false
    }

    // MARK: - GPT Streaming

    /// Riceve la risposta GPT in tempo reale.
    /// Per ogni frase completa:
    /// - la mostra nella UI così com'è
    /// - la trasforma con `ResponseTransformer.updateForTTS()` e la passa al sintetizzatore vocale
    private func streamAnswer(for prompt: String) async {
        var buffer = ""

        do {
            let stream = GPTService.stream(prompt: prompt, apiKey: Secrets.openAIKey)

            for try await delta in stream {
                buffer += delta
                for sentence in extractSentences(from: &buffer) {
                    await MainActor.run { responseText += sentence }
                    let toRead = ResponseTransformer.updateForTTS(text: sentence)
                    await MainActor.run { speechManager.enqueue(sentences: [toRead]) }
                }
            }

            // Ultimo frammento senza punto finale
            if !buffer.isEmpty {
                await MainActor.run { responseText += buffer }
                let toRead = ResponseTransformer.updateForTTS(text: buffer)
                await MainActor.run { speechManager.enqueue(sentences: [toRead]) }
            }

        } catch {
            await MainActor.run {
                responseText = "Errore nella chiamata: \(error.localizedDescription)"
            }
        }

        await MainActor.run { isButtonDisabled = false }
    }
    
    // MARK: - Helpers

    /// Ritorna l’etichetta corretta in base allo stato (Registra / Fine e invia / Ferma lettura).
    private func buttonLabel() -> String {
        if speechManager.isSpeaking       { "Ferma lettura" }
        else if speechManager.isRecording { "Fine e invia" }
        else                              { "Registra" }
    }

    /// Estrae frasi terminate da punto fermo. Il buffer tiene il resto.
    private func extractSentences(from buffer: inout String) -> [String] {
        var sentences: [String] = []
        while let range = buffer.range(of: ".") {
            sentences.append(String(buffer[..<range.upperBound]))
            buffer = String(buffer[range.upperBound...])
        }
        return sentences
    }

    /// Configura la sessione audio per permettere registrazione + output via speaker.
    private func configureAudio() {
        try? AVAudioSession.sharedInstance()
            .setCategory(.playAndRecord, options: [AVAudioSession.CategoryOptions.allowBluetoothHFP, .defaultToSpeaker])
        try? AVAudioSession.sharedInstance().setActive(true)
    }
}

// MARK: - Preview

//#Preview {
//    ContentView()
//}

