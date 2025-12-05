import Foundation

/// Insieme di trasformazioni testuali usate **solo** per il flusso TTS.
/// Nota: l'enum senza casi funge da *namespace* di funzioni statiche,
/// ovvero non può essere mai istanziato.
enum ResponseTransformer {
    
    /// Inserisce una virgola prima di ciascuna parola indicata in `words`,
    /// **solo** se la parola non è già preceduta da una virgola.
    ///
    /// - Parameters:
    ///   - text: Stringa di partenza.
    ///   - words: Array di parole/congiunzioni davanti alle quali
    ///            deve comparire la virgola (ad es. `["e", "o", "che"]`).
    /// - Returns: Una nuova stringa con le virgole aggiunte.
    ///
    /// La regex `(?<!,)\s+\(word)\b` funziona così:
    /// 1. `(?<!,)`   → Look-behind negativo: assicura che **non** ci sia già una virgola.
    /// 2. `\s+`      → Uno o più spazi prima della parola.
    /// 3. `\(word)\b` → La parola target seguita da un *word boundary*.
    static func addCommaBefore(text: String, replacing words: [String]) -> String {
        var result = text
        
        for word in words {
            // Costruisce dinamicamente il pattern per ciascuna parola
            let pattern = "(?<!,)\\s+\(word)\\b"
            
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(result.startIndex..., in: result)
                // Sostituisce " spazio + parola " con ", parola"
                result = regex.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: range,
                    withTemplate: ", \(word)"
                )
            }
        }
        
        return result
    }
    
    /// Sostituisce alcune locuzioni e termini con alternative più scorrevoli
    /// per la lettura vocale.
    ///
    /// - Parameters:
    ///   - text: Stringa di partenza.
    /// - Returns: La stringa con le parole/locuzioni sostituite.
    ///
    /// Modifiche apportate:
    /// 1. " piuttosto che " → " anziché "
    /// 2. " il che "       → " che "
    /// 3. "crucial"         → "important"
    /// 4. "In sintesi, "    → "Quindi per concludere, "
    ///
    /// Queste sostituzioni rendono il testo più naturale all'ascolto.
    static func replaceWords(text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: " piuttosto che ", with: " anziché ")
        result = result.replacingOccurrences(of: " il che ", with: " che ")
        result = result.replacingOccurrences(of: "crucial", with: "important")
        result = result.replacingOccurrences(of: "In sintesi, ", with: "Quindi, per concludere, ")
        
        return result
    }
    
    /// Applica tutte le trasformazioni necessarie per preparare il testo
    /// alla lettura vocale, combinando `replaceWords` e `addCommaBefore`.
    ///
    /// - Parameters:
    ///   - text: Stringa di partenza.
    /// - Returns: La stringa trasformata pronta per il TTS, con:
    ///   1. Sostituzioni lessicali (tramite `replaceWords`).
    ///   2. Inserimento di virgole prima delle congiunzioni (tramite `addCommaBefore`).
    ///
    /// Esempio di flusso:
    /// 1. Input: "Questo è un esempio piuttosto che un test"
    /// 2. `replaceWords` → "Questo è un esempio anziché un test"
    /// 3. `addCommaBefore` → se `words = ["e", "che"]`, diventa "Questo è un esempio anziché, un test"
    static func updateForTTS(text: String) -> String {
        var result = text
        
        // 1) Sostituzioni lessicali per rendere il testo più naturale
        result = replaceWords(text: result)
        // 2) Aggiunta di virgole prima delle parole specificate
        result = addCommaBefore(text: result, replacing: ["e", "ed", "o", "od", "sia", "che", "con", "per", "tra", "fra"])
        
        return result
    }
}
