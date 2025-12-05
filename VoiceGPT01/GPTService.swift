import Foundation

/// Servizio responsabile della comunicazione con l'API OpenAI (modello `gpt-4o`).
///
/// Espone una sola funzione `stream(prompt:apiKey:)`, che restituisce
/// uno `AsyncThrowingStream<String, Error>` contenente in tempo reale
/// i delta testuali prodotti da GPT.
///
/// Ogni stringa emessa rappresenta un frammento di frase della risposta.
struct GPTService {

    /// Struttura interna che rappresenta un blocco/parziale della risposta GPT.
    private struct ChatChunk: Decodable {
        struct Choice: Decodable {
            struct Delta: Decodable {
                /// Contenuto testuale incrementale (può essere `nil`).
                let content: String?
            }
            let delta: Delta
        }
        let choices: [Choice]
    }

    /// Esegue una richiesta streaming a GPT-4o con il prompt vocale trascritto.
    ///
    /// - Parameters:
    ///   - prompt: Il testo da inviare come messaggio dell'utente.
    ///   - apiKey: La chiave API di OpenAI (forma: `sk-...`).
    /// - Returns: Uno stream asincrono di frammenti testuali.
    ///
    /// La risposta è ricevuta **a pezzi** (chunking) grazie all'opzione `"stream": true`.
    /// Ogni frammento viene decodificato da JSON e, se contiene contenuto (`delta.content`),
    /// viene emesso nello stream di ritorno.
    static func stream(prompt: String, apiKey: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                // Verifica URL
                guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
                    continuation.finish(throwing: URLError(.badURL))
                    return
                }

                // Corpo della richiesta HTTP per ChatGPT
                let requestBody: [String: Any] = [
                    "model": "gpt-5-mini",
                    "stream": true,
                    // "verbosity": "medium", // 2–5 paragrafi (200–400 parole). Per più di 5 paragrafi, impostare high
                    "messages": [
                        // Prompt iniziale di sistema: imposta il comportamento del modello
                        ["role": "system", "content": "Questo è un esame orale universitario. Trattandosi di esposizione esclusivamente orale, risposta deve essere priva di elementi tipici del solo testo scritto e non adatti all'esposizione orale, tra cui elenchi numerati o puntati, parole in grassetto, formule numeriche e calcoli, e così via. In ogni caso, ogni frase deve anche essere usata come breve messaggio di testo SMS, quindi non deve essere essere più lunga di 140 caratteri. Usa il più possibile espressioni italiane: per esempio, invece di \"molti setup server high-performance\", dovresti dire \"molti sistemi server ad alte prestazioni\" e così via. Inoltre, poiché il prompt viene dettato a voce, potrebbe contenere errori di trascrizione: per esempio, \"ISODOSI\" può significare \"ISO/OSI\", oppure \"di H CP\" può significare \"DHCP\", e così via; devi quindi interpretare parole o acronimi senza senso attribuendo loro il corretto significato in un contesto informatico."],
                        // Messaggio dell'utente vero e proprio
                        ["role": "user", "content": prompt]
                    ]
                ]

                // Configurazione della richiesta HTTP
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)

                do {
                    let decoder = JSONDecoder()
                    // Esegue la richiesta e riceve i byte in streaming
                    let (bytes, _) = try await URLSession.shared.bytes(for: request)

                    // `bytes.lines` consente di leggere riga per riga
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }

                        let jsonLine = line.replacingOccurrences(of: "data: ", with: "")
                        if jsonLine == "[DONE]" { break }  // fine dello stream

                        if let jsonData = jsonLine.data(using: .utf8) {
                            let chunk = try decoder.decode(ChatChunk.self, from: jsonData)
                            if let delta = chunk.choices.first?.delta.content {
                                continuation.yield(delta)  // emette il frammento
                            }
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
